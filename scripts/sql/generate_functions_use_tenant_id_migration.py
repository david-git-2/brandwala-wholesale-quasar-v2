#!/usr/bin/env python3
"""Emit migration SQL from supabase/schemas (clean bodies)."""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMAS = ROOT / "supabase/schemas"
OUT = ROOT / "supabase/migrations/20261119233100_functions_use_tenant_id.sql"

# Functions whose bodies still reference parent_tenant_id column (from live DB audit).
TARGETS = [
    "_assert_parent_warehouse_tenant",
    "_insert_bill_line_from_compose_payload",
    "_upsert_shipment_ap_bill",
    "_validate_stock_location_nesting",
    "add_global_return_item",
    "add_shop_order_item_stock_pick",
    "apply_dropship_payout_settlement_fifo",
    "approve_stock_physical_count",
    "canonicalize_dropship_order_wallet_source_ids",
    "close_preorder_demand_document",
    "create_and_post_stock_movement",
    "create_cargo_company_with_wallet",
    "create_delivery_paper_for_document",
    "create_stock_physical_count",
    "create_vendor_with_wallet",
    "credit_dropship_profit_from_courier_remittance",
    "customer_accessible_catalog_glance",
    "delete_shop",
    "delete_stock_location",
    "dispatch_delivery_paper",
    "enqueue_notification",
    "ensure_default_cargo_company",
    "ensure_dropship_courier_cod_receivable",
    "ensure_preorder_demand_for_procuring_document",
    "get_available_stock",
    "get_cashbook_dashboard_summary",
    "get_customer_dues_report",
    "get_my_dropship_wallet_summary",
    "get_parent_cash_circulation",
    "get_shop_catalog_product_for_customer",
    "get_tenant_invoice_book_report",
    "get_vendor_for_tenant",
    "issue_dropship_tenant_b2b_invoice",
    "list_catalog_refresh_log",
    "list_child_allocation_summary",
    "list_open_invoices_for_payment",
    "list_shop_order_delivery_paper_qty_by_item",
    "mark_delivery_paper_packed",
    "paste_batch_code_items",
    "post_customer_receipt_with_allocations",
    "post_vendor_credit_refund",
    "preview_tenant_data_purge",
    "process_dropship_courier_remittance_uwl",
    "purge_tenant_operational_data",
    "record_delivery_paper_short_pick",
    "reverse_cashbook_ledger_entry_for_staff",
    "set_default_stock_location",
    "staff_close_catalog_procurement",
    "submit_stock_physical_count",
    "sync_delivery_paper_lines_for_demand",
    "sync_shipment_ap_bills",
    "transfer_dropship_reseller_profit",
    "transfer_wallet_balance",
    "trg_sync_profile_from_cargo_company",
    "trg_sync_profile_from_vendor",
    "update_catalog_order_rates_for_staff",
    "upsert_preorder_demand",
    "upsert_stock_location",
    "upsert_stock_physical_count_line",
]

WMS_MISSING = {
    "approve_stock_physical_count",
    "create_delivery_paper_for_document",
    "create_stock_physical_count",
    "dispatch_delivery_paper",
    "list_shop_order_delivery_paper_qty_by_item",
    "mark_delivery_paper_packed",
    "record_delivery_paper_short_pick",
    "staff_close_catalog_procurement",
    "submit_stock_physical_count",
    "sync_delivery_paper_lines_for_demand",
    "upsert_stock_physical_count_line",
}

CREATE_RE = re.compile(
    r'^CREATE OR REPLACE FUNCTION (?:public\.)?"(?P<schema>public)"\."(?P<name>[^"]+)"',
    re.MULTILINE,
)
CREATE_RE2 = re.compile(
    r'^CREATE OR REPLACE FUNCTION public\.(?P<name>[a-z0-9_]+)\(',
    re.MULTILINE | re.IGNORECASE,
)


def split_functions(text: str) -> dict[str, str]:
    matches: list[tuple[int, str]] = []
    for m in CREATE_RE.finditer(text):
        if m.group("schema") == "public":
            matches.append((m.start(), m.group("name")))
    for m in CREATE_RE2.finditer(text):
        matches.append((m.start(), m.group("name")))
    matches.sort(key=lambda x: x[0])
    out: dict[str, str] = {}
    for i, (start, name) in enumerate(matches):
        end = matches[i + 1][0] if i + 1 < len(matches) else len(text)
        chunk = text[start:end].strip()
        if not chunk.endswith(";"):
            continue
        # Keep only function body lines (stop before ALTER FUNCTION OWNER)
        lines = chunk.splitlines()
        body: list[str] = []
        for ln in lines:
            if ln.startswith("ALTER FUNCTION") or ln.startswith("REVOKE ALL ON FUNCTION"):
                break
            body.append(ln)
        sql = "\n".join(body).strip()
        if sql:
            out[name] = sql
    return out


def collect_schema_functions() -> dict[str, str]:
    found: dict[str, str] = {}
    for path in sorted(SCHEMAS.rglob("*.sql")):
        if path.suffix != ".sql":
            continue
        if path.name.endswith((".bak", ".pre-so3")):
            continue
        merged = split_functions(path.read_text(encoding="utf-8"))
        for name, sql in merged.items():
            if name in TARGETS and name not in found:
                found[name] = sql
    return found


def pg_get_functiondef(name: str) -> str | None:
    try:
        r = subprocess.run(
            [
                "docker",
                "exec",
                "supabase_db_brandwala-wholesale-quasar",
                "psql",
                "-U",
                "postgres",
                "-d",
                "postgres",
                "-X",
                "-At",
                "-c",
                f"select pg_get_functiondef(p.oid) from pg_proc p "
                f"join pg_namespace n on n.oid=p.pronamespace "
                f"where n.nspname='public' and p.proname='{name}' "
                f"order by pg_get_function_identity_arguments(p.oid) limit 1;",
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None
    if r.returncode != 0 or not r.stdout.strip():
        return None
    return r.stdout.strip()


def rewrite_wms_body(sql: str) -> str:
    replacements = [
        (r"\bdp\.parent_tenant_id\b", "dp.tenant_id"),
        (r"\bv_count\.parent_tenant_id\b", "v_count.tenant_id"),
        (r"\bv_pd\.parent_tenant_id\b", "v_pd.tenant_id"),
        (r"\bv_order\.parent_tenant_id\b", "v_order.tenant_id"),
        (r"(?<![\w.])parent_tenant_id(?![\w.])", "tenant_id"),
        (r"'parent_tenant_id'", "'tenant_id'"),
    ]
    for pat, sub in replacements:
        sql = re.sub(pat, sub, sql)
    return sql


def main() -> int:
    found = collect_schema_functions()
    parts = [
        "-- Sync function bodies to supabase/schemas (tenant_id; no parent_tenant_id column).\n",
        "DROP FUNCTION IF EXISTS public._upsert_shipment_ap_bill("
        "bigint, bigint, bigint, text, text, bigint, numeric, jsonb, boolean);\n",
    ]

    missing: list[str] = []
    for name in TARGETS:
        if name in WMS_MISSING:
            raw = pg_get_functiondef(name)
            if not raw:
                missing.append(name)
                continue
            parts.append(rewrite_wms_body(raw))
            parts.append("\n\n")
            continue
        sql = found.get(name)
        if not sql:
            missing.append(name)
            continue
        if re.search(r"\bparent_tenant_id\b", sql):
            missing.append(f"{name} (still has parent_tenant_id in schema)")
            continue
        parts.append(sql)
        parts.append("\n\n")

    # upsert_preorder_demand has two overloads in schema
    for path in sorted(SCHEMAS.rglob("*.sql")):
        text = path.read_text(encoding="utf-8")
        for m in re.finditer(
            r'^CREATE OR REPLACE FUNCTION public\.upsert_preorder_demand\(',
            text,
            re.MULTILINE,
        ):
            start = m.start()
            nxt = text.find("\nCREATE OR REPLACE FUNCTION", start + 10)
            if nxt == -1:
                chunk = text[start:]
            else:
                chunk = text[start:nxt]
            lines = chunk.splitlines()
            body = []
            for ln in lines:
                if ln.startswith("ALTER FUNCTION") or ln.startswith("GRANT"):
                    break
                body.append(ln)
            sql = "\n".join(body).strip()
            if "upsert_preorder_demand" in sql and sql not in "".join(parts):
                if not re.search(r"\mparent_tenant_id\M", sql):
                    parts.append(sql)
                    parts.append("\n\n")

    if missing:
        print("MISSING or dirty:", ", ".join(missing), file=sys.stderr)
        return 1

    OUT.write_text("".join(parts), encoding="utf-8")
    print(f"Wrote {OUT} ({len(found)} from schema + WMS from live)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
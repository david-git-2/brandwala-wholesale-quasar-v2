#!/usr/bin/env python3
"""Build phase 8c migration from patched public.sql (regex extract, no full split)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUBLIC = ROOT / "supabase/schemas/public.sql"
OUT = ROOT / "supabase/migrations/20261105223000_tenant_id_phase8c_bills_profiles_vendors.sql"

TABLES_RENAME = [
    "bills",
    "bill_lines",
    "bill_settlements",
    "books_exchange_rates",
    "cashbook_point_pots",
    "cashbook_points",
    "invoice_brands",
    "profiles",
    "vendors",
    "sales_return_items",
]

INCLUDE_MARKERS = (
    "public.bills",
    "public.bill_lines",
    "public.bill_settlements",
    "public.profiles",
    "public.vendors",
    "public.invoice_brands",
    "public.books_exchange_rates",
    "public.cashbook_points",
    "public.cashbook_point_pots",
    "public.sales_return_items",
    "v_kernel_bill_summaries",
)

# Must touch at least one core 8c table (avoid redeploying cashbook ledger RPCs with OUT row renames).
PATCH_SIGNALS = (
    "v_bill.tenant_id",
    "v_invoice.tenant_id",
    "v_inv.tenant_id",
    "v_cn.tenant_id",
    "b.tenant_id",
    "bl.tenant_id",
    "pr.tenant_id",
    "v.tenant_id",
    "p.tenant_id",
    "insert into public.bills",
    "insert into public.bill_lines",
    "insert into public.profiles",
    "insert into public.vendors",
    "insert into public.invoice_brands",
    "insert into public.sales_return_items",
    "insert into public.bill_settlements",
    "from public.v_kernel_bill_summaries",
    "join public.v_kernel_bill_summaries",
    "cpp.tenant_id",
    "cp.tenant_id",
    "public.books_exchange_rates",
)

EXCLUDE_FUNCTIONS = frozenset(
    {
        "list_cashbook_ledger_for_staff",
        "list_cashbook_entities_for_staff",
    }
)

RLS_TABLES = frozenset(
    {
        "bills",
        "bill_lines",
        "bill_settlements",
        "invoice_brands",
        "profiles",
        "vendors",
        "books_exchange_rates",
        "cashbook_points",
        "cashbook_point_pots",
    }
)

VIEW_PATTERNS = (
    r'CREATE OR REPLACE VIEW "public"\."global_invoice_items"',
    r'CREATE OR REPLACE VIEW "public"\."global_return_items"',
    r"CREATE OR REPLACE VIEW public\.v_kernel_bill_summaries",
)

FUNC_START = re.compile(
    r'CREATE OR REPLACE FUNCTION "public"\."(\w+)"',
    re.MULTILINE,
)
VIEW_START = re.compile(
    r'CREATE OR REPLACE VIEW (?:"public"\."(\w+)"|public\.(\w+))',
    re.MULTILINE,
)
POLICY_START = re.compile(
    r'CREATE POLICY "([^"]+)" ON "public"\."(\w+)"',
    re.MULTILINE,
)


def extract_from(pos: int, text: str) -> str:
    """From pos at statement start, return through terminating semicolon outside $$."""
    i = pos
    n = len(text)
    dollar_tag: str | None = None
    while i < n:
        if dollar_tag is None:
            if text[i : i + 2] == "$$":
                dollar_tag = "$$"
                i += 2
                continue
            m = re.match(r"\$([A-Za-z_][A-Za-z0-9_]*)\$", text[i:])
            if m:
                dollar_tag = m.group(0)
                i += len(dollar_tag)
                continue
            if text[i] == ";":
                return text[pos : i + 1]
            i += 1
        else:
            if text.startswith(dollar_tag, i):
                i += len(dollar_tag)
                dollar_tag = None
                continue
            i += 1
    return text[pos:]


def main() -> None:
    text = PUBLIC.read_text(encoding="utf-8")
    low = text.lower()

    renames = ["-- Phase 8c: rename parent_tenant_id -> tenant_id on bills/money/profile/vendor tables.\n"]
    for t in TABLES_RENAME:
        renames.append(f"ALTER TABLE public.{t} RENAME COLUMN parent_tenant_id TO tenant_id;\n")

    views: list[str] = []
    tables_sql = ROOT / "supabase/schemas/bills_pays/02_tables.sql"
    ttext = tables_sql.read_text(encoding="utf-8")
    for vname in ("global_invoice_items", "global_return_items"):
        m = re.search(rf'CREATE OR REPLACE VIEW "public"\."{vname}"', ttext)
        if m:
            views.append("\n" + extract_from(m.start(), ttext).strip() + "\n")

    funcs: list[str] = []
    seen_funcs: set[str] = set()
    for m in FUNC_START.finditer(text):
        name = m.group(1)
        if name in seen_funcs or name in EXCLUDE_FUNCTIONS:
            continue
        stmt = extract_from(m.start(), text)
        sl = stmt.lower()
        if not any(mark in sl for mark in INCLUDE_MARKERS):
            continue
        if not any(sig in sl for sig in PATCH_SIGNALS):
            continue
        if "public.notifications" in sl and "public.bills" not in sl and "public.profiles" not in sl:
            continue
        seen_funcs.add(name)
        funcs.append("\n" + stmt.strip() + "\n")

    policy_drops: list[str] = []
    policies: list[str] = []
    seen_policies: set[tuple[str, str]] = set()
    for m in POLICY_START.finditer(text):
        pname, table = m.group(1), m.group(2)
        if table not in RLS_TABLES:
            continue
        key = (table, pname)
        if key in seen_policies:
            continue
        seen_policies.add(key)
        stmt = extract_from(m.start(), text)
        policy_drops.append(f'DROP POLICY IF EXISTS "{pname}" ON public.{table};\n')
        policies.append("\n" + stmt.strip() + "\n")

    # bill_settlements RLS may live only in bills_pays split
    bp_rls = ROOT / "supabase/schemas/bills_pays/05_money_spine.sql"
    kernel = ROOT / "supabase/schemas/bills_pays/09_kernel_reads.sql"
    if kernel.exists():
        ktext = kernel.read_text(encoding="utf-8")
        m = re.search(r"CREATE OR REPLACE VIEW public\.v_kernel_bill_summaries", ktext)
        if m:
            views.append("\n" + extract_from(m.start(), ktext).strip() + ";\n")
    if bp_rls.exists():
        bp = bp_rls.read_text(encoding="utf-8")
        for m in re.finditer(r'CREATE POLICY "([^"]+)" ON public\.bill_settlements', bp):
            pname = m.group(1)
            if ("bill_settlements", pname) in seen_policies:
                continue
            stmt = extract_from(m.start(), bp)
            policy_drops.append(f'DROP POLICY IF EXISTS "{pname}" ON public.bill_settlements;\n')
            policies.append("\n" + stmt.strip() + "\n")

    parts = renames + [
        "\nDROP VIEW IF EXISTS public.global_invoice_items CASCADE;\n",
        "DROP VIEW IF EXISTS public.global_return_items CASCADE;\n",
        "DROP VIEW IF EXISTS public.v_kernel_bill_summaries CASCADE;\n",
        "\n-- compat + kernel views\n",
    ] + views
    parts.append(f"\n-- RPCs ({len(funcs)} functions)\n")
    parts.extend(funcs)
    parts.append("\n-- RLS\n")
    parts.extend(policy_drops)
    parts.extend(policies)

    OUT.write_text("".join(parts), encoding="utf-8")
    print(f"Wrote {OUT.name}: {len(funcs)} functions, {len(views)} views, {len(policies)} policies")


if __name__ == "__main__":
    main()

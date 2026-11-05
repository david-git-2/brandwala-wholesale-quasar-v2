#!/usr/bin/env python3
"""Build minimal phase 10 migration (renames + compat wrappers + targeted fixes)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUBLIC = ROOT / "supabase/schemas/public.sql"
OUT = ROOT / "supabase/migrations/20261106120000_tenant_id_phase10_cleanup.sql"

TARGET_FUNCTIONS = frozenset(
    {
        "resolve_books_tenant_id",
        "user_can_manage_books_tenant",
        "can_manage_products_for_books_tenant",
        "can_view_products_for_books_tenant",
        "set_products_catalog_books_tenant_id",
        "set_books_tenant_id_from_tenant",
        "sync_lookup_tenant_id",
        "sync_product_tenant_from_vendor",
        "_undo_wallet_ledger_row_before_delete",
        "_undo_wallet_ledger_row_before_update",
    }
)

RLS_POLICY_TABLES = frozenset(
    {"products", "batch_code_items", "global_shipment_items", "recipient_profiles"}
)

FUNC_START = re.compile(r'CREATE OR REPLACE FUNCTION "public"\."(\w+)"', re.M)
POLICY_START = re.compile(r'CREATE POLICY "([^"]+)" ON "public"\."(\w+)"', re.M)
TRIGGER_START = re.compile(r'CREATE OR REPLACE TRIGGER "trg_products_set_books_tenant_id"', re.M)


def extract_from(pos: int, text: str) -> str:
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


def extract_named_functions(text: str, names: frozenset[str]) -> list[str]:
    out: list[str] = []
    for m in FUNC_START.finditer(text):
        name = m.group(1)
        if name not in names:
            continue
        out.append(extract_from(m.start(), text).strip())
    return out


def collect_policies(text: str) -> list[tuple[str, str, str]]:
    items: list[tuple[str, str, str]] = []
    seen: set[tuple[str, str]] = set()
    for m in POLICY_START.finditer(text):
        pname, table = m.group(1), m.group(2)
        if table not in RLS_POLICY_TABLES:
            continue
        key = (table, pname)
        if key in seen:
            continue
        seen.add(key)
        items.append((table, pname, extract_from(m.start(), text).strip()))
    return items


def collect_views() -> list[str]:
    views: list[str] = []
    ttext = (ROOT / "supabase/schemas/bills_pays/02_tables.sql").read_text(encoding="utf-8")
    ktext = (ROOT / "supabase/schemas/bills_pays/09_kernel_reads.sql").read_text(encoding="utf-8")
    for vname in ("global_invoice_items", "global_return_items"):
        m = re.search(rf'CREATE OR REPLACE VIEW "public"\."{vname}"', ttext)
        if m:
            views.append(extract_from(m.start(), ttext).strip())
    m = re.search(r"CREATE OR REPLACE VIEW public\.v_kernel_bill_summaries", ktext)
    if m:
        views.append(extract_from(m.start(), ktext).strip())
    return views


def main() -> None:
    public_text = PUBLIC.read_text(encoding="utf-8")
    funcs = extract_named_functions(public_text, TARGET_FUNCTIONS)
    policies = collect_policies(public_text)
    views = collect_views()
    trigger_stmt = ""
    tm = TRIGGER_START.search(public_text)
    if tm:
        trigger_stmt = extract_from(tm.start(), public_text).strip()

    wrappers = """
-- Deprecated wrappers (one release): old names forward to books_* RPCs for in-DB callers not redeployed in this migration.
CREATE OR REPLACE FUNCTION public.resolve_parent_tenant_id(p_tenant_id bigint) RETURNS bigint
    LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO public
    AS $$ SELECT public.resolve_books_tenant_id(p_tenant_id); $$;

CREATE OR REPLACE FUNCTION public.user_can_manage_parent_tenant(p_tenant_id bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO public
    AS $$ SELECT public.user_can_manage_books_tenant(p_tenant_id); $$;

CREATE OR REPLACE FUNCTION public.can_manage_products_for_parent(p_tenant_id bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO public
    AS $$ SELECT public.can_manage_products_for_books_tenant(p_tenant_id); $$;

CREATE OR REPLACE FUNCTION public.can_view_products_for_parent(p_tenant_id bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO public
    AS $$ SELECT public.can_view_products_for_books_tenant(p_tenant_id); $$;

"""

    parts = [
        "-- Phase 10: rename books-scope RPCs; fix wallet triggers/views/RLS.\n",
        "ALTER FUNCTION public.resolve_parent_tenant_id(bigint) RENAME TO resolve_books_tenant_id;\n",
        "ALTER FUNCTION public.user_can_manage_parent_tenant(bigint) RENAME TO user_can_manage_books_tenant;\n",
        "ALTER FUNCTION public.can_manage_products_for_parent(bigint) RENAME TO can_manage_products_for_books_tenant;\n",
        "ALTER FUNCTION public.can_view_products_for_parent(bigint) RENAME TO can_view_products_for_books_tenant;\n",
        "ALTER FUNCTION public.set_products_catalog_parent_tenant_id() RENAME TO set_products_catalog_books_tenant_id;\n",
        wrappers,
    ]

    if views:
        parts.append("\nDROP VIEW IF EXISTS public.global_invoice_items CASCADE;\n")
        parts.append("DROP VIEW IF EXISTS public.global_return_items CASCADE;\n")
        parts.append("DROP VIEW IF EXISTS public.v_kernel_bill_summaries CASCADE;\n")
        for v in views:
            parts.append("\n" + v + ";\n")

    parts.append(f"\n-- Targeted function bodies ({len(funcs)})\n")
    for stmt in funcs:
        parts.append("\n" + stmt + ";\n")

    if trigger_stmt:
        parts.append("\nDROP TRIGGER IF EXISTS trg_products_set_parent_tenant_id ON public.products;\n")
        parts.append("\n" + trigger_stmt + ";\n")

    parts.append("\n-- RLS\n")
    for table, pname, stmt in policies:
        parts.append(f'DROP POLICY IF EXISTS "{pname}" ON public.{table};\n')
        parts.append("\n" + stmt + ";\n")

    OUT.write_text("".join(parts), encoding="utf-8")
    print(f"Wrote {OUT.name}: {len(funcs)} functions, {len(views)} views, {len(policies)} policies")


if __name__ == "__main__":
    main()

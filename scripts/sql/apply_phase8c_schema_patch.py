#!/usr/bin/env python3
"""Patch bills_pays split + public.sql for phase 8c column rename (declarative schema only)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

TABLES_8C = frozenset(
    {
        "bills",
        "bill_lines",
        "bill_settlements",
        "sales_return_items",
        "profiles",
        "vendors",
        "invoice_brands",
        "books_exchange_rates",
        "cashbook_point_pots",
        "cashbook_points",
    }
)

TABLES_SKIP_QUOTED_COL = frozenset(
    {
        "cashbook_accounts",
        "recipient_profiles",
        "notifications",
        "tenant_data_purge_logs",
    }
)

DOT_PREFIX_SKIP = frozenset({"wa", "wa2", "n"})

DOT_PREFIX_REPLACE = [
    "v_invoice",
    "v_bill",
    "v_cn",
    "v_parent",
    "v_inv",
    "v_item",
    "v_orig",
    "v_row",
    "b",
    "b2",
    "si",
    "pr",
    "v",
    "ven",
    "u",
    "cpp",
    "cp",
    "w",
    "i",
    "c",
    "bp",
    "pt",
    "bl",
    "ib",
    "prof",
    "profile",
    "bs",
    "ber",
    "new",
]

PRESERVE_SUBSTRINGS = (
    "user_can_manage_parent_tenant",
    "resolve_parent_tenant_id",
    "set_parent_tenant_id",
    "trg_recipient_profiles_set_parent_tenant_id",
    "parent_tenant_id is required",
)


def patch_create_table_blocks(text: str) -> str:
    pattern = re.compile(
        r'(CREATE TABLE IF NOT EXISTS "public"\."([^"]+)" \([\s\S]*?\);)',
        re.MULTILINE,
    )

    def repl(m: re.Match[str]) -> str:
        block, table = m.group(1), m.group(2)
        if table in TABLES_SKIP_QUOTED_COL:
            return block
        if table == "cashbook_entries":
            block = re.sub(
                r'\n    "parent_tenant_id" bigint NOT NULL,\n',
                "\n",
                block,
            )
            return block
        if table not in TABLES_8C:
            return block
        return block.replace('"parent_tenant_id"', '"tenant_id"')

    return pattern.sub(repl, text)


def patch_dot_refs(line: str) -> str:
    if any(s in line for s in PRESERVE_SUBSTRINGS):
        return line
    for prefix in DOT_PREFIX_REPLACE:
        line = line.replace(f"{prefix}.parent_tenant_id", f"{prefix}.tenant_id")
    return line


def patch_p_row_cashbook(line: str) -> str:
    if "p_row.parent_tenant_id" in line and "cashbook_entries" in line:
        return line.replace("p_row.parent_tenant_id", "p_row.tenant_id")
    if "wa.parent_tenant_id = p_row.parent_tenant_id" in line:
        return line.replace(
            "wa.parent_tenant_id = p_row.parent_tenant_id",
            "wa.parent_tenant_id = p_row.tenant_id",
        )
    return line


def patch_line(line: str, *, skip_notification_cols: bool) -> str:
    if skip_notification_cols and (
        'CREATE TABLE IF NOT EXISTS "public"."notifications"' in line
        or 'CREATE TABLE IF NOT EXISTS "public"."tenant_data_purge_logs"' in line
        or "n.parent_tenant_id" in line
        or '"notifications"' in line
        and "parent_tenant_id" in line
        and "CREATE INDEX" in line
    ):
        return line

    if any(s in line for s in PRESERVE_SUBSTRINGS):
        return line

    line = patch_p_row_cashbook(line)
    line = patch_dot_refs(line)

    # INSERT / column lists (books owner on bills + lines)
    line = line.replace(
        "parent_tenant_id, issued_by_tenant_id",
        "tenant_id, issued_by_tenant_id",
    )
    line = line.replace("invoice_id, parent_tenant_id", "invoice_id, tenant_id")
    line = line.replace(
        "UPDATE OF \"operating_tenant_id\", \"parent_tenant_id\"",
        'UPDATE OF "operating_tenant_id", "tenant_id"',
    )

    if "wa.parent_tenant_id" in line or "wa2.parent_tenant_id" in line:
        return line
    if "n.parent_tenant_id" in line and skip_notification_cols:
        return line

    # RLS / indexes / constraints on 8c tables (quoted column)
    if "recipient_profiles" in line or "cashbook_accounts" in line:
        if '"parent_tenant_id"' in line:
            return line

    if '"parent_tenant_id"' in line:
        if skip_notification_cols and (
            "notifications" in line or "tenant_data_purge_logs" in line
        ):
            return line
        line = line.replace('"parent_tenant_id"', '"tenant_id"')

    return line


def patch_compat_views(text: str) -> str:
    text = text.replace(
        '"parent_tenant_id" AS "tenant_id",\n    "parent_tenant_id",',
        '"tenant_id",\n    "tenant_id" AS "parent_tenant_id",',
    )
    text = text.replace(
        '"parent_tenant_id",\n    "parent_tenant_id" AS "tenant_id",',
        '"tenant_id",\n    "tenant_id" AS "parent_tenant_id",',
    )
    return text


def patch_file(path: Path, *, skip_notification_cols: bool) -> None:
    raw = path.read_text(encoding="utf-8")
    text = patch_create_table_blocks(raw)
    text = patch_compat_views(text)
    lines = [patch_line(ln, skip_notification_cols=skip_notification_cols) for ln in text.splitlines()]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    for p in sorted((ROOT / "supabase/schemas/bills_pays").glob("*.sql")):
        patch_file(p, skip_notification_cols=False)
        print("patched", p.relative_to(ROOT))

    public = ROOT / "supabase/schemas/public.sql"
    patch_file(public, skip_notification_cols=True)
    print("patched", public.relative_to(ROOT))


if __name__ == "__main__":
    main()

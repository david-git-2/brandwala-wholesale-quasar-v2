#!/usr/bin/env python3
"""Remove SQL objects from public.sql that already live under supabase/schemas/shop_order/."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHOP_ORDER = ROOT / "supabase/schemas/shop_order"
PUBLIC_SQL = ROOT / "supabase/schemas/public.sql"


def collect_shop_order_objects() -> tuple[set[str], set[str], set[str], set[str]]:
    types: set[str] = set()
    tables: set[str] = set()
    funcs: set[str] = set()
    policies: set[str] = set()

    for path in sorted(SHOP_ORDER.glob("*.sql")):
        text = path.read_text(encoding="utf-8")
        for m in re.finditer(r'CREATE TYPE "public"\."(\w+)"', text):
            types.add(m.group(1))
        for m in re.finditer(r'CREATE TABLE IF NOT EXISTS "public"\."(\w+)"', text):
            tables.add(m.group(1))
        for m in re.finditer(r'CREATE OR REPLACE FUNCTION "public"\."(\w+)"', text):
            funcs.add(m.group(1))
        for m in re.finditer(r'CREATE POLICY "([^"]+)" ON "public"\."(\w+)"', text):
            policies.add(m.group(1))

    sequences = {f"{t}_id_seq" for t in tables}
    sequences.update(
        {
            "shop_customer_group_access_id_seq",
            "shop_order_item_stock_picks_id_seq",
        }
    )
    return types, tables, funcs, policies | set()  # policies matched by name in stmt


def references_shop_object(stmt: str, types: set[str], tables: set[str], funcs: set[str]) -> bool:
    s = stmt.strip()
    if not s:
        return False

    m = re.match(r'CREATE TYPE "public"\."(\w+)"', s)
    if m and m.group(1) in types:
        return True

    m = re.match(r'ALTER TYPE "public"\."(\w+)"', s)
    if m and m.group(1) in types:
        return True

    m = re.match(r'CREATE TABLE IF NOT EXISTS "public"\."(\w+)"', s)
    if m and m.group(1) in tables:
        return True

    m = re.match(r'ALTER TABLE (?:ONLY )?"public"\."(\w+)"', s)
    if m and m.group(1) in tables:
        return True

    m = re.match(r'COMMENT ON (?:COLUMN |TABLE )?"public"\."(\w+)"', s)
    if m and m.group(1) in tables:
        return True

    m = re.match(r'CREATE OR REPLACE FUNCTION "public"\."(\w+)"', s)
    if m and m.group(1) in funcs:
        return True

    m = re.match(r'ALTER FUNCTION "public"\."(\w+)"', s)
    if m and m.group(1) in funcs:
        return True

    m = re.match(r'CREATE POLICY "([^"]+)" ON "public"\."(\w+)"', s)
    if m and m.group(2) in tables:
        return True

    m = re.match(r'CREATE (?:UNIQUE )?INDEX (?:"[^"]+" )?ON "public"\."(\w+)"', s)
    if m and m.group(1) in tables:
        return True

    m = re.match(r'CREATE (?:UNIQUE )?INDEX (?:"[^"]+" )?ON ONLY "public"\."(\w+)"', s)
    if m and m.group(1) in tables:
        return True

    m = re.match(r'CREATE TRIGGER "([^"]+)" (?:BEFORE|AFTER|INSTEAD OF)', s)
    if m and f'ON "public"."' in s:
        for t in tables:
            if f'ON "public"."{t}"' in s:
                return True

    if re.match(r'GRANT ', s):
        for t in tables:
            if f'TABLE "public"."{t}"' in s or f'SEQUENCE "public"."{t}' in s:
                return True
        for f in funcs:
            if f'FUNCTION "public"."{f}"' in s:
                return True

    if re.match(r'ALTER SEQUENCE "public"\."(\w+)"', s):
        if any(seq in s for seq in (f"{t}_id_seq" for t in tables)):
            return True

    m = re.match(r'ALTER TABLE ONLY "public"\."(\w+)"', s)
    if m and m.group(1) in tables:
        return True

    # FK / constraint blocks reference table in ALTER TABLE ONLY
    if s.startswith("ALTER TABLE ONLY "):
        for t in tables:
            if f'"public"."{t}"' in s:
                return True

    return False


def split_statements(sql: str) -> list[str]:
    """Split pg_dump SQL into statements (handles dollar-quoted function bodies)."""
    statements: list[str] = []
    buf: list[str] = []
    i = 0
    n = len(sql)
    dollar_tag: str | None = None

    def flush() -> None:
        if buf:
            statements.append("".join(buf))
            buf.clear()

    while i < n:
        if dollar_tag is None:
            if sql[i : i + 2] == "$$":
                dollar_tag = "$$"
                buf.append("$$")
                i += 2
                continue
            m = re.match(r"\$([A-Za-z_][A-Za-z0-9_]*)\$", sql[i:])
            if m:
                dollar_tag = m.group(0)
                buf.append(dollar_tag)
                i += len(dollar_tag)
                continue
            if sql[i] == ";":
                buf.append(";")
                i += 1
                flush()
                continue
            buf.append(sql[i])
            i += 1
        else:
            if sql.startswith(dollar_tag, i):
                buf.append(dollar_tag)
                i += len(dollar_tag)
                dollar_tag = None
                continue
            buf.append(sql[i])
            i += 1

    flush()
    return statements


def main() -> int:
    types, tables, funcs, _ = collect_shop_order_objects()
    original = PUBLIC_SQL.read_text(encoding="utf-8")
    statements = split_statements(original)

    kept: list[str] = []
    removed = 0
    for stmt in statements:
        if references_shop_object(stmt, types, tables, funcs):
            removed += 1
            continue
        kept.append(stmt)

    new_sql = "".join(kept)
    # collapse excessive blank lines
    new_sql = re.sub(r"\n{4,}", "\n\n\n", new_sql)
    PUBLIC_SQL.write_text(new_sql, encoding="utf-8")
    print(f"Removed {removed} statements ({len(statements) - removed} kept)")
    print(f"types={len(types)} tables={len(tables)} funcs={len(funcs)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

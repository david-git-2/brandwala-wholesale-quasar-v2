#!/usr/bin/env python3
"""Second pass: unqualified parent_tenant_id column refs -> tenant_id (8c)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

SKIP_LINE = (
    "resolve_parent_tenant_id",
    "user_can_manage_parent_tenant",
    "set_parent_tenant_id",
    "p_parent_tenant_id",
    "trg_recipient_profiles_set_parent_tenant_id",
    "parent_tenant_id is required",
    "ca.parent_tenant_id",
    "wa.parent_tenant_id",
    "wa2.parent_tenant_id",
    "'parent_tenant_id'",
    '"parent_tenant_id"',  # json keys — handled separately
)

SKIP_FILE_NOTIFICATION = ("notifications", "tenant_data_purge_logs", "n.parent_tenant_id")


def should_skip_line(line: str, *, public_mode: bool) -> bool:
    if any(s in line for s in SKIP_LINE):
        return True
    if public_mode and any(s in line for s in SKIP_FILE_NOTIFICATION):
        if "CREATE TABLE" in line or "n.parent_tenant_id" in line:
            return True
    if "recipient_profiles" in line and "parent_tenant_id" in line:
        return True
    return False


def fix_rls_quoted(line: str) -> str:
    if "recipient_profiles" in line:
        return line
    line = line.replace('("parent_tenant_id")', '("tenant_id")')
    line = line.replace('user_can_manage_parent_tenant("parent_tenant_id")', 'user_can_manage_parent_tenant("tenant_id")')
    line = line.replace('membership_has_module_action("parent_tenant_id"', 'membership_has_module_action("tenant_id"')
    line = line.replace('has_active_tenant_membership("parent_tenant_id")', 'has_active_tenant_membership("tenant_id")')
    line = line.replace("where parent_tenant_id =", "where tenant_id =")
    line = line.replace("WHERE parent_tenant_id =", "WHERE tenant_id =")
    return line


def fix_unqualified(line: str, *, public_mode: bool) -> str:
    if should_skip_line(line, public_mode=public_mode):
        return line
    # gs / v_ship shipment stock (8b column is tenant_id)
    line = line.replace("gs.parent_tenant_id", "gs.tenant_id")
    line = line.replace("v_ship.parent_tenant_id", "v_ship.tenant_id")
    line = line.replace("s.parent_tenant_id", "s.tenant_id")
    line = line.replace("l.parent_tenant_id", "l.tenant_id")
    line = line.replace("p.parent_tenant_id", "p.tenant_id")

    def repl(m: re.Match[str]) -> str:
        return "tenant_id"

    return re.sub(r"(?<![\w.])parent_tenant_id(?![\w.])", repl, line)


def process(path: Path, *, public_mode: bool) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    out = []
    for ln in lines:
        ln = fix_rls_quoted(ln)
        ln = fix_unqualified(ln, public_mode=public_mode)
        out.append(ln)
    path.write_text("\n".join(out) + "\n", encoding="utf-8")


def main() -> None:
    for p in sorted((ROOT / "supabase/schemas/bills_pays").glob("*.sql")):
        process(p, public_mode=False)
    process(ROOT / "supabase/schemas/public.sql", public_mode=True)
    print("second pass done")


if __name__ == "__main__":
    main()

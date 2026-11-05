#!/usr/bin/env python3
"""Build phase 8d migration."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUBLIC = ROOT / "supabase/schemas/public.sql"
OUT = ROOT / "supabase/migrations/20261105224000_tenant_id_phase8d_notifications_stragglers.sql"

NOTIFICATION_FUNCS = frozenset(
    {
        "enqueue_notification",
        "get_my_notification_unread_count",
        "list_my_notifications_paginated",
        "mark_all_my_notifications_read",
        "mark_notification_read",
    }
)

FUNC_START = re.compile(r'CREATE OR REPLACE FUNCTION "public"\."(\w+)"', re.MULTILINE)


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


def main() -> None:
    text = PUBLIC.read_text(encoding="utf-8")
    parts = [
        "-- Phase 8d: notifications + tenant_data_purge_logs column rename.\n",
        "ALTER TABLE public.notifications RENAME COLUMN parent_tenant_id TO tenant_id;\n",
        "ALTER TABLE public.tenant_data_purge_logs RENAME COLUMN parent_tenant_id TO tenant_id;\n",
        "\nDROP INDEX IF EXISTS public.notifications_parent_operating_created_idx;\n",
        "DROP INDEX IF EXISTS public.notifications_parent_tenant_created_idx;\n",
        'CREATE INDEX "notifications_parent_operating_created_idx" ON public.notifications USING btree (tenant_id, operating_tenant_id, created_at DESC);\n',
        'CREATE INDEX "notifications_parent_tenant_created_idx" ON public.notifications USING btree (tenant_id, created_at DESC);\n',
        "\nDROP POLICY IF EXISTS tenant_data_purge_logs_select ON public.tenant_data_purge_logs;\n",
        'CREATE POLICY "tenant_data_purge_logs_select" ON public.tenant_data_purge_logs FOR SELECT TO authenticated USING ((public.is_superadmin() OR public.user_can_manage_parent_tenant(tenant_id)));\n',
        "\n-- notification RPCs\n",
    ]
    for m in FUNC_START.finditer(text):
        name = m.group(1)
        if name not in NOTIFICATION_FUNCS:
            continue
        stmt = extract_from(m.start(), text).strip()
        parts.append("\n" + stmt + "\n")

    OUT.write_text("".join(parts), encoding="utf-8")
    print(f"Wrote {OUT.name}")


if __name__ == "__main__":
    main()

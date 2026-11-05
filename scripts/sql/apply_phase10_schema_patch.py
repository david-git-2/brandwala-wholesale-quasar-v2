#!/usr/bin/env python3
"""Phase 10: remove parent_tenant_id column semantics; rename books RPCs in declarative schema."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMA_FILES = [ROOT / "supabase/schemas/public.sql"] + sorted(
    (ROOT / "supabase/schemas/bills_pays").glob("*.sql")
)

# Longest-first renames (functions / triggers)
NAME_REPLACEMENTS = [
    ("resolve_parent_tenant_id", "resolve_books_tenant_id"),
    ("user_can_manage_parent_tenant", "user_can_manage_books_tenant"),
    ("can_manage_products_for_parent", "can_manage_products_for_books_tenant"),
    ("can_view_products_for_parent", "can_view_products_for_books_tenant"),
    ("set_products_catalog_parent_tenant_id", "set_products_catalog_books_tenant_id"),
    ("trg_products_set_parent_tenant_id", "trg_products_set_books_tenant_id"),
    ("trg_recipient_profiles_set_parent_tenant_id", "trg_recipient_profiles_set_books_tenant_id"),
    ("set_parent_tenant_id_from_tenant", "set_books_tenant_id_from_tenant"),
]

QUALIFIED_COLUMN = [
    ("wa2.parent_tenant_id", "wa2.tenant_id"),
    ("wa.parent_tenant_id", "wa.tenant_id"),
    ("w.parent_tenant_id", "w.tenant_id"),
    ("ca.parent_tenant_id", "ca.tenant_id"),
    ("cpp.parent_tenant_id", "cpp.tenant_id"),
    ("cp.parent_tenant_id", "cp.tenant_id"),
    ("v_invoice.parent_tenant_id", "v_invoice.tenant_id"),
    ("v_inv.parent_tenant_id", "v_inv.tenant_id"),
    ("v_parent.parent_tenant_id", "v_parent.tenant_id"),
    ("v_row.parent_tenant_id", "v_row.tenant_id"),
    ("v_bill.parent_tenant_id", "v_bill.tenant_id"),
    ("gs.parent_tenant_id", "gs.tenant_id"),
    ("l.parent_tenant_id", "l.tenant_id"),
    ("s.parent_tenant_id", "s.tenant_id"),
    ("p.parent_tenant_id", "p.tenant_id"),
    ("r.parent_tenant_id", "r.tenant_id"),
    ("i.parent_tenant_id", "i.tenant_id"),
    ("b.parent_tenant_id", "b.tenant_id"),
    ("bl.parent_tenant_id", "bl.tenant_id"),
    ("new.parent_tenant_id", "new.tenant_id"),
    ("old.parent_tenant_id", "old.tenant_id"),
]

COMPAT_VIEW_LINE = re.compile(
    r'^\s*"tenant_id"\s+AS\s+"parent_tenant_id",\s*$',
    re.MULTILINE,
)

CASHBOOK_DUP = (
    '    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,\n'
    '    "tenant_id" bigint NOT NULL,\n'
    '    CONSTRAINT "wallet_accounts_available_non_negative"'
)


def patch_text(text: str) -> str:
    for old, new in NAME_REPLACEMENTS:
        text = text.replace(old, new)

    for old, new in QUALIFIED_COLUMN:
        text = text.replace(old, new)

    text = COMPAT_VIEW_LINE.sub("", text)

    # JSON / payload keys
    text = text.replace("'parent_tenant_id'", "'tenant_id'")
    text = text.replace('"parent_tenant_id"', '"tenant_id"')
    text = text.replace("p_payload->>'parent_tenant_id'", "p_payload->>'tenant_id'")
    text = text.replace("nullif(p_payload->>'parent_tenant_id'", "nullif(p_payload->>'tenant_id'")

    # Exception messages
    text = text.replace("parent_tenant_id is required", "tenant_id is required")

    # Variables (after function renames so v_resolve_* not affected)
    text = re.sub(r"\bv_parent_tenant_id\b", "v_books_tenant_id", text)
    text = re.sub(r"\bp_parent_tenant_id\b", "p_books_tenant_id", text)

    # Alias in SELECT lists
    text = re.sub(
        r"\bAS\s+parent_tenant_id\b",
        "AS tenant_id",
        text,
        flags=re.IGNORECASE,
    )

    # Index / constraint identifier suffix (keep tenants.parent_id untouched)
    text = text.replace("_parent_tenant_id", "_tenant_id")

    # recipient_profiles stale dual-column RLS in bills_pays — align with tenant_id-only table
    text = text.replace(
        '(("tenant_id" IS NOT NULL) AND ("public"."has_active_tenant_membership"("tenant_id") OR "public"."user_can_manage_books_tenant"("tenant_id")))',
        '("public"."has_active_tenant_membership"("tenant_id") OR "public"."user_can_manage_books_tenant"("tenant_id"))',
    )
    # Simpler: remove clauses referencing dropped parent_tenant_id column on recipient_profiles
    text = re.sub(
        r'\(\("tenant_id"\s+IS\s+NOT\s+NULL\)\s+AND\s+\((?:[^()"]|"[^"]*")*\)\)',
        lambda m: m.group(0)
        if "recipient_profiles" not in m.group(0)
        else '("public"."has_active_tenant_membership"("tenant_id") OR "public"."user_can_manage_books_tenant"("tenant_id"))',
        text,
        count=0,
    )

    # Unqualified column refs (last — skips tenants.parent_id because it's parent_id not parent_tenant_id)
    text = re.sub(r"(?<![\w.])parent_tenant_id(?![\w.])", "tenant_id", text)

    # Fix over-replace on tenants.parent_id — should never happen; guard parent_id
    text = text.replace("tenants.tenant_id", "tenants.parent_id")  # noop safety

    text = text.replace(CASHBOOK_DUP, (
        '    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,\n'
        '    CONSTRAINT "wallet_accounts_available_non_negative"'
    ))

    return text


def fix_recipient_rls(text: str) -> str:
    """Collapse bills_pays recipient_profiles policies that still mention dual columns."""
    if "recipient_profiles_select" not in text:
        return text
    simple_select = (
        'CREATE POLICY "recipient_profiles_select" ON "public"."recipient_profiles" FOR SELECT TO "authenticated" '
        'USING (("public"."has_active_tenant_membership"("tenant_id") OR "public"."user_can_manage_books_tenant"("tenant_id")));'
    )
    simple_write = (
        'CREATE POLICY "recipient_profiles_write" ON "public"."recipient_profiles" TO "authenticated" '
        'USING (("public"."membership_has_module_action"("tenant_id", \'recipient_profile\'::"text", \'edit\'::"text") '
        'OR "public"."membership_has_module_action"("tenant_id", \'customer\'::"text", \'edit\'::"text") '
        'OR "public"."user_can_manage_books_tenant"("tenant_id"))) '
        'WITH CHECK (("public"."membership_has_module_action"("tenant_id", \'recipient_profile\'::"text", \'edit\'::"text") '
        'OR "public"."membership_has_module_action"("tenant_id", \'customer\'::"text", \'edit\'::"text") '
        'OR "public"."user_can_manage_books_tenant"("tenant_id")));'
    )
    text = re.sub(
        r'CREATE POLICY "recipient_profiles_select" ON "public"."recipient_profiles".*?;\n',
        simple_select + "\n",
        text,
        flags=re.DOTALL,
        count=1,
    )
    text = re.sub(
        r'CREATE POLICY "recipient_profiles_write" ON "public"."recipient_profiles".*?;\n',
        simple_write + "\n",
        text,
        flags=re.DOTALL,
        count=1,
    )
    return text


def main() -> None:
    for path in SCHEMA_FILES:
        if not path.exists():
            continue
        original = path.read_text(encoding="utf-8")
        updated = patch_text(original)
        if path.name == "04_rls.sql":
            updated = fix_recipient_rls(updated)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            print("patched", path.relative_to(ROOT))
        else:
            print("unchanged", path.relative_to(ROOT))


if __name__ == "__main__":
    main()

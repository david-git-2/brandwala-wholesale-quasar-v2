---
name: supabase-migration-order
description: >-
  Write and fix Supabase migrations so `pnpm run backend:reset` and
  `backend:pull-prod-data` succeed on an empty DB. Use when adding or editing
  files in supabase/migrations/, fixing migration ordering errors, stub/defer
  migrations, shop_order enum/table ordering, function return-type conflicts, or
  when the user mentions fresh reset, pull-prod-data, SQLSTATE 42704/42P13/42723.
---

Read **`.cursor/rules/supabase-migrations.mdc`** first. This skill adds the workflow.

## Root cause (why prod looked fine but local reset broke)

1. **Prod replays forward only** — objects created by schema push, manual SQL, or later migrations already exist when an older-timestamp file runs.
2. **`backend:reset` replays from empty** — migration filename timestamp is the **only** order. Anything referenced must exist in an **earlier** file.
3. **Backdated RPC files** — e.g. `20260822_*` functions that use types/tables/columns from `20260902_*` or `202708_*`.
4. **Return-type churn** — mid-history migration returns `jsonb`; later migration `CREATE OR REPLACE … RETURNS void` on the **same signature** → `42P13`.
5. **Rename collisions** — `ALTER FUNCTION … RENAME TO post_sales_invoice` when `post_sales_invoice` already exists from a dropship stub.

**Never assume prod state when reviewing migrations.**

## Before you add or edit a migration

### 1. Timestamp sanity

New file timestamp must be **after** every dependency it references.

| You need… | Must appear in an earlier migration |
|-----------|-------------------------------------|
| `public.shop_type_enum` | `*_shop_order_enums.sql` or scaffold |
| `public.shop_orders` | core tables / scaffold |
| enum label in function body | `CREATE TYPE` or `ALTER TYPE ADD VALUE` |
| `membership_has_module_action` | `20260912000100_perm_rls_helper.sql` or later |
| `stock_availability` | `20270814000045_*` or later |
| column on `shops` / `shop_orders` | `ALTER TABLE … ADD COLUMN` with earlier timestamp |

When adding RPCs for a **new module**, prefer one **prerequisites** file immediately before the first consumer:

```text
20260822090000_shop_order_enums.sql
20260822090100_shop_order_core_tables.sql   -- types + tables + helpers only; no RLS policies
20260822100000_shop_order_api_optimization.sql
```

Use `IF NOT EXISTS` on types/tables so later scaffold migrations stay idempotent. **Do not** duplicate RLS policies in prerequisites (Sep scaffold creates them).

### 2. Function rules

```sql
-- Changing return type or OUT params on same signature:
drop function if exists public.foo(bigint, jsonb);
create or replace function public.foo(...) returns jsonb ...

-- Renaming when target name may already exist:
drop function if exists public.post_sales_invoice(bigint);
alter function public.post_global_invoice(bigint) rename to post_sales_invoice;
```

`CREATE OR REPLACE` is OK for same signature + same return type only.

### 3. Enum rules

- Put **full enum** (all labels you need in early RPCs) in the earliest prerequisites file, **or**
- `ALTER TYPE … ADD VALUE` in a file **before** any function that casts to that label.
- Postgres validates enum casts at **function create** time, not at call time.

### 4. When history is already wrong (exceptional)

Do **not** only fix prod mentally.

1. **Stub** the too-early file:

```sql
-- Stub: body moved to 20270814000046_deferred_child_tenant_warehouse_readonly.sql
do $$ begin
  raise notice 'skipped … (deferred to 20270814000046)';
end $$;
```

2. **Defer** full body to `YYYYMMDDHHMMSS_deferred_<name>.sql` placed **after all dependencies** (types, columns, helper functions, enum values).
3. Defer **only** what the early file needed — do not re-apply superseded functions (e.g. skip `create_and_post_stock_movement` if `20270820_*` replaces it).

## Mandatory verify

**Default (local already has prod data):**

```bash
pnpm run backend:local
pnpm run backend:types:local
```

**Empty-DB replay** — only when fixing migration ordering, before first prod pull, or user asks for reset:

```bash
pnpm run backend:reset
```

Must end with `Finished supabase db reset` and **no** `ERROR:` lines. Then optionally:

```bash
pnpm run backend:pull-prod-data   # once — loads prod rows; do not repeat after every migration
pnpm run deploy:backend           # prod push — only when intentional
```

See `.cursor/rules/supabase-local-backend.mdc` — never auto-run `backend:reset` or `backend:restore-dumps` when applying a new migration on an existing local DB.

## Quick grep checks (new migration file)

Replace `NEWFILE.sql` with your file; run from repo root:

```bash
# Enum/type used — who creates it first?
rg 'shop_type_enum|shop_order_status|stock_availability' supabase/migrations/*.sql -l | sort

# Function return-type risk — same name, multiple files
rg 'create or replace function public\.YOUR_FN' supabase/migrations/*.sql
```

If your file’s timestamp sorts **before** the create-type / create-table file, fix ordering before commit.

## Real failures from this repo (do not repeat)

| Symptom | Cause | Fix pattern |
|---------|-------|-------------|
| `type "shop_type_enum" does not exist` | RPC dated Aug 22, enum dated Sep 2 | Prerequisites enums file |
| `policy "shops_select…" already exists` | Prerequisites + scaffold both create policies | Tables only in prerequisites |
| `cannot change return type` (`42P13`) | void ↔ jsonb on same signature | `DROP FUNCTION IF EXISTS` first |
| `function … already exists` (`42723`) | Rename target already defined | Drop duplicate before rename |
| `invalid input value for enum` (`22P02`) | Deferred file before `ADD VALUE` | Move deferred later |

## New feature DDL (normal path)

1. Edit `supabase/schemas/` (not hand-written DDL migrations for features).
2. `pnpm run backend:schema:diff` → `supabase db diff -f short_name`.
3. Review generated migration timestamp is **after** dependencies.
4. `pnpm run backend:local` → `pnpm run backend:types:local` (or `backend:reset` only when proving empty-DB replay).

Hand-write migrations only for **DML** (seeds, backfills). Copy RPC bodies from **`supabase/schemas/`**, never from old migration files (see `AGENTS.md`).

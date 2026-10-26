# Supabase Schema & Domain Split Guide

Declarative SQL lives in `supabase/schemas/`. Production history is anchored by [`supabase/migrations/00000000000000_baseline.sql`](../supabase/migrations/00000000000000_baseline.sql); imperative history is in [`supabase/migrations/_legacy/`](../supabase/migrations/_legacy/).

---

## Declarative layout (current)

| Path | Role |
|------|------|
| `supabase/schemas/_extensions.sql` | `pg_trgm`, `pg_net` (not in `pg_dump`) |
| `supabase/schemas/public.sql` | Full `public` schema DDL |
| `supabase/_domain_splits_archive/` | Pre-squash domain splits (reference only; not loaded by pg-delta) |

`config.toml` sets `[experimental.pgdelta] enabled = true` and `schema_paths` to extensions + `public.sql` only.

---

## Schema changes

1. Edit `supabase/schemas/public.sql` (or re-split a domain into `schemas/<domain>/` and extend `schema_paths` — see archive README).
2. Generate a migration (does **not** apply to the DB):

   ```bash
   pnpm run backend:schema:sync -- my_change_name
   ```

3. Review the new file under `supabase/migrations/`. If it contains unexpected `DROP`s, fix `public.sql` first — do not apply to prod without review.
4. Local apply + types:

   ```bash
   pnpm run backend:local
   pnpm run backend:types:local
   ```

5. Deploy: `pnpm run deploy:backend` after merge (human-approved migrations only).

Do **not** use `supabase db diff` for declarative work; use `declarative sync`. Optional sanity check after reset: `pnpm exec supabase db diff --use-pg-delta` (should be empty).

**DML only** (seeds, backfills, permission rows): hand-write a migration; sync does not see data.

**RPC bodies:** copy from `public.sql` or domain `03_rpcs.sql`, never from `_legacy/` migrations.

---

## Local reset

`pnpm run backend:reset` replays **one** baseline migration (~30–45s), not 1,389 files. Prod data: `backend:pull-prod-data` still resets from migrations then restores dumps.

---

## Domain split tracker (re-split from `public.sql`)

| Domain | Status | Notes |
| :--- | :--- | :--- |
| procurement, shop_order, bills_pays, notifications | Archived splits | See `_domain_splits_archive/` |
| tenants, permissions, tag, thrift, wallet, investor, global_reference | Stub READMEs under `schemas/` | Extract from `public.sql` when you touch the module |

One domain per PR; run `backend:schema:sync` before merge.

---

## Related docs

- [Documentation index](../docs/README.md)
- [Database conventions](../docs/architecture/database.md)

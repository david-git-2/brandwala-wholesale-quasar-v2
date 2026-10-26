# `supabase/schemas/` — declarative public schema

How-to: [doc/supabase-schema.md](../../doc/supabase-schema.md)

| File | Role |
|------|------|
| `_extensions.sql` | Extensions `pg_dump` omits (`pg_trgm`, `pg_net`) |
| `public.sql` | Full `public` schema (source of truth with baseline migration) |

**Migrations:** [`migrations/00000000000000_baseline.sql`](../migrations/00000000000000_baseline.sql) matches prod at squash time; new DDL → `pnpm run backend:schema:sync -- <name>` (`--no-apply`, review SQL, then `backend:local` / deploy).

**Domain splits:** archived under [`../_domain_splits_archive/`](../_domain_splits_archive/) for re-split work. Do not put extra `*.sql` under `schemas/` unless listed in `config.toml` `schema_paths` — pg-delta loads the whole tree.

Legacy replay chain: [`migrations/_legacy/`](../migrations/_legacy/).

# Declarative schema (how to change SQL)

`supabase/schemas/` is the current public schema. Production still only **runs** files in `supabase/migrations/`.

## Layout

| Path | Role |
|------|------|
| `supabase/schemas/_extensions.sql` | `CREATE EXTENSION` (dump omits this) |
| `supabase/schemas/public.sql` | Full public schema until a module is split |
| `supabase/schemas/<domain>/` | Stub until you move that module’s objects here |
| `supabase/migrations/` | History; what `db push` applies |

## Daily change (DDL)

1. `pnpm run env:local` (Docker). Restart `pnpm run dev`.
2. Edit the live SQL in `supabase/schemas/` (usually `public.sql` until split).
3. Preview: `pnpm run backend:schema:diff` (does **not** write a file).
4. If the preview is the change you want: `pnpm exec supabase db diff -f short_name`
5. Review the new file under `supabase/migrations/`. Drop grant/comment/`OWNER TO` noise.
6. `pnpm run backend:reset` (must replay clean).
7. Later: `pnpm run deploy:backend` (push migrations to production).

## Hand-write a migration when

- Seeds, backfills, `INSERT`/`UPDATE`/`DELETE` of rows (module catalog, grants as data).
- Anything `db diff` cannot see.

Do not use `db diff -f` for those.

## Split a module

Tracker and what to type: [SUPABASE_SCHEMA_SPLIT.md](SUPABASE_SCHEMA_SPLIT.md). In Agent mode: `split schema tag` or `split next schema module`.

Move that module’s objects from `public.sql` into `supabase/schemas/<domain>/…sql`. **Delete the copies from `public.sql` in the same PR.** A partial `schemas/` folder looks like “drop the rest of the database.”

## Refresh the dump

```bash
pnpm run backend:schema:dump
```

Overwrites `public.sql` from local Docker. Keep `_extensions.sql`. Do not dump into `supabase/.dumps/` (that folder is gitignored prod **data**).

## First-run `db diff`

Shadow DB applies every migration, then applies `schemas/`. Grant/comment/`OWNER TO` noise and CHECK-constraint recasts are normal. **Do not commit that as a baseline migration.** Fix only real errors that block the shadow (e.g. missing `pg_trgm` — already in `_extensions.sql`).

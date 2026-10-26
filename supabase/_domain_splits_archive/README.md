# Pre-baseline domain split SQL (reference)

Before the declarative baseline squash, modules lived under `supabase/schemas/<domain>/` (`01_types.sql` … `04_rpcs.sql`) alongside `public.sql`.

pg-delta scans **all** `*.sql` under `supabase/schemas/`, so these folders were moved here to avoid duplicate DDL during `declarative sync`.

**Active declarative SQL:** [`schemas/_extensions.sql`](../schemas/_extensions.sql) + [`schemas/public.sql`](../schemas/public.sql) (see `schema_paths` in `config.toml`).

To re-split a domain: extract objects from `public.sql` into new files under `schemas/<domain>/`, update `schema_paths` order, run `pnpm run backend:schema:sync -- <name>` until the generated migration is empty or expected.

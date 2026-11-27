# `comments` declarative SQL

Cross-cutting plain-text comments kernel (polymorphic `entity_type` + `entity_id`). Registered in `supabase/config.toml` `schema_paths`.

- `02_tables.sql` — `comments` table, sequence, indexes, trigger
- `03_rpcs.sql` — `list_comments`, `add_comment`, `soft_delete_comment`
- `04_rls.sql` — RLS, policies, grants
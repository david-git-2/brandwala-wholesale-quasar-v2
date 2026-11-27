# `thrift` declarative SQL

Live declarative schema for the thrift module (split out of `../public.sql` and registered in `supabase/config.toml` `schema_paths`):

- `01_types.sql` — `thrift_*` enums
- `02_tables.sql` — `thrift_*` tables, sequences, constraints, indexes
- `03_rpcs.sql` — `thrift_*` RPCs, helper functions, triggers
- `04_rls.sql` — RLS enablement, policies, and grants

# `costing` declarative SQL

Live declarative schema for the legacy `costing_files` module (split out of `../public.sql` and registered in `supabase/config.toml` `schema_paths`):

- `01_types.sql` — `costing_file_status`, `costing_file_item_status` enums
- `02_tables.sql` — `costing_files`, `costing_file_items`, `costing_file_viewers` tables, sequences, constraints, indexes
- `03_rpcs.sql` — `costing_file*` RPCs, helper functions, triggers
- `04_rls.sql` — RLS enablement, policies, and grants

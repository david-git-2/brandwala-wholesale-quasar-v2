-- =========================================================
-- Seed Store module into the master module catalog
-- This runs for databases that already applied earlier
-- module seed migrations.
-- =========================================================

insert into public.modules (
  key,
  name,
  description,
  is_active
)
values (
  'store',
  'Store',
  'Manage storefront configuration and store-level operations.',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

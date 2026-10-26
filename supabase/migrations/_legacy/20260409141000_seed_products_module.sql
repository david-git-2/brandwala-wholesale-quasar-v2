-- =========================================================
-- Seed Products module into the master module catalog
-- This runs for existing databases that already applied the
-- earlier module seed migration.
-- =========================================================

insert into public.modules (
  key,
  name,
  description,
  is_active
)
values (
  'products',
  'Products',
  'Manage the product catalog and product-level records.',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

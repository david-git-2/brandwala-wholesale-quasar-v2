-- =========================================================
-- Seed vendor module in module catalog
-- =========================================================

insert into public.modules (
  key,
  name,
  description,
  is_active
)
values (
  'vendor',
  'Vendor',
  'Manage vendor records, sourcing, and supplier collaboration.',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

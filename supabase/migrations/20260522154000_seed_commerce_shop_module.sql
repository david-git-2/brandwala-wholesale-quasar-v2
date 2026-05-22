insert into public.modules (
  key,
  name,
  description,
  is_active
)
values (
  'commerce_shop',
  'Commerce Shop',
  'Browse sellable products directly from inventory.',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  updated_at = now();

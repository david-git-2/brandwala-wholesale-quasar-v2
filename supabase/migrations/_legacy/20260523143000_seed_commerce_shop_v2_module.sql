insert into public.modules (
  key,
  name,
  description,
  is_active
)
values (
  'commerce_shop_v2',
  'Commerce Shop v2',
  'Isolated commerce module with dedicated pricing and inventory aggregation flow.',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

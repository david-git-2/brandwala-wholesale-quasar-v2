insert into public.modules (
  key,
  name,
  description,
  is_active
)
values (
  'cart',
  'Cart',
  'Manage customer shopping carts and line items.',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

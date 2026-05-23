insert into public.modules (
  key,
  name,
  description,
  is_active
)
values (
  'commerce_cart',
  'Commerce Cart',
  'Dedicated cart module for commerce shop workflows.',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

delete from public.tenant_modules
where module_key = 'commerce_shop_v2';

delete from public.modules
where key = 'commerce_shop_v2';

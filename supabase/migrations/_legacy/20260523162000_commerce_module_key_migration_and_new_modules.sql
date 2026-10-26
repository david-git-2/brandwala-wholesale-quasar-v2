insert into public.modules (
  key,
  name,
  description,
  is_active
)
values
  (
    'commerce_shop',
    'Commerce Shop',
    'Isolated commerce module with dedicated pricing and inventory aggregation flow.',
    true
  ),
  (
    'commerce_order',
    'Commerce Order',
    'Dedicated order module for commerce shop workflows.',
    true
  ),
  (
    'commerce_invoice',
    'Commerce Invoice',
    'Dedicated invoice module for commerce shop workflows.',
    true
  )
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

update public.tenant_modules tm
set module_key = 'commerce_shop'
where tm.module_key = 'commerce_shop_v2'
  and not exists (
    select 1
    from public.tenant_modules existing
    where existing.tenant_id = tm.tenant_id
      and existing.module_key = 'commerce_shop'
  );

delete from public.tenant_modules
where module_key = 'commerce_shop_v2';

update public.modules
set is_active = false
where key = 'commerce_shop_v2';

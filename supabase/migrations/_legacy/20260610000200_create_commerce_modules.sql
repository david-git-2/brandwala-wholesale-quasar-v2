-- Seed new commerce modules in public.modules and link for all tenants.
begin;

insert into public.modules (
  key,
  name,
  description,
  is_active
)
values
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
  ),
  (
    'commerce_accounting',
    'Commerce Accounting',
    'Dedicated accounting module for commerce shop workflows.',
    true
  )
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

-- Enable the modules for all tenants
insert into public.tenant_modules (tenant_id, module_key)
select id, 'commerce_order'
from public.tenants
on conflict do nothing;

insert into public.tenant_modules (tenant_id, module_key)
select id, 'commerce_invoice'
from public.tenants
on conflict do nothing;

insert into public.tenant_modules (tenant_id, module_key)
select id, 'commerce_accounting'
from public.tenants
on conflict do nothing;

commit;

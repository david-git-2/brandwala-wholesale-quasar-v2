-- ====================================================================
-- Enable commerce_cart module key for all existing tenants.
-- ====================================================================
begin;

insert into public.tenant_modules (tenant_id, module_key, is_active)
select id, 'commerce_cart', true
from public.tenants
on conflict (tenant_id, module_key) do update
set is_active = true;

commit;

-- ====================================================================
-- Migration: Register 'customer' module in catalog and auto-enable for all tenants
-- ====================================================================

begin;

-- 1. Register 'customer' core module in public.modules catalog
insert into public.modules (key, name, description, is_active)
values (
  'customer',
  'Customers',
  'Unified customer groups, wholesale/retail billing profiles, storefront member access, and automated wallet accounts.',
  true
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

-- 2. Insert standard module actions into public.module_actions catalog
insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  ('customer', 'view', 'app', true, true),
  ('customer', 'create', 'app', true, true),
  ('customer', 'edit', 'app', true, true),
  ('customer', 'delete', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true;

-- 3. Auto-enable 'customer' for all existing tenants in public.tenant_modules
insert into public.tenant_modules (tenant_id, module_key, is_active)
select id, 'customer', true
from public.tenants
on conflict (tenant_id, module_key) do update
set is_active = true;

-- 4. Create/update trigger function to auto-enable 'customer' for any new tenant
create or replace function public.auto_enable_customer_module_for_new_tenant()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.tenant_modules (tenant_id, module_key, is_active)
  values (NEW.id, 'customer', true)
  on conflict (tenant_id, module_key) do update set is_active = true;
  return NEW;
end;
$$;

drop trigger if exists trg_auto_enable_customer_module on public.tenants;
create trigger trg_auto_enable_customer_module
  after insert on public.tenants
  for each row
  execute function public.auto_enable_customer_module_for_new_tenant();

commit;

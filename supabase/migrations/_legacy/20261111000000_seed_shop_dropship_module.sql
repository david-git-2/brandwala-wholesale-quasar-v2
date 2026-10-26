-- =========================================================
-- Seed shop_dropship submodule in master module catalog & tenant_modules
-- =========================================================

begin;

-- 1. Insert or update shop_dropship submodule in public.modules catalog
insert into public.modules (key, name, description, is_active, parent_module_key)
values (
  'shop_dropship',
  'Dropship Ops Desk',
  'Manage dropship consignments, couriers, return policies, and payout ledger.',
  true,
  'shop_order'
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

-- 2. Insert module_actions catalog for shop_dropship
insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  ('shop_dropship', 'view', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true;

-- 3. Auto-enable shop_dropship in tenant_modules for all tenants with shop_order or shop_order_mgmt
insert into public.tenant_modules (tenant_id, module_key, is_active)
select distinct tm.tenant_id, 'shop_dropship', true
from public.tenant_modules tm
where tm.module_key in ('shop_order', 'shop_order_mgmt') and tm.is_active = true
on conflict (tenant_id, module_key) do update set
  is_active = true;

commit;



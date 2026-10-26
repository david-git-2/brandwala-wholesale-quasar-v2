-- Shop & Order nav reshape: Shops / Orders / Shipping.
-- Adds shop_shipping. Retires shop_dropship + shop_fulfillment from assignment/nav.
-- Invoice source_module 'shop_dropship' is unchanged (label on global_invoices, not a nav key).

begin;

insert into public.modules (key, name, description, is_active, parent_module_key)
values (
  'shop_shipping',
  'Shipping',
  'Shared courier catalog, pickup/sender, and COD remittance for any shop order that needs delivery (retail or dropship).',
  true,
  'shop_order'
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  ('shop_shipping', 'view', 'app', true, true),
  ('shop_shipping', 'configure', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true,
  tenant_configurable = true;

update public.modules
set
  name = 'Shops',
  description = 'Shop setup: create shops, categories, customer access, listings, and resellers. Staff sidebar: Shops.'
where key = 'shop_config';

update public.modules
set
  name = 'Orders',
  description = 'Staff and customer orders for all shop types, including dropship process-order on the order page. Staff sidebar: Orders.'
where key = 'shop_order_mgmt';

update public.modules
set
  description = 'Parent module. Staff nav is three items: Shops, Orders, Shipping. Dropship is a shop type, not a fourth menu.'
where key = 'shop_order';

-- Keep keys for historical grants / invoice source_module; hide from catalog assignment.
update public.modules
set
  name = 'Dropship (legacy key)',
  description = 'Retired from nav. Dropship process lives on shop_order_mgmt; couriers live on shop_shipping. Do not assign this key to new tenants.',
  is_active = false
where key = 'shop_dropship';

update public.modules
set
  name = 'Fulfillment (legacy key)',
  description = 'Retired from nav. Fulfill actions live on shop_order_mgmt (order page). Do not assign this key to new tenants.',
  is_active = false
where key = 'shop_fulfillment';

insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
values
  ('app', 'staff', 'shop_shipping', 'view', true),
  ('app', 'staff', 'shop_shipping', 'configure', true),
  ('app', 'manager', 'shop_shipping', 'view', true),
  ('app', 'manager', 'shop_shipping', 'configure', true),
  ('app', 'viewer', 'shop_shipping', 'view', true)
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

insert into public.tenant_modules (tenant_id, module_key, is_active)
select distinct tm.tenant_id, 'shop_shipping', true
from public.tenant_modules tm
where tm.module_key in ('shop_order', 'shop_order_mgmt', 'shop_dropship')
  and tm.is_active = true
on conflict (tenant_id, module_key) do update set
  is_active = true;

select public.seed_tenant_roles_and_grants(id) from public.tenants;

insert into public.tenant_role_grants (tenant_role_id, module_key, action, allowed)
select trg.tenant_role_id, 'shop_shipping', 'view', trg.allowed
from public.tenant_role_grants trg
where trg.module_key = 'shop_dropship'
  and trg.action = 'view'
on conflict (tenant_role_id, module_key, action) do update set
  allowed = excluded.allowed;

insert into public.tenant_role_grants (tenant_role_id, module_key, action, allowed)
select trg.tenant_role_id, 'shop_shipping', 'configure', trg.allowed
from public.tenant_role_grants trg
where trg.module_key = 'shop_dropship'
  and trg.action = 'view'
on conflict (tenant_role_id, module_key, action) do update set
  allowed = excluded.allowed;

commit;

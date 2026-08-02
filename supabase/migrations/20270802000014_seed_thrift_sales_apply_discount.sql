-- =========================================================
-- Move apply_discount under thrift_sales (create invoice UI)
-- Deactivate legacy thrift_stock / thrift_shipment copies
-- =========================================================

begin;

insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  ('thrift_sales', 'apply_discount', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true,
  tenant_configurable = true;

insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
values
  ('app', 'staff', 'thrift_sales', 'apply_discount', true),
  ('app', 'manager', 'thrift_sales', 'apply_discount', true),
  ('app', 'cashier', 'thrift_sales', 'apply_discount', true)
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

-- Remove unused apply_discount from stock/shipment (never wired for those modules)
delete from public.system_role_templates
where action = 'apply_discount'
  and module_key in ('thrift_stock', 'thrift_shipment');

delete from public.tenant_role_grants
where action = 'apply_discount'
  and module_key in ('thrift_stock', 'thrift_shipment');

delete from public.membership_grants
where action = 'apply_discount'
  and module_key in ('thrift_stock', 'thrift_shipment');

update public.module_actions
set is_active = false
where action = 'apply_discount'
  and module_key in ('thrift_stock', 'thrift_shipment');

select public.seed_tenant_roles_and_grants(id) from public.tenants;

commit;

-- =========================================================
-- Seed thrift_shipment download action + role templates
-- =========================================================

begin;

insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  ('thrift_shipment', 'download', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true,
  tenant_configurable = true;

insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
values
  ('app', 'staff', 'thrift_shipment', 'download', true),
  ('app', 'manager', 'thrift_shipment', 'download', true)
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

-- Backfill role grants from templates on existing tenants
select public.seed_tenant_roles_and_grants(id) from public.tenants;

commit;

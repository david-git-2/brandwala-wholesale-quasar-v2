begin;

-- =========================================================
-- Missing staff system_role_templates (MASTER_PLAN §15.3 parity)
-- =========================================================
insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
values
  ('app', 'staff', 'inventory', 'view', true),
  ('app', 'staff', 'inventory', 'allocate', true),
  ('app', 'staff', 'global_reference', 'view', true),
  ('app', 'staff', 'reporting_treasury', 'view', true),
  ('app', 'staff', 'shop_order', 'view', true),
  ('app', 'staff', 'investor_reports', 'view', true),
  ('app', 'staff', 'investor_reports', 'export', true),
  ('app', 'staff', 'shipment_reports', 'view', true),
  ('app', 'staff', 'shipment_reports', 'export', true),
  ('app', 'staff', 'parent_dashboard', 'view', true)
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

-- Re-sync system role grants from templates
select public.seed_tenant_roles_and_grants(id) from public.tenants;

commit;

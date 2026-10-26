-- =========================================================
-- Seed thrift_sales module for tenant feature flag + grants
-- =========================================================

begin;

insert into public.modules (key, name, description, is_active)
values (
  'thrift_sales',
  'Thrift Sales',
  'Create and manage sales invoices for thrift inventory.',
  true
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  ('thrift_sales', 'view', 'app', true, true),
  ('thrift_sales', 'create', 'app', true, true),
  ('thrift_sales', 'edit', 'app', true, true),
  ('thrift_sales', 'delete', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true,
  tenant_configurable = true;

-- Staff: full thrift sales access (matches other thrift modules)
insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
values
  ('app', 'staff', 'thrift_sales', 'view', true),
  ('app', 'staff', 'thrift_sales', 'create', true),
  ('app', 'staff', 'thrift_sales', 'edit', true),
  ('app', 'staff', 'thrift_sales', 'delete', true),
  ('app', 'manager', 'thrift_sales', 'view', true),
  ('app', 'manager', 'thrift_sales', 'create', true),
  ('app', 'manager', 'thrift_sales', 'edit', true),
  ('app', 'manager', 'thrift_sales', 'delete', true),
  ('app', 'cashier', 'thrift_sales', 'view', true),
  ('app', 'cashier', 'thrift_sales', 'create', true),
  ('app', 'cashier', 'thrift_sales', 'edit', false),
  ('app', 'cashier', 'thrift_sales', 'delete', false),
  ('app', 'viewer', 'thrift_sales', 'view', true)
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

-- Enable for tenants that already have thrift_stock
insert into public.tenant_modules (tenant_id, module_key, is_active)
select tm.tenant_id, 'thrift_sales', true
from public.tenant_modules tm
where tm.module_key = 'thrift_stock'
  and tm.is_active = true
on conflict (tenant_id, module_key) do update set
  is_active = true;

-- Backfill role grants from templates on existing tenants
select public.seed_tenant_roles_and_grants(id) from public.tenants;

commit;

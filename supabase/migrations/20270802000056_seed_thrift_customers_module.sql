-- =========================================================
-- Seed thrift_customers module (view-only) + widen SELECT RLS
-- =========================================================

begin;

insert into public.modules (key, name, description, is_active)
values (
  'thrift_customers',
  'Thrift Customers',
  'Browse thrift customer profiles created from sales invoices.',
  true
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  ('thrift_customers', 'view', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true,
  tenant_configurable = true;

insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
values
  ('app', 'staff', 'thrift_customers', 'view', true),
  ('app', 'manager', 'thrift_customers', 'view', true),
  ('app', 'cashier', 'thrift_customers', 'view', true),
  ('app', 'viewer', 'thrift_customers', 'view', true)
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

-- Enable for tenants that already have thrift_stock
insert into public.tenant_modules (tenant_id, module_key, is_active)
select tm.tenant_id, 'thrift_customers', true
from public.tenant_modules tm
where tm.module_key = 'thrift_stock'
  and tm.is_active = true
on conflict (tenant_id, module_key) do update set
  is_active = true;

-- Backfill role grants from templates on existing tenants
select public.seed_tenant_roles_and_grants(id) from public.tenants;

-- SELECT: customers module view OR sales view (POS search keeps working)
drop policy if exists select_thrift_customers on public.thrift_customers;
create policy select_thrift_customers
  on public.thrift_customers
  for select
  to authenticated
  using (
    public.membership_has_module_action(tenant_id, 'thrift_customers', 'view')
    or public.membership_has_module_action(tenant_id, 'thrift_sales', 'view')
  );

commit;

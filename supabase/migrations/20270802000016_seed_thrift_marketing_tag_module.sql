-- =========================================================
-- Seed thrift_marketing_tag module (nav view gate only)
-- =========================================================

begin;

insert into public.modules (key, name, description, is_active)
values (
  'thrift_marketing_tag',
  'Thrift Marketing Tags',
  'Print live sale stickers and marketing tags for thrift stock.',
  true
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  ('thrift_marketing_tag', 'view', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true,
  tenant_configurable = true;

insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
values
  ('app', 'staff', 'thrift_marketing_tag', 'view', true),
  ('app', 'manager', 'thrift_marketing_tag', 'view', true),
  ('app', 'cashier', 'thrift_marketing_tag', 'view', true),
  ('app', 'viewer', 'thrift_marketing_tag', 'view', true)
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

-- Enable for tenants that already have thrift_stock
insert into public.tenant_modules (tenant_id, module_key, is_active)
select tm.tenant_id, 'thrift_marketing_tag', true
from public.tenant_modules tm
where tm.module_key = 'thrift_stock'
  and tm.is_active = true
on conflict (tenant_id, module_key) do update set
  is_active = true;

-- Backfill role grants from templates on existing tenants
select public.seed_tenant_roles_and_grants(id) from public.tenants;

commit;

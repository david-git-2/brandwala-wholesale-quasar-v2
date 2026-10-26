-- =========================================================
-- Seed documentation module for tenant feature flag + grants
-- =========================================================

begin;

insert into public.modules (key, name, description, is_active)
values (
  'documentation',
  'Documentation',
  'User guides and feature manuals.',
  true
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values ('documentation', 'view', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true,
  tenant_configurable = true;

-- Preserve current visibility (admin/staff/viewer) until revoked or module disabled
insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
values
  ('app', 'staff', 'documentation', 'view', true),
  ('app', 'viewer', 'documentation', 'view', true)
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

-- Enable for all existing tenants so current behavior is unchanged until turned off
insert into public.tenant_modules (tenant_id, module_key, is_active)
select t.id, 'documentation', true
from public.tenants t
on conflict (tenant_id, module_key) do update set
  is_active = true;

-- Backfill staff/viewer grants from templates on existing tenants
select public.seed_tenant_roles_and_grants(id) from public.tenants;

commit;

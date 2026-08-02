-- =========================================================
-- seed_tenant_roles_and_grants: insert missing grants only.
-- Never overwrite tenant-customized allowed values on conflict.
-- =========================================================

begin;

create or replace function public.seed_tenant_roles_and_grants(p_tenant_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role record;
begin
  -- App default roles
  insert into public.tenant_roles (tenant_id, scope, name, slug, is_system, is_admin, source_app_role)
  values
    (p_tenant_id, 'app', 'Administrator', 'administrator', true, true, 'admin'::public.app_role),
    (p_tenant_id, 'app', 'Staff', 'staff', true, false, 'staff'::public.app_role),
    (p_tenant_id, 'app', 'Viewer', 'viewer', true, false, 'viewer'::public.app_role)
  on conflict (tenant_id, scope, slug) do nothing;

  -- Shop default roles
  insert into public.tenant_roles (tenant_id, scope, name, slug, is_system, is_admin, source_app_role)
  values
    (p_tenant_id, 'shop', 'Customer Admin', 'customer-admin', true, false, null),
    (p_tenant_id, 'shop', 'Negotiator', 'negotiator', true, false, null),
    (p_tenant_id, 'shop', 'Customer Staff', 'customer-staff', true, false, null)
  on conflict (tenant_id, scope, slug) do nothing;

  -- Seed role grants from templates (additive only — preserve customizations)
  for v_role in (
    select id, scope, slug
    from public.tenant_roles
    where tenant_id = p_tenant_id and is_admin = false
  ) loop
    insert into public.tenant_role_grants (tenant_role_id, module_key, action, allowed)
    select v_role.id, t.module_key, t.action, t.allowed
    from public.system_role_templates t
    where t.scope = v_role.scope and t.role_slug = v_role.slug
    on conflict (tenant_role_id, module_key, action) do nothing;
  end loop;
end;
$$;

grant execute on function public.seed_tenant_roles_and_grants(bigint) to authenticated;

commit;

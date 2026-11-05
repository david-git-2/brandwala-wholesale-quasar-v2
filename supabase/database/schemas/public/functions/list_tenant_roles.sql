CREATE FUNCTION public.list_tenant_roles (
  p_tenant_id bigint,
  p_scope     text
)
  RETURNS TABLE (
    id              bigint,
    tenant_id       bigint,
    scope           text,
    name            text,
    slug            text,
    is_system       boolean,
    is_admin        boolean,
    source_app_role public.app_role,
    is_active       boolean,
    created_at      timestamp with time zone,
    updated_at      timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not public.is_superadmin() and not exists (
    select 1 from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  end if;

  return query
  select r.id, r.tenant_id, r.scope, r.name, r.slug, r.is_system, r.is_admin, r.source_app_role, r.is_active, r.created_at, r.updated_at
  from public.tenant_roles r
  where r.tenant_id = p_tenant_id
    and r.scope = p_scope
    and r.is_active = true;
end;
$function$;

GRANT ALL ON FUNCTION public.list_tenant_roles(bigint, text) TO anon;

GRANT ALL ON FUNCTION public.list_tenant_roles(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.list_tenant_roles(bigint, text) TO service_role;
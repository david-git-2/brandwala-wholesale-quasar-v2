CREATE FUNCTION public.list_tenant_role_grants (
  p_tenant_role_id bigint
)
  RETURNS TABLE (
    id               bigint,
    tenant_role_id   bigint,
    module_key       text,
    action           text,
    allowed          boolean,
    updated_by_email text,
    created_at       timestamp with time zone,
    updated_at       timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
begin
  select tr.tenant_id into v_tenant_id
  from public.tenant_roles tr
  where tr.id = p_tenant_role_id;

  if v_tenant_id is null then
    raise exception 'Role not found';
  end if;

  if not public.is_superadmin() and not exists (
    select 1 from public.memberships m
    where m.tenant_id = v_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  end if;

  return query
  select rg.id, rg.tenant_role_id, rg.module_key, rg.action, rg.allowed, rg.updated_by_email, rg.created_at, rg.updated_at
  from public.tenant_role_grants rg
  where rg.tenant_role_id = p_tenant_role_id;
end;
$function$;

GRANT ALL ON FUNCTION public.list_tenant_role_grants(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_tenant_role_grants(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_tenant_role_grants(bigint) TO service_role;
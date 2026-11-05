CREATE FUNCTION public.upsert_tenant_role_grant (
  p_tenant_role_id bigint,
  p_module_key     text,
  p_action         text,
  p_allowed        boolean
)
  RETURNS public.tenant_role_grants
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_role public.tenant_roles;
  v_row public.tenant_role_grants;
begin
  select * into v_role from public.tenant_roles where id = p_tenant_role_id;

  if v_role.id is null then
    raise exception 'Role not found';
  end if;

  if not public.user_is_tenant_admin(v_role.tenant_id) then
    raise exception 'Unauthorized';
  end if;

  if v_role.is_admin = true then
    raise exception 'Cannot assign explicit grants to an Administrator role';
  end if;

  if not (p_module_key = any(public.get_active_module_keys_for_tenant(v_role.tenant_id))) then
    raise exception 'Module is not active for this tenant';
  end if;

  if not exists (
    select 1 from public.module_actions
    where module_key = p_module_key and action = p_action and is_active = true
  ) then
    raise exception 'Invalid or inactive action: % for module %', p_action, p_module_key;
  end if;

  insert into public.tenant_role_grants (
    tenant_role_id,
    module_key,
    action,
    allowed,
    updated_by_email
  )
  values (
    p_tenant_role_id,
    p_module_key,
    p_action,
    p_allowed,
    public.current_user_email()
  )
  on conflict (tenant_role_id, module_key, action) do update set
    allowed = excluded.allowed,
    updated_by_email = excluded.updated_by_email,
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.upsert_tenant_role_grant(bigint, text, text, boolean) TO anon;

GRANT ALL ON FUNCTION public.upsert_tenant_role_grant(bigint, text, text, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_tenant_role_grant(bigint, text, text, boolean) TO service_role;
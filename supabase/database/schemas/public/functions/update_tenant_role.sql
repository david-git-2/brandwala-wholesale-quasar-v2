CREATE FUNCTION public.update_tenant_role (
  p_role_id  bigint,
  p_name     text,
  p_is_admin boolean
)
  RETURNS public.tenant_roles
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.tenant_roles;
begin
  select * into v_row from public.tenant_roles where id = p_role_id;

  if v_row.id is null then
    raise exception 'Role not found';
  end if;

  if not public.user_is_tenant_admin(v_row.tenant_id) then
    raise exception 'Unauthorized';
  end if;

  if p_is_admin = true and v_row.is_admin = false and exists (
    select 1 from public.tenant_roles
    where tenant_id = v_row.tenant_id and scope = v_row.scope and is_admin = true and id <> p_role_id
  ) then
    raise exception 'Only one Administrator role is allowed per scope';
  end if;

  if v_row.is_system = true and v_row.is_admin <> p_is_admin then
    raise exception 'Cannot modify admin status of system roles';
  end if;

  update public.tenant_roles
  set
    name = trim(p_name),
    is_admin = p_is_admin,
    updated_at = now()
  where id = p_role_id
  returning * into v_row;

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.update_tenant_role(bigint, text, boolean) TO anon;

GRANT ALL ON FUNCTION public.update_tenant_role(bigint, text, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.update_tenant_role(bigint, text, boolean) TO service_role;
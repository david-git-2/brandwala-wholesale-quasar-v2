CREATE FUNCTION public.delete_tenant_role (
  p_role_id bigint
)
  RETURNS void
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

  if v_row.is_system = true then
    raise exception 'Cannot delete system roles';
  end if;

  if exists (
    select 1 from public.memberships where tenant_role_id = p_role_id
  ) then
    raise exception 'Cannot delete role: members are currently assigned to it';
  end if;

  if exists (
    select 1 from public.customer_group_members where tenant_role_id = p_role_id
  ) then
    raise exception 'Cannot delete role: customer group members are currently assigned to it';
  end if;

  delete from public.tenant_roles where id = p_role_id;
end;
$function$;

GRANT ALL ON FUNCTION public.delete_tenant_role(bigint) TO anon;

GRANT ALL ON FUNCTION public.delete_tenant_role(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delete_tenant_role(bigint) TO service_role;
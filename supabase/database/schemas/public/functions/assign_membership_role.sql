CREATE FUNCTION public.assign_membership_role (
  p_membership_id  bigint,
  p_tenant_role_id bigint
)
  RETURNS public.memberships
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_member public.memberships;
  v_role public.tenant_roles;
begin
  select * into v_member from public.memberships where id = p_membership_id;
  if v_member.id is null then
    raise exception 'Membership not found';
  end if;

  if not public.user_is_tenant_admin(v_member.tenant_id) then
    raise exception 'Unauthorized';
  end if;

  select * into v_role from public.tenant_roles where id = p_tenant_role_id;
  if v_role.id is null then
    raise exception 'Role not found';
  end if;

  if v_role.tenant_id <> v_member.tenant_id then
    raise exception 'Role and Membership must belong to the same tenant';
  end if;

  if v_role.scope <> 'app' then
    raise exception 'Role scope must be app for internal memberships';
  end if;

  update public.memberships
  set
    tenant_role_id = p_tenant_role_id,
    updated_at = now()
  where id = p_membership_id
  returning * into v_member;

  return v_member;
end;
$function$;

GRANT ALL ON FUNCTION public.assign_membership_role(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.assign_membership_role(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.assign_membership_role(bigint, bigint) TO service_role;
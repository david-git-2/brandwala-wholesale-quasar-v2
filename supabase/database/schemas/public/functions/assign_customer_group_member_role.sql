CREATE FUNCTION public.assign_customer_group_member_role (
  p_cgm_id         bigint,
  p_tenant_role_id bigint
)
  RETURNS public.customer_group_members
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_member public.customer_group_members;
  v_group public.customer_groups;
  v_role public.tenant_roles;
  v_books_id bigint;
begin
  select * into v_member from public.customer_group_members where id = p_cgm_id;
  if v_member.id is null then
    raise exception 'Customer group member not found';
  end if;

  select * into v_group from public.customer_groups where id = v_member.customer_group_id;
  if v_group.id is null then
    raise exception 'Customer group not found';
  end if;

  v_books_id := coalesce(v_group.parent_tenant_id, public.resolve_parent_tenant_id(v_group.tenant_id));

  if not public.user_is_tenant_admin(v_books_id) then
    raise exception 'Unauthorized';
  end if;

  select * into v_role from public.tenant_roles where id = p_tenant_role_id;
  if v_role.id is null then
    raise exception 'Role not found';
  end if;

  if public.resolve_parent_tenant_id(v_role.tenant_id) is distinct from v_books_id then
    raise exception 'Role and Customer group member must belong to the same tenant';
  end if;

  if v_role.scope <> 'shop' then
    raise exception 'Role scope must be shop for customer group members';
  end if;

  update public.customer_group_members
  set
    tenant_role_id = p_tenant_role_id,
    updated_at = now()
  where id = p_cgm_id
  returning * into v_member;

  return v_member;
end;
$function$;

GRANT ALL ON FUNCTION public.assign_customer_group_member_role(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.assign_customer_group_member_role(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.assign_customer_group_member_role(bigint, bigint) TO service_role;
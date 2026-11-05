CREATE FUNCTION public.transfer_network_owner (
  p_parent_tenant_id bigint,
  p_new_email        text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_email text := lower(trim(p_new_email));
  v_old_owner public.memberships;
  v_new_membership public.memberships;
  v_owner_role_id bigint;
  v_manager_role_id bigint;
begin
  if not public.is_superadmin() and not public.is_network_owner(p_parent_tenant_id) then
    raise exception 'Only the current network owner or superadmin can transfer ownership';
  end if;

  if v_email = '' then
    raise exception 'p_new_email is required';
  end if;

  select t.parent_id into v_old_owner.tenant_id
  from public.tenants t
  where t.id = p_parent_tenant_id;

  if exists (
    select 1 from public.tenants t
    where t.id = p_parent_tenant_id and t.parent_id is not null
  ) then
    raise exception 'Ownership transfer must target the parent or standalone tenant';
  end if;

  select tr.id into v_owner_role_id
  from public.tenant_roles tr
  where tr.tenant_id = p_parent_tenant_id and tr.scope = 'app' and tr.slug = 'owner'
  limit 1;

  select tr.id into v_manager_role_id
  from public.tenant_roles tr
  where tr.tenant_id = p_parent_tenant_id and tr.scope = 'app' and tr.slug = 'manager'
  limit 1;

  select m.* into v_old_owner
  from public.memberships m
  where m.tenant_id = p_parent_tenant_id
    and m.role = 'owner'::public.app_role
    and m.is_active = true
  order by m.id asc
  limit 1;

  if v_old_owner.id is null then
    raise exception 'No active owner found for tenant %', p_parent_tenant_id;
  end if;

  if lower(trim(v_old_owner.email)) = v_email then
    return jsonb_build_object('success', true, 'owner_membership_id', v_old_owner.id);
  end if;

  update public.memberships
  set
    role = 'manager'::public.app_role,
    tenant_role_id = v_manager_role_id,
    updated_at = now()
  where id = v_old_owner.id;

  select m.* into v_new_membership
  from public.memberships m
  where m.tenant_id = p_parent_tenant_id
    and lower(trim(m.email)) = v_email
  limit 1;

  if v_new_membership.id is null then
    insert into public.memberships (email, tenant_id, role, is_active, tenant_role_id)
    values (v_email, p_parent_tenant_id, 'owner'::public.app_role, true, v_owner_role_id)
    returning * into v_new_membership;
  else
    update public.memberships
    set
      role = 'owner'::public.app_role,
      tenant_role_id = v_owner_role_id,
      is_active = true,
      updated_at = now()
    where id = v_new_membership.id
    returning * into v_new_membership;
  end if;

  return jsonb_build_object(
    'success', true,
    'previous_owner_membership_id', v_old_owner.id,
    'owner_membership_id', v_new_membership.id
  );
end;
$function$;

GRANT ALL ON FUNCTION public.transfer_network_owner(bigint, text) TO anon;

GRANT ALL ON FUNCTION public.transfer_network_owner(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.transfer_network_owner(bigint, text) TO service_role;
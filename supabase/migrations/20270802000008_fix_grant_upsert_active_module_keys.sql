-- Align grant upserts with list/bootstrap/has_module_action:
-- accept expanded submodule keys from get_active_module_keys_for_tenant,
-- not only exact rows in tenant_modules.

begin;

create or replace function public.upsert_tenant_role_grant(
  p_tenant_role_id bigint,
  p_module_key text,
  p_action text,
  p_allowed boolean
)
returns public.tenant_role_grants
language plpgsql
security definer
set search_path = public
volatile
as $$
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
$$;

create or replace function public.upsert_membership_grant(
  p_membership_id bigint,
  p_module_key text,
  p_action text,
  p_effect text
)
returns public.membership_grants
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_member public.memberships;
  v_row public.membership_grants;
begin
  select * into v_member from public.memberships where id = p_membership_id;
  if v_member.id is null then
    raise exception 'Membership not found';
  end if;

  if not public.user_is_tenant_admin(v_member.tenant_id) then
    raise exception 'Unauthorized';
  end if;

  if p_effect not in ('allow', 'deny') then
    raise exception 'Invalid effect: %', p_effect;
  end if;

  if not (p_module_key = any(public.get_active_module_keys_for_tenant(v_member.tenant_id))) then
    raise exception 'Module is not active for this tenant';
  end if;

  if not exists (
    select 1 from public.module_actions
    where module_key = p_module_key and action = p_action and is_active = true
  ) then
    raise exception 'Invalid or inactive action: % for module %', p_action, p_module_key;
  end if;

  insert into public.membership_grants (
    membership_id,
    module_key,
    action,
    effect,
    created_by_email
  )
  values (
    p_membership_id,
    p_module_key,
    p_action,
    p_effect,
    public.current_user_email()
  )
  on conflict (membership_id, module_key, action) do update set
    effect = excluded.effect,
    created_by_email = excluded.created_by_email,
    updated_at = now()
  returning * into v_row;

  perform public.bump_tenant_permission_version(v_member.tenant_id);
  return v_row;
end;
$$;

create or replace function public.upsert_customer_group_member_grant(
  p_cgm_id bigint,
  p_module_key text,
  p_action text,
  p_effect text
)
returns public.customer_group_member_grants
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_member public.customer_group_members;
  v_group public.customer_groups;
  v_row public.customer_group_member_grants;
begin
  select * into v_member from public.customer_group_members where id = p_cgm_id;
  if v_member.id is null then
    raise exception 'Customer group member not found';
  end if;

  select * into v_group from public.customer_groups where id = v_member.customer_group_id;
  if v_group.id is null then
    raise exception 'Customer group not found';
  end if;

  if not public.user_is_tenant_admin(v_group.tenant_id) then
    raise exception 'Unauthorized';
  end if;

  if p_effect not in ('allow', 'deny') then
    raise exception 'Invalid effect: %', p_effect;
  end if;

  if not (p_module_key = any(public.get_active_module_keys_for_tenant(v_group.tenant_id))) then
    raise exception 'Module is not active for this tenant';
  end if;

  if not exists (
    select 1 from public.module_actions
    where module_key = p_module_key and action = p_action and is_active = true
  ) then
    raise exception 'Invalid or inactive action: % for module %', p_action, p_module_key;
  end if;

  insert into public.customer_group_member_grants (
    customer_group_member_id,
    module_key,
    action,
    effect
  )
  values (
    p_cgm_id,
    p_module_key,
    p_action,
    p_effect
  )
  on conflict (customer_group_member_id, module_key, action) do update set
    effect = excluded.effect
  returning * into v_row;

  perform public.bump_tenant_permission_version(v_group.tenant_id);
  return v_row;
end;
$$;

grant execute on function public.upsert_tenant_role_grant(bigint, text, text, boolean) to authenticated;
grant execute on function public.upsert_membership_grant(bigint, text, text, text) to authenticated;
grant execute on function public.upsert_customer_group_member_grant(bigint, text, text, text) to authenticated;

commit;

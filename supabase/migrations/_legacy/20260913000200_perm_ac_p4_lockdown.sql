-- Migration: AC-P4 RPC-only grant access + helper RPCs
begin;

-- =========================================================
-- 1. Fix broken grant list RPCs (alias bug in access check)
-- =========================================================
create or replace function public.list_membership_grants(p_membership_id bigint)
returns table (
  id bigint,
  membership_id bigint,
  module_key text,
  action text,
  effect text,
  created_by_email text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_tenant_id bigint;
begin
  select m.tenant_id into v_tenant_id
  from public.memberships m
  where m.id = p_membership_id;

  if v_tenant_id is null then
    raise exception 'Membership not found';
  end if;

  if not public.is_superadmin() and not public.user_is_tenant_admin(v_tenant_id) then
    raise exception 'Access denied';
  end if;

  return query
  select
    mg.id,
    mg.membership_id,
    mg.module_key,
    mg.action,
    mg.effect,
    mg.created_by_email,
    mg.created_at,
    mg.updated_at
  from public.membership_grants mg
  where mg.membership_id = p_membership_id;
end;
$$;

create or replace function public.list_customer_group_member_grants(p_cgm_id bigint)
returns table (
  id bigint,
  customer_group_member_id bigint,
  module_key text,
  action text,
  effect text
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_tenant_id bigint;
begin
  select cg.tenant_id into v_tenant_id
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where cgm.id = p_cgm_id;

  if v_tenant_id is null then
    raise exception 'Customer group member not found';
  end if;

  if not public.is_superadmin() and not public.user_is_tenant_admin(v_tenant_id) then
    raise exception 'Access denied';
  end if;

  return query
  select
    cgmg.id,
    cgmg.customer_group_member_id,
    cgmg.module_key,
    cgmg.action,
    cgmg.effect
  from public.customer_group_member_grants cgmg
  where cgmg.customer_group_member_id = p_cgm_id;
end;
$$;

-- =========================================================
-- 2. Delete override RPCs (inherit = remove row)
-- =========================================================
create or replace function public.delete_membership_grant(
  p_membership_id bigint,
  p_module_key text,
  p_action text
)
returns void
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_tenant_id bigint;
begin
  select m.tenant_id into v_tenant_id
  from public.memberships m
  where m.id = p_membership_id;

  if v_tenant_id is null then
    raise exception 'Membership not found';
  end if;

  if not public.user_is_tenant_admin(v_tenant_id) then
    raise exception 'Unauthorized';
  end if;

  delete from public.membership_grants
  where membership_id = p_membership_id
    and module_key = p_module_key
    and action = p_action;

  perform public.bump_tenant_permission_version(v_tenant_id);
end;
$$;

create or replace function public.delete_customer_group_member_grant(
  p_cgm_id bigint,
  p_module_key text,
  p_action text
)
returns void
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_tenant_id bigint;
begin
  select cg.tenant_id into v_tenant_id
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where cgm.id = p_cgm_id;

  if v_tenant_id is null then
    raise exception 'Customer group member not found';
  end if;

  if not public.user_is_tenant_admin(v_tenant_id) then
    raise exception 'Unauthorized';
  end if;

  delete from public.customer_group_member_grants
  where customer_group_member_id = p_cgm_id
    and module_key = p_module_key
    and action = p_action;

  perform public.bump_tenant_permission_version(v_tenant_id);
end;
$$;

grant execute on function public.delete_membership_grant(bigint, text, text) to authenticated;
grant execute on function public.delete_customer_group_member_grant(bigint, text, text) to authenticated;

-- =========================================================
-- 3. Bulk override marker RPCs
-- =========================================================
create or replace function public.list_membership_ids_with_overrides(p_tenant_id bigint)
returns table (membership_id bigint)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_superadmin() and not public.user_is_tenant_admin(p_tenant_id) then
    raise exception 'Unauthorized';
  end if;

  return query
  select distinct mg.membership_id
  from public.membership_grants mg
  join public.memberships m on m.id = mg.membership_id
  where m.tenant_id = p_tenant_id;
end;
$$;

create or replace function public.list_cgm_ids_with_overrides(p_customer_group_id bigint)
returns table (customer_group_member_id bigint)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.customer_groups
  where id = p_customer_group_id;

  if v_tenant_id is null then
    raise exception 'Customer group not found';
  end if;

  if not public.is_superadmin() and not public.user_is_tenant_admin(v_tenant_id) then
    raise exception 'Unauthorized';
  end if;

  return query
  select distinct cgmg.customer_group_member_id
  from public.customer_group_member_grants cgmg
  join public.customer_group_members cgm on cgm.id = cgmg.customer_group_member_id
  where cgm.customer_group_id = p_customer_group_id;
end;
$$;

grant execute on function public.list_membership_ids_with_overrides(bigint) to authenticated;
grant execute on function public.list_cgm_ids_with_overrides(bigint) to authenticated;

-- =========================================================
-- 4. Configurable module actions for grant matrices
-- =========================================================
create or replace function public.list_configurable_module_actions(
  p_scope text,
  p_tenant_id bigint
)
returns table (
  id bigint,
  module_key text,
  action text,
  description text,
  scope text,
  tenant_configurable boolean,
  is_active boolean
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if p_scope not in ('app', 'shop', 'investor') then
    raise exception 'Invalid scope: %', p_scope;
  end if;

  if not public.is_superadmin() and not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  end if;

  return query
  select
    ma.id,
    ma.module_key,
    ma.action,
    ma.description,
    ma.scope,
    ma.tenant_configurable,
    ma.is_active
  from public.module_actions ma
  inner join public.tenant_modules tm
    on tm.module_key = ma.module_key
    and tm.tenant_id = p_tenant_id
    and tm.is_active = true
  where ma.is_active = true
    and ma.tenant_configurable = true
    and ma.scope = p_scope
    and ma.scope <> 'platform';
end;
$$;

grant execute on function public.list_configurable_module_actions(text, bigint) to authenticated;

-- Ensure upsert RPCs bump permission version
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

  if not exists (
    select 1 from public.tenant_modules
    where tenant_id = v_member.tenant_id and module_key = p_module_key and is_active = true
  ) then
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

  if not exists (
    select 1 from public.tenant_modules
    where tenant_id = v_group.tenant_id and module_key = p_module_key and is_active = true
  ) then
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

-- =========================================================
-- 5. Lock down direct table access (RPC-only for clients)
-- =========================================================
drop policy if exists "tenant_roles_select_member" on public.tenant_roles;
drop policy if exists "tenant_roles_write_admin" on public.tenant_roles;
drop policy if exists "tenant_role_grants_select_member" on public.tenant_role_grants;
drop policy if exists "tenant_role_grants_write_admin" on public.tenant_role_grants;
drop policy if exists "membership_grants_select_member" on public.membership_grants;
drop policy if exists "membership_grants_write_admin" on public.membership_grants;
drop policy if exists "cg_member_grants_select_member" on public.customer_group_member_grants;
drop policy if exists "cg_member_grants_write_admin" on public.customer_group_member_grants;

revoke all on public.tenant_roles from authenticated;
revoke all on public.tenant_role_grants from authenticated;
revoke all on public.membership_grants from authenticated;
revoke all on public.customer_group_member_grants from authenticated;

commit;

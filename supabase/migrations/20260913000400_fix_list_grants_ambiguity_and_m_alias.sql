-- Fix PL/pgSQL ambiguity and missing table alias 'm' in list_*_grants functions
begin;

-- 1. list_tenant_role_grants
create or replace function public.list_tenant_role_grants(p_tenant_role_id bigint)
returns table (
  id bigint,
  tenant_role_id bigint,
  module_key text,
  action text,
  allowed boolean,
  updated_by_email text,
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
$$;

grant execute on function public.list_tenant_role_grants(bigint) to authenticated;


-- 2. list_membership_grants
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

  if not public.is_superadmin() and not exists (
    select 1 from public.memberships m
    where m.tenant_id = v_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  end if;

  return query
  select mg.id, mg.membership_id, mg.module_key, mg.action, mg.effect, mg.created_by_email, mg.created_at, mg.updated_at
  from public.membership_grants mg
  where mg.membership_id = p_membership_id;
end;
$$;

grant execute on function public.list_membership_grants(bigint) to authenticated;


-- 3. list_customer_group_member_grants
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

  if not public.is_superadmin() and not exists (
    select 1 from public.memberships m
    where m.tenant_id = v_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  end if;

  return query
  select cgmg.id, cgmg.customer_group_member_id, cgmg.module_key, cgmg.action, cgmg.effect
  from public.customer_group_member_grants cgmg
  where cgmg.customer_group_member_id = p_cgm_id;
end;
$$;

grant execute on function public.list_customer_group_member_grants(bigint) to authenticated;

commit;

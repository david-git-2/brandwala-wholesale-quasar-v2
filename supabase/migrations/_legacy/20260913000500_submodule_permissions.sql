begin;

-- =========================================================
-- 1. Redefine has_module_action to support submodule keys
-- =========================================================
create or replace function public.has_module_action(
  p_tenant_id bigint,
  p_module_key text,
  p_action text
)
returns boolean
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_has_app_action boolean;
  v_has_shop_action boolean;
  v_member_id bigint;
  v_tenant_role_id bigint;
  v_role_is_admin boolean;
  v_override_effect text;
  v_role_allowed boolean;
  v_shop_allowed boolean;
begin
  -- Superadmin bypass
  if public.is_superadmin() then
    return true;
  end if;

  -- 1. Check module status for the tenant (supports submodules via expansion helper)
  if not (p_module_key = any(public.get_active_module_keys_for_tenant(p_tenant_id))) then
    return false;
  end if;

  -- 2. parent/child hierarchy blocks module for tenant
  if exists (
    select 1
    from public.tenants
    where id = p_tenant_id
      and parent_id is not null
  ) and p_module_key in (
    'global_shipment', 'global_stock', 'global_stock_type', 'procurement_stock',
    'shipment_reports', 'parent_dashboard', 'investor_reports',
    'investor_profiles', 'investor_capital_ledger', 'investor_shipment_share', 'investor_portal'
  ) then
    return false;
  end if;

  -- 3. Resolve active action entries in module_actions
  select
    exists(
      select 1 from public.module_actions ma
      where ma.module_key = p_module_key and ma.action = p_action
        and ma.scope in ('app', 'investor') and ma.is_active = true
    ),
    exists(
      select 1 from public.module_actions ma
      where ma.module_key = p_module_key and ma.action = p_action
        and ma.scope = 'shop' and ma.is_active = true
    )
  into v_has_app_action, v_has_shop_action;

  -- 4. Check App Scope permissions
  if v_has_app_action and exists (
    select 1 from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    select m.id, m.tenant_role_id, tr.is_admin
    into v_member_id, v_tenant_role_id, v_role_is_admin
    from public.memberships m
    left join public.tenant_roles tr on tr.id = m.tenant_role_id
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true;

    -- Administrator shortcut
    if coalesce(v_role_is_admin, false) = true then
      return true;
    end if;

    -- Member overrides
    select effect
    into v_override_effect
    from public.membership_grants
    where membership_id = v_member_id
      and module_key = p_module_key
      and action = p_action;

    if v_override_effect = 'deny' then
      return false;
    elsif v_override_effect = 'allow' then
      return true;
    end if;

    -- Role grants
    select allowed
    into v_role_allowed
    from public.tenant_role_grants
    where tenant_role_id = v_tenant_role_id
      and module_key = p_module_key
      and action = p_action;

    return coalesce(v_role_allowed, false);

  -- 5. Check Shop Scope permissions
  elsif v_has_shop_action and exists (
    select 1
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    where cg.tenant_id = p_tenant_id
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.is_active = true
      and cg.is_active = true
  ) then
    -- Administrator shortcut check
    if exists (
      select 1
      from public.customer_group_members cgm
      join public.customer_groups cg on cg.id = cgm.customer_group_id
      join public.tenant_roles tr on tr.id = cgm.tenant_role_id
      where cg.tenant_id = p_tenant_id
        and cg.is_active = true
        and cgm.is_active = true
        and lower(trim(cgm.email)) = public.current_user_email()
        and tr.is_admin = true
    ) then
      return true;
    end if;

    -- Resolve overrides and role grants
    select
      coalesce(
        bool_or(case when g.effect = 'allow' then true else null end),
        bool_or(case when g.effect = 'deny' then false else null end),
        bool_or(rg.allowed)
      ) into v_shop_allowed
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    left join public.customer_group_member_grants g
      on g.customer_group_member_id = cgm.id
      and g.module_key = p_module_key
      and g.action = p_action
    left join public.tenant_role_grants rg
      on rg.tenant_role_id = cgm.tenant_role_id
      and rg.module_key = p_module_key
      and rg.action = p_action
    where cg.tenant_id = p_tenant_id
      and cg.is_active = true
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email();

    return coalesce(v_shop_allowed, false);
  end if;

  return false;
end;
$$;

-- =========================================================
-- 2. Redefine list_configurable_module_actions for submodules
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
  where ma.is_active = true
    and ma.tenant_configurable = true
    and ma.scope = p_scope
    and ma.scope <> 'platform'
    and ma.module_key = any(public.get_active_module_keys_for_tenant(p_tenant_id));
end;
$$;

commit;

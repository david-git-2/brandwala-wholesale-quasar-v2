begin;

-- ---------------------------------------------------------------------------
-- Membership update guard (owner / manager desk rules)
-- ---------------------------------------------------------------------------
create or replace function public.guard_membership_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_superadmin() then
    return new;
  end if;

  if old.tenant_id is distinct from new.tenant_id then
    raise exception 'Only superadmin can move memberships across tenants';
  end if;

  if lower(trim(old.email)) = lower(trim(public.current_user_email()))
    and old.email is not distinct from new.email
    and old.role is not distinct from new.role
    and old.is_active is not distinct from new.is_active
    and old.investor_id is not distinct from new.investor_id
    and old.tenant_role_id is not distinct from new.tenant_role_id
    and old.accent_color is not distinct from new.accent_color
    and old.preference is distinct from new.preference
  then
    return new;
  end if;

  if exists (
    select 1
    from public.memberships m
    where m.tenant_id = public.resolve_parent_tenant_id(old.tenant_id)
      and lower(trim(m.email)) = public.current_user_email()
      and m.role = 'owner'::public.app_role
      and m.is_active = true
  ) then
    if old.role = 'owner'::public.app_role and new.role is distinct from old.role then
      raise exception 'Use transfer_network_owner to change the network owner';
    end if;
    if new.role = 'owner'::public.app_role then
      raise exception 'Only transfer_network_owner can assign owner';
    end if;
    return new;
  end if;

  if exists (
    select 1
    from public.memberships m
    where m.tenant_id = old.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.role = 'manager'::public.app_role
      and m.is_active = true
  ) then
    if old.role in ('owner'::public.app_role, 'manager'::public.app_role) then
      raise exception 'Managers cannot modify owner or manager memberships';
    end if;
    if new.role in ('owner'::public.app_role, 'manager'::public.app_role) then
      raise exception 'Managers cannot promote memberships to owner or manager';
    end if;
    return new;
  end if;

  if not public.is_tenant_admin(old.tenant_id) then
    raise exception 'Only tenant admins can update tenant memberships';
  end if;

  if old.role not in ('staff', 'viewer') then
    raise exception 'Tenant admins can only update staff or viewer memberships';
  end if;

  if new.role not in ('staff', 'viewer') then
    raise exception 'Tenant admins cannot promote membership role beyond staff/viewer';
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Network owner / tenant manager helpers
-- ---------------------------------------------------------------------------
create or replace function public.is_network_owner(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id)
      and lower(trim(m.email)) = public.current_user_email()
      and m.role = 'owner'::public.app_role
      and m.is_active = true
  );
$$;

create or replace function public.is_tenant_manager(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.role = 'manager'::public.app_role
      and m.is_active = true
  );
$$;

grant execute on function public.is_network_owner(bigint) to authenticated;
grant execute on function public.is_tenant_manager(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- Admin checks (owner inherits children; manager is per-tenant)
-- ---------------------------------------------------------------------------
create or replace function public.is_tenant_admin(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_network_owner(p_tenant_id)
    or public.is_tenant_manager(p_tenant_id);
$$;

create or replace function public.user_is_tenant_admin(p_tenant_id bigint)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if public.is_superadmin() then
    return true;
  end if;

  if public.is_network_owner(p_tenant_id) or public.is_tenant_manager(p_tenant_id) then
    return true;
  end if;

  return exists (
    select 1
    from public.memberships m
    left join public.tenant_roles tr on tr.id = m.tenant_role_id
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and (
        m.role = 'owner'::public.app_role
        or tr.is_admin = true
      )
  );
end;
$$;

create or replace function public.has_active_tenant_membership(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_superadmin()
    or public.is_network_owner(p_tenant_id)
    or exists (
      select 1
      from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
        and m.tenant_id = p_tenant_id
        and m.is_active = true
    );
$$;

create or replace function public.membership_has_module_action(
  p_tenant_id bigint,
  p_module_key text,
  p_action text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and (
        m.role in ('owner'::public.app_role, 'manager'::public.app_role)
        or public.has_module_action(p_tenant_id, p_module_key, p_action)
      )
  )
  or public.is_network_owner(p_tenant_id);
$$;

create or replace function public.user_can_manage_parent_tenant(p_parent_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_parent_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and (
        m.role = 'owner'::public.app_role
        or public.has_module_action(p_parent_tenant_id, 'procurement_stock', 'manage')
      )
  );
$$;

-- ---------------------------------------------------------------------------
-- Grants: owner (network) and manager get full module access on their desk
-- ---------------------------------------------------------------------------
create or replace function public.get_effective_grants(p_tenant_id bigint)
returns table(module_key text, action text)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_member_id bigint;
  v_tenant_role_id bigint;
  v_role_is_admin boolean;
  v_member_role public.app_role;
begin
  select m.id, m.tenant_role_id, tr.is_admin, m.role
  into v_member_id, v_tenant_role_id, v_role_is_admin, v_member_role
  from public.memberships m
  left join public.tenant_roles tr on tr.id = m.tenant_role_id
  where m.tenant_id = p_tenant_id
    and lower(trim(m.email)) = public.current_user_email()
    and m.is_active = true;

  if public.is_superadmin()
     or public.is_network_owner(p_tenant_id)
     or v_member_role = 'manager'::public.app_role
     or coalesce(v_role_is_admin, false) = true then
    return query
    select ma.module_key, ma.action
    from public.module_actions ma
    join public.tenant_modules tm on tm.module_key = ma.module_key
    where tm.tenant_id = p_tenant_id
      and tm.is_active = true
      and ma.is_active = true
      and (ma.scope <> 'platform' or public.is_superadmin())
      and not (
        exists (
          select 1
          from public.tenants
          where id = p_tenant_id
            and parent_id is not null
        ) and ma.module_key in (
          'global_shipment', 'global_stock', 'global_stock_type', 'procurement_stock',
          'shipment_reports', 'parent_dashboard', 'investor_reports',
          'investor_profiles', 'investor_capital_ledger', 'investor_shipment_share', 'investor_portal'
        )
      );
    return;
  end if;

  return query
  with role_allowed as (
    select rg.module_key, rg.action
    from public.tenant_role_grants rg
    where rg.tenant_role_id = v_tenant_role_id
      and rg.allowed = true
  ),
  with_overrides as (
    select ra.module_key, ra.action from role_allowed ra
    union
    select mg.module_key, mg.action
    from public.membership_grants mg
    where mg.membership_id = v_member_id
      and mg.effect = 'allow'
  ),
  effective as (
    select wo.module_key, wo.action from with_overrides wo
    except
    select mg.module_key, mg.action
    from public.membership_grants mg
    where mg.membership_id = v_member_id
      and mg.effect = 'deny'
  )
  select e.module_key, e.action
  from effective e
  join public.module_actions ma on ma.module_key = e.module_key and ma.action = e.action
  join public.tenant_modules tm on tm.module_key = e.module_key
  where tm.tenant_id = p_tenant_id
    and tm.is_active = true
    and ma.is_active = true
    and (ma.scope <> 'platform' or public.is_superadmin())
    and not (
      exists (
        select 1
        from public.tenants
        where id = p_tenant_id
          and parent_id is not null
      ) and ma.module_key in (
        'global_shipment', 'global_stock', 'global_stock_type', 'procurement_stock',
        'shipment_reports', 'parent_dashboard', 'investor_reports',
        'investor_profiles', 'investor_capital_ledger', 'investor_shipment_share', 'investor_portal'
      )
    );
end;
$$;

-- has_module_action: owner/manager/network-owner desk bypass (preserve shop branch)
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
  v_member_role public.app_role;
  v_override_effect text;
  v_role_allowed boolean;
  v_shop_allowed boolean;
begin
  if public.is_superadmin() then
    return true;
  end if;

  if not (p_module_key = any(public.get_active_module_keys_for_tenant(p_tenant_id))) then
    return false;
  end if;

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

  if v_has_app_action and (
    exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
    or public.is_network_owner(p_tenant_id)
  ) then
    select m.id, m.tenant_role_id, tr.is_admin, m.role
    into v_member_id, v_tenant_role_id, v_role_is_admin, v_member_role
    from public.memberships m
    left join public.tenant_roles tr on tr.id = m.tenant_role_id
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true;

    if public.is_network_owner(p_tenant_id)
       or v_member_role = 'manager'::public.app_role
       or coalesce(v_role_is_admin, false) = true then
      return true;
    end if;

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

    select allowed
    into v_role_allowed
    from public.tenant_role_grants
    where tenant_role_id = v_tenant_role_id
      and module_key = p_module_key
      and action = p_action;

    return coalesce(v_role_allowed, false);

  elsif v_has_shop_action and public.current_customer_group_id(p_tenant_id) is not null then
    if exists (
      select 1
      from public.customer_group_members cgm
      join public.customer_groups cg on cg.id = cgm.customer_group_id
      join public.tenant_roles tr on tr.id = cgm.tenant_role_id
      where cg.id = public.current_customer_group_id(p_tenant_id)
        and cg.is_active = true
        and cgm.is_active = true
        and lower(trim(cgm.email)) = public.current_user_email()
        and tr.is_admin = true
    ) then
      return true;
    end if;

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
    where cg.id = public.current_customer_group_id(p_tenant_id)
      and cg.is_active = true
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email();

    return coalesce(v_shop_allowed, false);
  end if;

  return false;
end;
$$;

-- ---------------------------------------------------------------------------
-- Login + bootstrap
-- ---------------------------------------------------------------------------
create or replace function public.check_login_membership(p_email text, p_scope text)
returns table(
  has_match boolean,
  matched_role public.app_role,
  member_id bigint,
  member_email text,
  member_tenant_id bigint,
  member_is_active boolean,
  member_created_at timestamptz,
  member_updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_roles public.app_role[];
  v_email text;
begin
  case lower(coalesce(p_scope, ''))
    when 'platform' then
      v_roles := array['superadmin'::public.app_role];
    when 'app' then
      v_roles := array[
        'owner'::public.app_role,
        'manager'::public.app_role,
        'staff'::public.app_role,
        'viewer'::public.app_role
      ];
    else
      v_roles := array[]::public.app_role[];
  end case;

  v_email := lower(trim(coalesce(p_email, auth.jwt() ->> 'email', '')));

  select
    m.role,
    m.id,
    m.email,
    m.tenant_id,
    m.is_active,
    m.created_at,
    m.updated_at
  into
    matched_role,
    member_id,
    member_email,
    member_tenant_id,
    member_is_active,
    member_created_at,
    member_updated_at
  from public.memberships m
  where lower(trim(m.email)) = v_email
    and m.is_active = true
    and m.role = any(v_roles)
  order by
    case m.role
      when 'owner' then 1
      when 'manager' then 2
      when 'staff' then 3
      when 'viewer' then 4
      else 99
    end,
    m.id asc
  limit 1;

  has_match := matched_role is not null;
  return next;
end;
$$;

create or replace function public.get_app_bootstrap_context(
  p_email text default null,
  p_tenant_id bigint default null,
  p_membership_id bigint default null
)
returns table(
  member_id bigint,
  member_email text,
  member_role public.app_role,
  member_is_active boolean,
  member_preference jsonb,
  tenant_id bigint,
  tenant_name text,
  tenant_slug text,
  tenant_is_active boolean,
  tenant_preference jsonb,
  active_module_keys text[],
  tenant_role_id bigint,
  is_admin boolean,
  effective_grants jsonb,
  permission_version bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_email text;
  v_member record;
  v_target_tenant_id bigint;
  v_grants jsonb;
  v_perm_version bigint;
  v_is_admin boolean;
begin
  v_email := lower(trim(coalesce(p_email, public.current_user_email())));
  v_target_tenant_id := p_tenant_id;

  select
    m.id,
    lower(trim(m.email)) as email,
    m.role,
    m.is_active,
    m.preference as member_preference,
    m.tenant_role_id,
    t.id as tenant_id,
    t.name as tenant_name,
    t.slug as tenant_slug,
    t.is_active as tenant_is_active,
    t.preference as tenant_preference,
    tr.is_admin
  into v_member
  from public.memberships m
  inner join public.tenants t on t.id = m.tenant_id
  left join public.tenant_roles tr on tr.id = m.tenant_role_id
  where lower(trim(m.email)) = v_email
    and m.is_active = true
    and m.role in ('owner', 'manager', 'staff', 'viewer')
    and (p_tenant_id is null or m.tenant_id = p_tenant_id)
    and (p_membership_id is null or m.id = p_membership_id)
  order by
    case m.role
      when 'owner' then 1
      when 'manager' then 2
      when 'staff' then 3
      when 'viewer' then 4
      else 99
    end,
    m.id asc
  limit 1;

  if v_member.id is null and p_tenant_id is not null and public.is_network_owner(p_tenant_id) then
    select
      m.id,
      lower(trim(m.email)) as email,
      m.role,
      m.is_active,
      m.preference as member_preference,
      m.tenant_role_id,
      t.id as tenant_id,
      t.name as tenant_name,
      t.slug as tenant_slug,
      t.is_active as tenant_is_active,
      t.preference as tenant_preference,
      tr.is_admin
    into v_member
    from public.memberships m
    inner join public.tenants t on t.id = m.tenant_id
    left join public.tenant_roles tr on tr.id = m.tenant_role_id
    where lower(trim(m.email)) = v_email
      and m.is_active = true
      and m.role = 'owner'::public.app_role
      and m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id)
    order by m.id asc
    limit 1;

    if v_member.id is not null then
      select child.id, child.name, child.slug, child.is_active, child.preference
      into v_target_tenant_id, v_member.tenant_name, v_member.tenant_slug,
           v_member.tenant_is_active, v_member.tenant_preference
      from public.tenants child
      where child.id = p_tenant_id;
    end if;
  end if;

  if v_member.id is null then
    return;
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object('module_key', module_key, 'action', action)),
    '[]'::jsonb
  )
  into v_grants
  from public.get_effective_grants(coalesce(v_target_tenant_id, v_member.tenant_id));

  select tpv.version into v_perm_version
  from public.tenant_permission_versions tpv
  where tpv.tenant_id = coalesce(v_target_tenant_id, v_member.tenant_id);

  if v_perm_version is null then
    perform public.bump_tenant_permission_version(coalesce(v_target_tenant_id, v_member.tenant_id));
    v_perm_version := 1;
  end if;

  v_is_admin := v_member.role in ('owner'::public.app_role, 'manager'::public.app_role)
    or coalesce(v_member.is_admin, false);

  member_id := v_member.id;
  member_email := v_member.email;
  member_role := v_member.role;
  member_is_active := v_member.is_active;
  member_preference := coalesce(v_member.member_preference, '{}'::jsonb);
  tenant_id := coalesce(v_target_tenant_id, v_member.tenant_id);
  tenant_name := v_member.tenant_name;
  tenant_slug := v_member.tenant_slug;
  tenant_is_active := v_member.tenant_is_active;
  tenant_preference := coalesce(v_member.tenant_preference, '{}'::jsonb);
  active_module_keys := coalesce(
    public.get_active_module_keys_for_tenant(coalesce(v_target_tenant_id, v_member.tenant_id)),
    '{}'::text[]
  );
  tenant_role_id := v_member.tenant_role_id;
  is_admin := v_is_admin;
  effective_grants := v_grants;
  permission_version := v_perm_version;

  return next;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tenant listing for workspace switcher
-- ---------------------------------------------------------------------------
create or replace function public.list_tenants_by_membership(
  p_tenant_id bigint default null,
  p_email text default null,
  p_role public.app_role default null
)
returns table(
  id bigint,
  name text,
  slug text,
  public_domain text,
  is_active boolean,
  parent_id bigint,
  preference jsonb,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  with direct as (
    select distinct
      t.id,
      t.name,
      t.slug,
      t.public_domain,
      t.is_active,
      t.parent_id,
      t.preference,
      t.created_at,
      t.updated_at
    from public.tenants t
    inner join public.memberships m on m.tenant_id = t.id
    where m.is_active = true
      and (p_tenant_id is null or t.id = p_tenant_id)
      and (p_email is null or lower(trim(m.email)) = lower(trim(p_email)))
      and (p_role is null or m.role = p_role)
  ),
  inherited_children as (
    select distinct
      child.id,
      child.name,
      child.slug,
      child.public_domain,
      child.is_active,
      child.parent_id,
      child.preference,
      child.created_at,
      child.updated_at
    from public.memberships owner_m
    inner join public.tenants child on child.parent_id = owner_m.tenant_id
    where owner_m.is_active = true
      and owner_m.role = 'owner'::public.app_role
      and (p_email is null or lower(trim(owner_m.email)) = lower(trim(p_email)))
      and (p_tenant_id is null or child.id = p_tenant_id)
  )
  select * from direct
  union
  select * from inherited_children
  order by id asc;
$$;

create or replace function public.list_my_admin_tenants()
returns table(
  id bigint,
  name text,
  slug text,
  public_domain text,
  is_active boolean,
  parent_id bigint,
  preference jsonb,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  with owner_roots as (
    select m.tenant_id as root_id
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'owner'::public.app_role
      and m.is_active = true
  ),
  manager_desks as (
    select m.tenant_id as desk_id
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'manager'::public.app_role
      and m.is_active = true
  )
  select
    t.id,
    t.name,
    t.slug,
    t.public_domain,
    t.is_active,
    t.parent_id,
    t.preference,
    t.created_at,
    t.updated_at
  from public.tenants t
  where t.id in (select root_id from owner_roots)
     or t.parent_id in (select root_id from owner_roots)
     or t.id in (select desk_id from manager_desks)
  order by t.id asc;
$$;

-- ---------------------------------------------------------------------------
-- Membership assignment rules
-- ---------------------------------------------------------------------------
create or replace function public.can_assign_membership_role(
  p_target_tenant_id bigint,
  p_target_role public.app_role
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_superadmin()
    or (
      public.is_network_owner(p_target_tenant_id)
      and p_target_role in ('manager', 'staff', 'viewer', 'investor')
    )
    or (
      public.is_tenant_manager(p_target_tenant_id)
      and p_target_role in ('staff', 'viewer', 'investor')
    );
$$;

create or replace function public.transfer_network_owner(
  p_parent_tenant_id bigint,
  p_new_email text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
$$;

grant execute on function public.transfer_network_owner(bigint, text) to authenticated;

-- is_tenant_staff: include owner/manager
create or replace function public.is_tenant_staff(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and (
        m.role in (
          'superadmin'::public.app_role,
          'owner'::public.app_role,
          'manager'::public.app_role
        )
        or public.has_module_action(p_tenant_id, 'shop_order_mgmt', 'view')
      )
  )
  or public.is_network_owner(p_tenant_id);
$$;

commit;

begin;

-- Legacy rows sometimes store a truncated membership/investor email (e.g. 20 chars).
-- JWT always carries the full address, so grant checks fail with "not allowed".

create or replace function public.membership_email_matches_current_user(p_membership_email text)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select case
    when p_membership_email is null or trim(p_membership_email) = '' then false
    else lower(trim(p_membership_email)) = public.current_user_email()
      or (
        auth.uid() is not null
        and exists (
          select 1
          from auth.users u
          where u.id = auth.uid()
            and lower(trim(u.email)) = public.current_user_email()
            and lower(trim(u.email)) like lower(trim(p_membership_email)) || '%'
        )
      )
  end;
$$;

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
      and public.membership_email_matches_current_user(m.email)
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
      and public.membership_email_matches_current_user(m.email)
      and m.role = 'manager'::public.app_role
      and m.is_active = true
  );
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
      where public.membership_email_matches_current_user(m.email)
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
      and public.membership_email_matches_current_user(m.email)
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
      and public.membership_email_matches_current_user(m.email)
      and m.is_active = true
      and (
        m.role = 'owner'::public.app_role
        or public.has_module_action(p_parent_tenant_id, 'procurement_stock', 'manage')
      )
  );
$$;

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
    and public.membership_email_matches_current_user(m.email)
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

create or replace function public.auth_investor_id()
returns bigint
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_investor_id bigint;
begin
  select m.investor_id into v_investor_id
  from public.memberships m
  inner join public.investors i
    on i.id = m.investor_id
    and i.is_active = true
  where public.membership_email_matches_current_user(m.email)
    and m.is_active = true
  order by case when m.role = 'investor'::public.app_role then 0 else 1 end
  limit 1;

  return v_investor_id;
end;
$$;

create or replace function public.get_investor_bootstrap_context(
  p_tenant_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_membership public.memberships;
  v_tenant public.tenants;
  v_perm_version bigint;
begin
  select * into v_tenant from public.tenants where id = p_tenant_id;
  if v_tenant.id is null then raise exception 'tenant not found'; end if;

  select m.* into v_membership
  from public.memberships m
  inner join public.investors i
    on i.id = m.investor_id
    and i.tenant_id = p_tenant_id
    and i.is_active = true
  where m.tenant_id = p_tenant_id
    and public.membership_email_matches_current_user(m.email)
    and m.is_active = true
  limit 1;

  if v_membership.id is null or v_membership.investor_id is null then
    return jsonb_build_object('authenticated', false, 'tenant', row_to_json(v_tenant));
  end if;

  select version into v_perm_version
  from public.tenant_permission_versions
  where tenant_id = p_tenant_id;

  if v_perm_version is null then
    perform public.bump_tenant_permission_version(p_tenant_id);
    v_perm_version := 1;
  end if;

  return jsonb_build_object(
    'authenticated', true,
    'tenant', row_to_json(v_tenant),
    'investor_account', row_to_json(v_membership),
    'portfolio', public.get_investor_portfolio_summary(v_membership.investor_id),
    'module_keys', (
      select coalesce(jsonb_agg(tm.module_key), '[]'::jsonb)
      from public.tenant_modules tm
      where tm.tenant_id = p_tenant_id
        and tm.is_active = true
        and tm.module_key = 'investor_portal'
    ),
    'permission_version', v_perm_version
  );
end;
$$;

-- Repair truncated emails when auth.users gives a unique extension.
alter table public.memberships disable trigger user;

with repairs as (
  select
    m.id as membership_id,
    lower(trim(u.email)) as full_email
  from public.memberships m
  join auth.users u
    on lower(trim(u.email)) like lower(trim(m.email)) || '%'
   and lower(trim(u.email)) <> lower(trim(m.email))
  where trim(coalesce(m.email, '')) <> ''
    and not exists (
      select 1
      from auth.users u2
      where u2.id <> u.id
        and lower(trim(u2.email)) like lower(trim(m.email)) || '%'
    )
)
update public.memberships m
set
  email = r.full_email,
  updated_at = now()
from repairs r
where m.id = r.membership_id;

update public.investors i
set
  email = r.full_email,
  updated_at = now()
from (
  select
    i2.id as investor_id,
    lower(trim(u.email)) as full_email
  from public.investors i2
  join auth.users u
    on lower(trim(u.email)) like lower(trim(i2.email)) || '%'
   and lower(trim(u.email)) <> lower(trim(i2.email))
  where trim(coalesce(i2.email, '')) <> ''
    and not exists (
      select 1
      from auth.users u2
      where u2.id <> u.id
        and lower(trim(u2.email)) like lower(trim(i2.email)) || '%'
    )
) r
where i.id = r.investor_id;

alter table public.memberships enable trigger user;

grant execute on function public.membership_email_matches_current_user(text) to authenticated;

commit;

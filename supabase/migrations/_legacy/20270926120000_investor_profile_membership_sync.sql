begin;

-- Keep investor portal login in sync with investor profiles (memberships.investor_id + email).

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

  if coalesce(current_setting('app.sync_investor_profile_membership', true), '') = '1' then
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

create or replace function public.sync_investor_profile_membership(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_email text,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_linked public.memberships;
  v_by_email public.memberships;
begin
  perform set_config('app.sync_investor_profile_membership', '1', true);

  v_email := lower(trim(coalesce(p_email, '')));

  if v_email = '' then
    update public.memberships
    set
      investor_id = null,
      updated_at = now()
    where tenant_id = p_tenant_id
      and investor_id = p_investor_id;
    perform set_config('app.sync_investor_profile_membership', '0', true);
    return;
  end if;

  select * into v_linked
  from public.memberships m
  where m.tenant_id = p_tenant_id
    and m.investor_id = p_investor_id
  limit 1;

  if v_linked.id is not null then
    update public.memberships
    set
      email = v_email,
      investor_id = p_investor_id,
      is_active = case
        when role = 'investor'::public.app_role then coalesce(p_is_active, true)
        else is_active
      end,
      updated_at = now()
    where id = v_linked.id;
    perform set_config('app.sync_investor_profile_membership', '0', true);
    return;
  end if;

  select * into v_by_email
  from public.memberships m
  where m.tenant_id = p_tenant_id
    and lower(trim(m.email)) = v_email
  limit 1;

  if v_by_email.id is not null then
    update public.memberships
    set
      investor_id = p_investor_id,
      is_active = case
        when v_by_email.role = 'investor'::public.app_role then coalesce(p_is_active, true)
        else is_active
      end,
      updated_at = now()
    where id = v_by_email.id;
    perform set_config('app.sync_investor_profile_membership', '0', true);
    return;
  end if;

  insert into public.memberships (tenant_id, email, role, is_active, investor_id)
  values (
    p_tenant_id,
    v_email,
    'investor'::public.app_role,
    coalesce(p_is_active, true),
    p_investor_id
  );

  perform set_config('app.sync_investor_profile_membership', '0', true);
end;
$$;

create or replace function public.upsert_investor_profile(
  p_id bigint,
  p_tenant_id bigint,
  p_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_is_active boolean,
  p_currency_code text,
  p_notes text
)
returns public.investors
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.investors;
  v_action text;
begin
  v_action := case when p_id is null then 'create' else 'edit' end;
  if not public.membership_has_module_action(p_tenant_id, 'investor_profiles', v_action) then
    raise exception 'not allowed';
  end if;

  if p_id is not null then
    update public.investors
    set
      name = p_name,
      phone = p_phone,
      email = p_email,
      address = p_address,
      is_active = p_is_active,
      currency_code = p_currency_code,
      notes = p_notes,
      updated_at = now()
    where id = p_id and tenant_id = p_tenant_id
    returning * into v_row;

    if v_row.id is null then
      raise exception 'investor not found';
    end if;
  else
    insert into public.investors (
      tenant_id, name, phone, email, address, is_active, currency_code, notes
    ) values (
      p_tenant_id, p_name, p_phone, p_email, p_address, p_is_active, p_currency_code, p_notes
    )
    returning * into v_row;
  end if;

  perform public.sync_investor_profile_membership(
    p_tenant_id,
    v_row.id,
    v_row.email,
    v_row.is_active
  );

  return v_row;
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
  where lower(trim(m.email)) = public.current_user_email()
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
    and lower(trim(m.email)) = public.current_user_email()
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

-- Backfill: link memberships that already share the investor profile email.
alter table public.memberships disable trigger user;

update public.memberships m
set
  investor_id = i.id,
  updated_at = now()
from public.investors i
where i.tenant_id = m.tenant_id
  and trim(coalesce(i.email, '')) <> ''
  and lower(trim(i.email)) = lower(trim(m.email))
  and (m.investor_id is distinct from i.id);

-- Backfill: dedicated investor memberships where email is free.
insert into public.memberships (tenant_id, email, role, is_active, investor_id)
select
  i.tenant_id,
  lower(trim(i.email)),
  'investor'::public.app_role,
  i.is_active,
  i.id
from public.investors i
where trim(coalesce(i.email, '')) <> ''
  and not exists (
    select 1
    from public.memberships m
    where m.tenant_id = i.tenant_id
      and lower(trim(m.email)) = lower(trim(i.email))
  );

alter table public.memberships enable trigger user;

-- Ensure investor_portal module where capital is enabled.
insert into public.tenant_modules (tenant_id, module_key, is_active)
select tm.tenant_id, 'investor_portal', true
from public.tenant_modules tm
where tm.module_key = 'investor_capital'
  and tm.is_active = true
  and not exists (
    select 1
    from public.tenant_modules ip
    where ip.tenant_id = tm.tenant_id
      and ip.module_key = 'investor_portal'
  );

grant execute on function public.sync_investor_profile_membership(bigint, bigint, text, boolean) to authenticated;
grant execute on function public.upsert_investor_profile(bigint, bigint, text, text, text, text, boolean, text, text) to authenticated;
grant execute on function public.auth_investor_id() to authenticated;
grant execute on function public.get_investor_bootstrap_context(bigint) to authenticated;

commit;

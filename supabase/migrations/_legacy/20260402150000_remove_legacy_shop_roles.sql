-- =========================================================
-- Remove legacy shop roles from app_role
-- Keep app_role for internal memberships only
-- =========================================================

drop policy if exists "memberships_insert" on public.memberships;
drop policy if exists "memberships_update" on public.memberships;
drop policy if exists "memberships_delete" on public.memberships;

alter table public.memberships
  drop constraint if exists memberships_role_tenant_check;

alter type public.app_role rename to app_role_legacy;

drop function if exists public.can_manage_membership(bigint, public.app_role_legacy);
drop function if exists public.check_login_membership(text);
drop function if exists public.check_login_membership(text, text);
drop function if exists public.list_tenants_by_membership(bigint, text, public.app_role_legacy);
drop function if exists public.get_tenant_details_by_membership(bigint, text, public.app_role_legacy);
drop function if exists public.get_app_bootstrap_context(text, bigint, bigint);

create type public.app_role as enum (
  'superadmin',
  'admin',
  'staff'
);

alter table public.memberships
  alter column role type public.app_role
  using role::text::public.app_role;

create or replace function public.can_manage_membership(
  p_target_tenant_id bigint,
  p_target_role public.app_role
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    public.is_superadmin()
    or (
      public.is_tenant_admin(p_target_tenant_id)
      and p_target_role in ('staff')
    )
$$;

create or replace function public.check_login_membership(
  p_email text,
  p_scope text
)
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
      v_roles := array['admin'::public.app_role, 'staff'::public.app_role];
    else
      v_roles := array[]::public.app_role[];
  end case;

  v_email := lower(trim(coalesce(p_email, auth.jwt() ->> 'email', '')));

  select m.role,
         m.id,
         m.email,
         m.tenant_id,
         m.is_active,
         m.created_at,
         m.updated_at
  into matched_role,
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
  order by case m.role
    when 'superadmin' then 1
    when 'admin' then 2
    when 'staff' then 3
    else 99
  end
  limit 1;

  has_match := matched_role is not null;
  return next;
end;
$$;

create or replace function public.list_tenants_by_membership(
  p_tenant_id bigint default null,
  p_email text default null,
  p_role public.app_role default null
)
returns table(
  id bigint,
  name text,
  slug text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select distinct
    t.id,
    t.name,
    t.slug,
    t.is_active,
    t.created_at,
    t.updated_at
  from public.tenants t
  inner join public.memberships m
    on m.tenant_id = t.id
  where m.is_active = true
    and (p_tenant_id is null or t.id = p_tenant_id)
    and (
      p_email is null
      or lower(trim(m.email)) = lower(trim(p_email))
    )
    and (p_role is null or m.role = p_role)
  order by t.id asc;
$$;

grant execute on function public.list_tenants_by_membership(bigint, text, public.app_role)
to authenticated;

create or replace function public.get_tenant_details_by_membership(
  p_tenant_id bigint,
  p_email text default null,
  p_role public.app_role default null
)
returns table(
  id bigint,
  name text,
  slug text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select distinct
    t.id,
    t.name,
    t.slug,
    t.is_active,
    t.created_at,
    t.updated_at
  from public.tenants t
  inner join public.memberships m
    on m.tenant_id = t.id
  where t.id = p_tenant_id
    and m.is_active = true
    and (
      p_email is null
      or lower(trim(m.email)) = lower(trim(p_email))
    )
    and (p_role is null or m.role = p_role)
  limit 1;
$$;

grant execute on function public.get_tenant_details_by_membership(bigint, text, public.app_role)
to authenticated;

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
  tenant_id bigint,
  tenant_name text,
  tenant_slug text,
  tenant_is_active boolean,
  active_module_keys text[]
)
language sql
security definer
set search_path = public
stable
as $$
  with matched_member as (
    select
      m.id,
      lower(trim(m.email)) as email,
      m.role,
      m.is_active,
      t.id as tenant_id,
      t.name as tenant_name,
      t.slug as tenant_slug,
      t.is_active as tenant_is_active
    from public.memberships m
    inner join public.tenants t
      on t.id = m.tenant_id
    where lower(trim(m.email)) = lower(trim(coalesce(p_email, public.current_user_email())))
      and m.is_active = true
      and m.role in ('admin', 'staff')
      and (p_tenant_id is null or m.tenant_id = p_tenant_id)
      and (p_membership_id is null or m.id = p_membership_id)
    order by
      case m.role
        when 'admin' then 1
        when 'staff' then 2
        else 99
      end,
      m.id asc
    limit 1
  ),
  module_keys as (
    select
      tm.tenant_id,
      coalesce(
        array_agg(tm.module_key order by tm.module_key)
          filter (where tm.module_key is not null),
        '{}'::text[]
      ) as active_module_keys
    from public.tenant_modules tm
    inner join public.modules mo
      on mo.key = tm.module_key
    where tm.is_active = true
      and mo.is_active = true
    group by tm.tenant_id
  )
  select
    mm.id as member_id,
    mm.email as member_email,
    mm.role as member_role,
    mm.is_active as member_is_active,
    mm.tenant_id,
    mm.tenant_name,
    mm.tenant_slug,
    mm.tenant_is_active,
    coalesce(mk.active_module_keys, '{}'::text[]) as active_module_keys
  from matched_member mm
  left join module_keys mk
    on mk.tenant_id = mm.tenant_id;
$$;

grant execute on function public.get_app_bootstrap_context(text, bigint, bigint)
to authenticated;

create policy "memberships_insert"
on public.memberships
for insert
to authenticated
with check (
  public.is_superadmin()
  or public.can_manage_membership(tenant_id, role)
);

create policy "memberships_update"
on public.memberships
for update
to authenticated
using (
  public.is_superadmin()
  or public.can_manage_membership(tenant_id, role)
)
with check (
  public.is_superadmin()
  or public.can_manage_membership(tenant_id, role)
);

create policy "memberships_delete"
on public.memberships
for delete
to authenticated
using (
  public.is_superadmin()
  or public.can_manage_membership(tenant_id, role)
);

alter table public.memberships
  add constraint memberships_role_tenant_check check (
    (role = 'superadmin' and tenant_id is null)
    or
    (role <> 'superadmin' and tenant_id is not null)
  );

drop type public.app_role_legacy;

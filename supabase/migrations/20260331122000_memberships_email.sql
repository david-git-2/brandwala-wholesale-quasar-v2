-- =========================================================
-- Membership email migration
-- For Supabase / Postgres
-- =========================================================

alter table public.memberships
  add column if not exists email text;

update public.memberships m
set email = lower(trim(p.email))
from public.profiles p
where p.id = m.profile_id
  and (m.email is null or trim(m.email) = '');

update public.memberships
set email = lower(trim(email))
where email is not null;

alter table public.memberships
  alter column email set not null;

alter table public.memberships
  drop constraint if exists memberships_profile_id_fkey;

drop index if exists memberships_profile_id_idx;

alter table public.memberships
  drop column if exists profile_id;

drop index if exists memberships_email_tenant_unique;
create unique index memberships_email_tenant_unique
on public.memberships (lower(trim(email)), coalesce(tenant_id, -1));

drop index if exists memberships_email_idx;
create index memberships_email_idx on public.memberships (lower(trim(email)));

create or replace function public.current_user_email()
returns text
language sql
stable
as $$
  select lower(trim(coalesce(auth.jwt() ->> 'email', '')))
$$;

create or replace function public.is_superadmin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'superadmin'
      and m.is_active = true
      and m.tenant_id is null
  )
$$;

create or replace function public.is_tenant_admin(p_tenant_id bigint)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.tenant_id = p_tenant_id
      and m.role = 'admin'
      and m.is_active = true
  )
$$;

create or replace function public.can_manage_membership(
  p_target_tenant_id bigint,
  p_target_role app_role
)
returns boolean
language sql
stable
as $$
  select
    public.is_superadmin()
    or (
      public.is_tenant_admin(p_target_tenant_id)
      and p_target_role in ('staff', 'viewer', 'customer')
    )
$$;

create or replace function public.check_login_membership(
  p_email text,
  p_scope text
)
returns table(
  has_match boolean,
  matched_role app_role,
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
  v_roles app_role[];
  v_email text;
begin
  case lower(coalesce(p_scope, ''))
    when 'platform' then
      v_roles := array['superadmin'::app_role];
    when 'app' then
      v_roles := array['admin'::app_role, 'staff'::app_role];
    when 'shop' then
      v_roles := array['customer'::app_role, 'viewer'::app_role];
    else
      v_roles := array[]::app_role[];
  end case;

  v_email := lower(trim(coalesce(p_email, public.current_user_email())));

  select m.role
       , m.id
       , m.email
       , m.tenant_id
       , m.is_active
       , m.created_at
       , m.updated_at
  into matched_role
      , member_id
      , member_email
      , member_tenant_id
      , member_is_active
      , member_created_at
      , member_updated_at
  from public.memberships m
  where lower(trim(m.email)) = v_email
    and m.is_active = true
    and m.role = any(v_roles)
  order by case m.role
    when 'superadmin' then 1
    when 'admin' then 2
    when 'staff' then 3
    when 'customer' then 4
    when 'viewer' then 5
    else 99
  end
  limit 1;

  has_match := matched_role is not null;
  return next;
end;
$$;

-- =========================================================
-- Migration: Add preference jsonb column to memberships
-- =========================================================

begin;

alter table public.memberships
  add column if not exists preference jsonb not null default '{}'::jsonb;

-- Redefine get_app_bootstrap_context
drop function if exists public.get_app_bootstrap_context(text, bigint, bigint);

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
      m.preference as member_preference,
      t.id as tenant_id,
      t.name as tenant_name,
      t.slug as tenant_slug,
      t.is_active as tenant_is_active,
      t.preference as tenant_preference
    from public.memberships m
    inner join public.tenants t
      on t.id = m.tenant_id
    where lower(trim(m.email)) = lower(trim(coalesce(p_email, public.current_user_email())))
      and m.is_active = true
      and m.role in ('admin', 'staff', 'viewer')
      and (p_tenant_id is null or m.tenant_id = p_tenant_id)
      and (p_membership_id is null or m.id = p_membership_id)
    order by
      case m.role
        when 'admin' then 1
        when 'staff' then 2
        when 'viewer' then 3
        else 99
      end,
      m.id asc
    limit 1
  )
  select
    mm.id as member_id,
    mm.email as member_email,
    mm.role as member_role,
    mm.is_active as member_is_active,
    coalesce(mm.member_preference, '{}'::jsonb) as member_preference,
    mm.tenant_id,
    mm.tenant_name,
    mm.tenant_slug,
    mm.tenant_is_active,
    coalesce(mm.tenant_preference, '{}'::jsonb) as tenant_preference,
    coalesce(public.get_active_module_keys_for_tenant(mm.tenant_id), '{}'::text[]) as active_module_keys
  from matched_member mm;
$$;

grant execute on function public.get_app_bootstrap_context(text, bigint, bigint) to authenticated;

-- Create update_membership_preference_for_self RPC
drop function if exists public.update_membership_preference_for_self(bigint, jsonb);

create function public.update_membership_preference_for_self(
  p_membership_id bigint,
  p_preference jsonb
)
returns table(
  id bigint,
  email text,
  role public.app_role,
  is_active boolean,
  tenant_id bigint,
  preference jsonb,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
volatile
as $$
begin
  if not exists (
    select 1
    from public.memberships m
    where m.id = p_membership_id
      and lower(trim(m.email)) = lower(trim(public.current_user_email()))
      and m.is_active = true
  ) then
    raise exception 'Unauthorized to update this membership preference';
  end if;

  if jsonb_typeof(p_preference) is distinct from 'object' then
    raise exception 'Membership preference must be a JSON object';
  end if;

  return query
  update public.memberships as m
  set preference = p_preference
  where m.id = p_membership_id
  returning
    m.id,
    m.email,
    m.role,
    m.is_active,
    m.tenant_id,
    m.preference,
    m.created_at,
    m.updated_at;
end;
$$;

grant execute on function public.update_membership_preference_for_self(bigint, jsonb) to authenticated;

commit;

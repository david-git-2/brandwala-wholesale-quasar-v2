-- =========================================================
-- Tenant access by membership filters
-- Any authenticated user can call these RPCs
-- =========================================================

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
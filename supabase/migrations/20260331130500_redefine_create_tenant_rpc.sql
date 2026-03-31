-- =========================================================
-- Tenant create RPC redefinition
-- Use SQL instead of PL/pgSQL to avoid ambiguous id references
-- =========================================================

create or replace function public.create_tenant_for_superadmin(
  p_name text,
  p_slug text,
  p_is_active boolean default true
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
volatile
as $$
  with permission as (
    select public.is_superadmin() as allowed
  ),
  inserted as (
    insert into public.tenants (name, slug, is_active)
    select
      trim(p_name),
      lower(trim(p_slug)),
      coalesce(p_is_active, true)
    from permission
    where allowed
    returning
      id,
      name,
      slug,
      is_active,
      created_at,
      updated_at
  )
  select
    id,
    name,
    slug,
    is_active,
    created_at,
    updated_at
  from inserted;
$$;

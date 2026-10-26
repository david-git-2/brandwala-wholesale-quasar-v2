-- =========================================================
-- Tenant update/delete RPCs
-- Keep tenant mutations behind a superadmin-only definer function
-- =========================================================

create or replace function public.update_tenant_for_superadmin(
  p_tenant_id bigint,
  p_name text,
  p_slug text,
  p_is_active boolean
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
  updated as (
    update public.tenants as t
    set
      name = trim(p_name),
      slug = lower(trim(p_slug)),
      is_active = coalesce(p_is_active, true)
    from permission
    where allowed
      and t.id = p_tenant_id
    returning
      t.id,
      t.name,
      t.slug,
      t.is_active,
      t.created_at,
      t.updated_at
  )
  select
    id,
    name,
    slug,
    is_active,
    created_at,
    updated_at
  from updated;
$$;

create or replace function public.delete_tenant_for_superadmin(
  p_tenant_id bigint
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
  deleted as (
    delete from public.tenants as t
    using permission
    where allowed
      and t.id = p_tenant_id
    returning
      t.id,
      t.name,
      t.slug,
      t.is_active,
      t.created_at,
      t.updated_at
  )
  select
    id,
    name,
    slug,
    is_active,
    created_at,
    updated_at
  from deleted;
$$;

-- =========================================================
-- Tenant list RPC
-- Return tenants only when the current member is a superadmin
-- =========================================================

create or replace function public.list_tenants_for_superadmin()
returns table(
  id bigint,
  name text,
  slug text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_superadmin() then
    return;
  end if;

  return query
  select
    t.id,
    t.name,
    t.slug,
    t.is_active,
    t.created_at,
    t.updated_at
  from public.tenants t
  order by t.id asc;
end;
$$;

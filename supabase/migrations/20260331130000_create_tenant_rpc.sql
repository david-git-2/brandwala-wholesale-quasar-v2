-- =========================================================
-- Tenant create RPC
-- Allow superadmins to create tenants without direct table insert
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
language plpgsql
security definer
set search_path = public
volatile
as $$
begin
  if not public.is_superadmin() then
    return;
  end if;

  return query
  with inserted as (
    insert into public.tenants (name, slug, is_active)
    values (
      trim(p_name),
      lower(trim(p_slug)),
      coalesce(p_is_active, true)
    )
    returning *
  )
  select
    inserted.id,
    inserted.name,
    inserted.slug,
    inserted.is_active,
    inserted.created_at,
    inserted.updated_at
  from inserted;
end;
$$;

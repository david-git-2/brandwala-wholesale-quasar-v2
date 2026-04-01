create or replace function public.list_my_admin_tenants()
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
  select
    t.id,
    t.name,
    t.slug,
    t.is_active,
    t.created_at,
    t.updated_at
  from public.tenants t
  where exists (
    select 1
    from public.memberships m
    where m.tenant_id = t.id
      and lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'
      and m.is_active = true
  )
  order by t.id asc;
$$;

grant execute on function public.list_my_admin_tenants() to authenticated;
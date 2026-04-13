-- =========================================================
-- Store module: admin access listing supports all stores
-- =========================================================

drop function if exists public.get_store_access_admin(bigint);

create or replace function public.get_store_access_admin(
  p_store_id bigint default null
)
returns setof public.store_access
language sql
security definer
set search_path = public
stable
as $$
  select sa.*
  from public.store_access sa
  join public.stores s on s.id = sa.store_id
  where (p_store_id is null or sa.store_id = p_store_id)
    and public.can_manage_store(s.tenant_id)
  order by sa.id asc
$$;

grant execute on function public.get_store_access_admin(bigint)
to authenticated;

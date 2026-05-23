create or replace function public.get_stores_for_customer_v2(
  p_tenant_id bigint default null
)
returns table(
  id bigint,
  name text,
  vendor_code text,
  tenant_id bigint,
  created_at timestamptz,
  updated_at timestamptz,
  see_price boolean
)
language sql
security definer
set search_path = public
stable
as $$
  select
    s.id,
    s.name,
    s.vendor_code,
    s.tenant_id,
    s.created_at,
    s.updated_at,
    bool_or(sa.see_price) as see_price
  from public.stores s
  join public.store_access sa
    on sa.store_id = s.id
  join public.customer_group_members cgm
    on cgm.customer_group_id = sa.customer_group_id
  where sa.status = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
    and (p_tenant_id is null or s.tenant_id = p_tenant_id)
  group by
    s.id,
    s.name,
    s.vendor_code,
    s.tenant_id,
    s.created_at,
    s.updated_at
  order by s.id asc;
$$;

grant execute on function public.get_stores_for_customer_v2(bigint)
to authenticated;

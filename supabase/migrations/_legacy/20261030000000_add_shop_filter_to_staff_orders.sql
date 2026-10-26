-- SQL Migration: Add shop filter to list_shop_orders_for_staff RPC
begin;

drop function if exists public.list_shop_orders_for_staff(bigint, integer, integer, text, text);

create or replace function public.list_shop_orders_for_staff(
  p_tenant_id bigint,
  p_limit integer default 20,
  p_offset integer default 0,
  p_search text default null,
  p_status text default null,
  p_shop_id bigint default null
)
returns table (
  id bigint,
  tenant_id bigint,
  shop_id bigint,
  shop_name text,
  customer_group_id bigint,
  customer_group_name text,
  order_no text,
  name text,
  status public.shop_order_status,
  created_at timestamptz,
  updated_at timestamptz,
  item_count bigint,
  total_amount numeric
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  return query
  select
    o.id,
    o.tenant_id,
    o.shop_id,
    s.name as shop_name,
    o.customer_group_id,
    cg.name as customer_group_name,
    o.order_no,
    o.name,
    o.status,
    o.created_at,
    o.updated_at,
    (select count(*)::bigint from public.shop_order_items where order_id = o.id) as item_count,
    coalesce(
      (
        select sum(coalesce(final_price_amount, staff_offer_amount, customer_offer_amount, unit_sell_price_amount, unit_list_price_amount) * quantity)
        from public.shop_order_items
        where order_id = o.id
      ),
      0
    )::numeric as total_amount
  from public.shop_orders o
  join public.shops s on s.id = o.shop_id
  join public.customer_groups cg on cg.id = o.customer_group_id
  where o.tenant_id = p_tenant_id
    and (p_status is null or o.status::text = p_status)
    and (p_shop_id is null or o.shop_id = p_shop_id)
    and (
      p_search is null 
      or o.order_no ilike ('%' || p_search || '%')
      or o.name ilike ('%' || p_search || '%')
      or s.name ilike ('%' || p_search || '%')
      or cg.name ilike ('%' || p_search || '%')
    )
  order by o.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;

grant execute on function public.list_shop_orders_for_staff(bigint, integer, integer, text, text, bigint) to authenticated;

commit;

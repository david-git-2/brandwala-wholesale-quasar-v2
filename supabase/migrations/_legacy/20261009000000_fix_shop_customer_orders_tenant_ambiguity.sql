-- Fix PL/pgSQL ambiguity: RETURNS TABLE(tenant_id) shadows shops.tenant_id
-- in list_shop_orders_for_customer (42702).

begin;

create or replace function public.list_shop_orders_for_customer(
  p_shop_id bigint,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id bigint,
  tenant_id bigint,
  shop_id bigint,
  customer_group_id bigint,
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
declare
  v_tenant_id bigint;
  v_cust_group_id bigint;
begin
  select s.tenant_id into v_tenant_id
  from public.shops s
  where s.id = p_shop_id;

  select cg.id
  into v_cust_group_id
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where cg.tenant_id = v_tenant_id
    and lower(trim(cgm.email)) = public.current_user_email()
    and cgm.is_active = true
    and cg.is_active = true
  limit 1;

  if v_cust_group_id is null then
    return;
  end if;

  return query
  select
    o.id,
    o.tenant_id,
    o.shop_id,
    o.customer_group_id,
    o.order_no,
    o.name,
    o.status,
    o.created_at,
    o.updated_at,
    (select count(*)::bigint from public.shop_order_items soi where soi.order_id = o.id) as item_count,
    coalesce(
      (
        select sum(
          coalesce(
            soi.final_price_amount,
            soi.customer_offer_amount,
            soi.unit_sell_price_amount,
            soi.unit_list_price_amount
          ) * soi.quantity
        )
        from public.shop_order_items soi
        where soi.order_id = o.id
      ),
      0
    )::numeric as total_amount
  from public.shop_orders o
  where o.shop_id = p_shop_id
    and o.customer_group_id = v_cust_group_id
  order by o.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;

grant execute on function public.list_shop_orders_for_customer(bigint, integer, integer)
  to authenticated;

commit;

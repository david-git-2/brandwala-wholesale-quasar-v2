-- RPC: list dropship desk orders for staff (post-handoff queue)
begin;

create or replace function public.list_dropship_shop_orders_for_staff(
  p_tenant_id bigint,
  p_limit integer default 20,
  p_offset integer default 0,
  p_status text default null,
  p_search text default null
)
returns table (
  id bigint,
  order_no text,
  status public.shop_order_status,
  created_at timestamptz,
  customer_group_name text,
  created_by_email text,
  recipient_name text,
  recipient_phone text,
  courier_name text,
  courier_awb_number text,
  cod_collect_amount numeric,
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
    o.order_no,
    o.status,
    o.created_at,
    cg.name as customer_group_name,
    o.created_by_email,
    o.recipient_name,
    o.recipient_phone,
    coalesce(cs.name, o.courier_name) as courier_name,
    o.courier_awb_number,
    o.cod_collect_amount,
    coalesce(
      (
        select sum(
          coalesce(
            final_price_amount,
            staff_offer_amount,
            customer_offer_amount,
            unit_sell_price_amount,
            unit_list_price_amount
          ) * quantity
        )
        from public.shop_order_items
        where order_id = o.id
      ),
      0
    )::numeric as total_amount
  from public.shop_orders o
  join public.customer_groups cg on cg.id = o.customer_group_id
  left join public.courier_services cs on cs.id::text = o.courier_service_id::text
  where o.tenant_id = p_tenant_id
    and o.shop_type_snapshot = 'dropship'
    and (
      case
        when p_status is null then o.status::text in (
          'processing',
          'ready_for_pickup',
          'shipped',
          'delivered',
          'returned',
          'payment_received'
        )
        else o.status::text = p_status
      end
    )
    and (
      p_search is null
      or o.order_no ilike ('%' || p_search || '%')
      or o.recipient_name ilike ('%' || p_search || '%')
      or o.recipient_phone ilike ('%' || p_search || '%')
      or o.courier_awb_number ilike ('%' || p_search || '%')
      or o.courier_name ilike ('%' || p_search || '%')
      or cs.name ilike ('%' || p_search || '%')
      or cg.name ilike ('%' || p_search || '%')
      or o.created_by_email ilike ('%' || p_search || '%')
    )
  order by o.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;

grant execute on function public.list_dropship_shop_orders_for_staff(bigint, integer, integer, text, text) to authenticated;

commit;

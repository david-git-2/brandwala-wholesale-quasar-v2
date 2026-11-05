CREATE FUNCTION public._recompute_shop_order_item_fulfillment (
  p_order_item_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_item public.shop_order_items%rowtype;
  v_pick_qty integer := 0;
  v_first_held bigint;
  v_weighted_cost numeric(12,4);
begin
  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  if v_item.id is null then
    return;
  end if;

  if coalesce(v_item.is_gift, false) and v_item.gift_source = 'customer_stock' then
    return;
  end if;

  if coalesce(v_item.is_fulfillment_unavailable, false) then
    update public.shop_order_items
    set
      confirmed_quantity = 0,
      global_stock_id = null,
      cost_price_amount = null,
      updated_at = now()
    where id = p_order_item_id;
    return;
  end if;

  select coalesce(sum(sp.quantity), 0)
  into v_pick_qty
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id;

  select sp.held_stock_id
  into v_first_held
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id
  order by sp.id asc
  limit 1;

  select case
    when v_pick_qty > 0 then
      coalesce(
        sum(
          coalesce(public.calculate_landed_unit_cost(sp.shipment_item_id), 0)
          * sp.quantity
        ) / nullif(v_pick_qty, 0),
        v_item.cost_price_amount
      )
    else null
  end
  into v_weighted_cost
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id;

  update public.shop_order_items
  set
    confirmed_quantity = v_pick_qty,
    global_stock_id = v_first_held,
    cost_price_amount = v_weighted_cost,
    updated_at = now()
  where id = p_order_item_id;
end;
$function$;

GRANT ALL ON FUNCTION public._recompute_shop_order_item_fulfillment(bigint) TO anon;

GRANT ALL ON FUNCTION public._recompute_shop_order_item_fulfillment(bigint) TO authenticated;

GRANT ALL ON FUNCTION public._recompute_shop_order_item_fulfillment(bigint) TO service_role;
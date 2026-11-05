CREATE FUNCTION public.remove_dropship_order_gift_item (
  p_order_item_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_pick record;
  v_parent_tenant_id bigint;
  v_stock public.global_stocks%rowtype;
begin
  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  if v_item.id is null then
    return jsonb_build_object('success', false, 'error', 'order item not found');
  end if;

  if not coalesce(v_item.is_gift, false) then
    return jsonb_build_object('success', false, 'error', 'not a gift line');
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id for update;
  if v_order.status <> 'processing'::public.shop_order_status then
    return jsonb_build_object('success', false, 'error', 'can only remove gifts while processing');
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  for v_pick in
    select * from public.shop_order_item_stock_picks where order_item_id = p_order_item_id
  loop
    if v_pick.held_stock_id is not null then
      select * into v_stock from public.global_stocks where id = v_pick.held_stock_id for update;
      if found
         and v_stock.availability = 'held'::public.stock_availability
         and v_stock.quantity >= v_pick.quantity then
        perform public.create_and_post_stock_movement(
          p_tenant_id => v_parent_tenant_id,
          p_stock_id => v_stock.id,
          p_quantity => v_pick.quantity,
          p_to_location_id => v_stock.location_id,
          p_to_availability => 'sellable'::public.stock_availability,
          p_to_grade_tag_id => v_stock.grade_tag_id,
          p_movement_type => 'availability_transfer'::public.stock_movement_type,
          p_notes => 'Undo dropship gift pick',
          p_reference_type => 'shop_order',
          p_reference_id => v_order.id::text
        );
      end if;
    end if;
    delete from public.shop_order_item_stock_picks where id = v_pick.id;
  end loop;

  if v_item.gift_source = 'customer_stock' and v_item.shop_customer_stock_id is not null then
    update public.shop_customer_stocks
    set quantity_on_hand = quantity_on_hand + v_item.quantity, updated_at = now()
    where id = v_item.shop_customer_stock_id;
  end if;

  delete from public.shop_order_items where id = p_order_item_id;

  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  return jsonb_build_object('success', true);
end;
$function$;

GRANT ALL ON FUNCTION public.remove_dropship_order_gift_item(bigint) TO anon;

GRANT ALL ON FUNCTION public.remove_dropship_order_gift_item(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.remove_dropship_order_gift_item(bigint) TO service_role;
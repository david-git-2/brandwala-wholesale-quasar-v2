CREATE FUNCTION public.remove_shop_order_item_stock_pick (
  p_pick_id bigint,
  p_search  text    DEFAULT NULL::text,
  p_limit   integer DEFAULT 50,
  p_offset  integer DEFAULT 0
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_pick public.shop_order_item_stock_picks%rowtype;
  v_order public.shop_orders%rowtype;
  v_stock public.global_stocks%rowtype;
  v_parent_tenant_id bigint;
  v_order_item_id bigint;
  v_confirmed_qty numeric;
  v_fulfillment_resolved boolean;
  v_pick_list jsonb;
begin
  select * into v_pick from public.shop_order_item_stock_picks where id = p_pick_id for update;
  if v_pick.id is null then
    raise exception 'pick not found';
  end if;

  select * into v_order from public.shop_orders where id = v_pick.order_id for update;
  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'pick removal is only allowed while order is processing';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

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
        p_notes => 'Undo dropship processing pick',
        p_reference_type => 'shop_order',
        p_reference_id => v_order.id::text
      );
    end if;
  end if;

  v_order_item_id := v_pick.order_item_id;

  delete from public.shop_order_item_stock_picks where id = p_pick_id;

  perform public._recompute_shop_order_item_fulfillment(v_order_item_id);
  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  select
    soi.confirmed_quantity,
    coalesce(soi.is_fulfillment_unavailable, false)
      or coalesce(soi.confirmed_quantity, 0) > 0
      or (
        coalesce(soi.is_gift, false)
        and soi.gift_source = 'customer_stock'
        and coalesce(soi.confirmed_quantity, 0) >= soi.quantity
      )
      or (coalesce(soi.is_gift, false) and soi.gift_source = 'stock')
  into v_confirmed_qty, v_fulfillment_resolved
  from public.shop_order_items soi
  where soi.id = v_order_item_id;

  v_pick_list := public.list_stock_for_order_item_pick(
    v_order_item_id,
    p_search,
    p_limit,
    p_offset
  );

  return jsonb_build_object(
    'success', true,
    'cod_collect_amount', (select cod_collect_amount from public.shop_orders where id = v_order.id),
    'order_line', jsonb_build_object(
      'id', v_order_item_id,
      'confirmed_quantity', v_confirmed_qty,
      'fulfillment_resolved', v_fulfillment_resolved
    ),
    'pick_list', v_pick_list
  );
end;
$function$;

CREATE FUNCTION public.remove_shop_order_item_stock_pick (
  p_pick_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_pick public.shop_order_item_stock_picks%rowtype;
  v_order public.shop_orders%rowtype;
  v_stock public.global_stocks%rowtype;
  v_parent_tenant_id bigint;
  v_held_stock_id bigint;
  v_release_qty integer;
begin
  select * into v_pick from public.shop_order_item_stock_picks where id = p_pick_id for update;
  if v_pick.id is null then
    raise exception 'pick not found';
  end if;

  select * into v_order from public.shop_orders where id = v_pick.order_id for update;
  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'pick removal is only allowed while order is processing';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);
  v_held_stock_id := v_pick.held_stock_id;
  v_release_qty := v_pick.quantity;

  delete from public.shop_order_item_stock_picks where id = p_pick_id;

  perform public._recompute_shop_order_item_fulfillment(v_pick.order_item_id);
  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  if v_held_stock_id is not null then
    select * into v_stock from public.global_stocks where id = v_held_stock_id for update;
    if found
       and v_stock.availability = 'held'::public.stock_availability
       and v_stock.quantity >= v_release_qty then
      perform public.create_and_post_stock_movement(
        p_tenant_id => v_parent_tenant_id,
        p_stock_id => v_stock.id,
        p_quantity => v_release_qty,
        p_to_location_id => v_stock.location_id,
        p_to_availability => 'sellable'::public.stock_availability,
        p_to_grade_tag_id => v_stock.grade_tag_id,
        p_movement_type => 'availability_transfer'::public.stock_movement_type,
        p_notes => 'Undo dropship processing pick',
        p_reference_type => 'shop_order',
        p_reference_id => v_order.id::text
      );
    end if;
  end if;

  return jsonb_build_object('success', true);
end;
$function$;

GRANT ALL ON FUNCTION public.remove_shop_order_item_stock_pick(bigint, text, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.remove_shop_order_item_stock_pick(bigint, text, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.remove_shop_order_item_stock_pick(bigint, text, integer, integer) TO service_role;

GRANT ALL ON FUNCTION public.remove_shop_order_item_stock_pick(bigint) TO anon;

GRANT ALL ON FUNCTION public.remove_shop_order_item_stock_pick(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.remove_shop_order_item_stock_pick(bigint) TO service_role;
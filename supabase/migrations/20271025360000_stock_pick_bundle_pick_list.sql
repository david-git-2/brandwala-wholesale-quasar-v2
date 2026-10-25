-- stock pick: bundle pick_list in add/remove responses
create or replace function public.add_shop_order_item_stock_pick(
  p_order_item_id bigint,
  p_global_stock_id bigint,
  p_quantity integer,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_stock public.global_stocks%rowtype;
  v_held_stock_id bigint;
  v_parent_tenant_id bigint;
  v_existing_qty integer := 0;
  v_total_picked integer := 0;
  v_pick_id bigint;
  v_grade_tag_id bigint;
  v_confirmed_qty numeric;
  v_fulfillment_resolved boolean;
  v_pick_list jsonb;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'quantity must be positive';
  end if;

  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  if v_item.id is null then
    raise exception 'order item not found';
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id for update;
  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'stock pick is only allowed while order is processing';
  end if;

  if coalesce(v_item.is_fulfillment_unavailable, false) then
    raise exception 'line is marked unavailable';
  end if;

  v_grade_tag_id := coalesce(v_item.grade_tag_id, public.default_stock_grade_tag_id());

  select * into v_stock
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gs.id = p_global_stock_id
    and gsi.product_id = v_item.product_id
    and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
  for update of gs;

  if v_stock.id is null then
    raise exception 'stock not found or does not match line product/grade';
  end if;

  if v_stock.availability <> 'sellable'::public.stock_availability then
    raise exception 'stock is not sellable';
  end if;

  if public.global_stock_atp_qty(v_stock.id) < p_quantity then
    raise exception 'insufficient ATP (requested %, available %)', p_quantity, public.global_stock_atp_qty(v_stock.id);
  end if;

  select coalesce(sum(sp.quantity), 0)
  into v_total_picked
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id;

  select coalesce(sp.quantity, 0)
  into v_existing_qty
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id
    and sp.global_stock_id = p_global_stock_id;

  if v_total_picked - v_existing_qty + p_quantity > v_item.quantity then
    raise exception 'pick quantity exceeds ordered qty (ordered %, would pick %)',
      v_item.quantity, v_total_picked - v_existing_qty + p_quantity;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  perform public.create_and_post_stock_movement(
    p_tenant_id => v_parent_tenant_id,
    p_stock_id => v_stock.id,
    p_quantity => p_quantity,
    p_to_location_id => v_stock.location_id,
    p_to_availability => 'held'::public.stock_availability,
    p_to_grade_tag_id => v_stock.grade_tag_id,
    p_movement_type => 'availability_transfer'::public.stock_movement_type,
    p_notes => 'Dropship processing pick',
    p_reference_type => 'shop_order',
    p_reference_id => v_order.id::text
  );

  select gs.id into v_held_stock_id
  from public.global_stocks gs
  where gs.shipment_item_id = v_stock.shipment_item_id
    and gs.parent_tenant_id = v_parent_tenant_id
    and gs.availability = 'held'::public.stock_availability
    and gs.location_id is not distinct from v_stock.location_id
    and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id())
      = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id())
  order by gs.id desc
  limit 1;

  insert into public.shop_order_item_stock_picks (
    tenant_id, order_id, order_item_id, global_stock_id,
    shipment_item_id, shipment_id, quantity, held_stock_id, created_by_email
  )
  values (
    v_order.tenant_id, v_order.id, v_item.id, v_stock.id,
    v_stock.shipment_item_id,
    (select shipment_id from public.global_shipment_items where id = v_stock.shipment_item_id),
    p_quantity, v_held_stock_id, public.current_user_email()
  )
  on conflict (order_item_id, global_stock_id) do update
  set
    quantity = public.shop_order_item_stock_picks.quantity + excluded.quantity,
    held_stock_id = excluded.held_stock_id,
    updated_at = now()
  returning id into v_pick_id;

  perform public._recompute_shop_order_item_fulfillment(p_order_item_id);
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
  where soi.id = p_order_item_id;

  v_pick_list := public.list_stock_for_order_item_pick(
    p_order_item_id,
    p_search,
    p_limit,
    p_offset
  );

  return jsonb_build_object(
    'success', true,
    'pick_id', v_pick_id,
    'confirmed_quantity', v_confirmed_qty,
    'cod_collect_amount', (select cod_collect_amount from public.shop_orders where id = v_order.id),
    'order_line', jsonb_build_object(
      'id', p_order_item_id,
      'confirmed_quantity', v_confirmed_qty,
      'fulfillment_resolved', v_fulfillment_resolved
    ),
    'pick_list', v_pick_list
  );
end;
$$;

create or replace function public.remove_shop_order_item_stock_pick(
  p_pick_id bigint,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
$$;

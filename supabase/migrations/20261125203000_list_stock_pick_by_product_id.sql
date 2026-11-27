-- Stock pick list: optional p_product_id (validated against order line); search may match product id.

DROP FUNCTION IF EXISTS public.list_stock_for_order_item_pick(bigint, text, integer, integer);

CREATE OR REPLACE FUNCTION public.list_stock_for_order_item_pick(
  p_order_item_id bigint,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0,
  p_product_id bigint DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_shop_id bigint;
  v_shop_tenant_id bigint;
  v_total_count bigint;
  v_data jsonb;
  v_limit integer;
  v_offset integer;
  v_grade_tag_id bigint;
  v_ordered_qty integer;
  v_picked_total integer;
  v_remaining integer;
  v_billed numeric;
  v_product_id bigint;
begin
  select * into v_item from public.shop_order_items where id = p_order_item_id;
  if v_item.id is null then
    raise exception 'order item not found';
  end if;

  v_product_id := coalesce(p_product_id, v_item.product_id);
  if p_product_id is not null and p_product_id is distinct from v_item.product_id then
    raise exception 'product id does not match order line';
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id;
  if v_order.id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if not public._shop_order_allows_stock_pick(v_order) then
    raise exception 'stock pick is not allowed for this order status';
  end if;

  if coalesce(v_item.is_fulfillment_unavailable, false) then
    raise exception 'line is marked unavailable';
  end if;

  v_shop_id := v_order.shop_id;
  v_shop_tenant_id := v_order.tenant_id;
  v_grade_tag_id := coalesce(v_item.grade_tag_id, public.default_stock_grade_tag_id());
  v_limit := greatest(1, least(coalesce(p_limit, 50), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  v_ordered_qty := greatest(coalesce(v_item.confirmed_quantity, v_item.quantity, 0), 0)::integer;

  select coalesce(sum(sp.quantity), 0)::int
  into v_picked_total
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id;

  v_remaining := greatest(v_ordered_qty - v_picked_total, 0);

  if v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum then
    v_billed := public._shop_order_item_billed_qty(p_order_item_id);
    v_remaining := least(
      v_remaining,
      greatest(v_ordered_qty - coalesce(v_billed, 0)::int, 0)
    );
  end if;

  select count(distinct gs.id)
  into v_total_count
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.stock_locations sl on sl.id = gs.location_id
  left join public.tags tg on tg.id = gs.grade_tag_id
  where gs.tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
    and gsi.product_id = v_product_id
    and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
    and public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
    and gship.status = 'received'
    and gs.availability = 'sellable'::public.stock_availability
    and (gs.location_id is null or sl.is_pickable = true)
    and (
      p_search is null or p_search = ''
      or gsi.name ilike '%' || p_search || '%'
      or gsi.product_code ilike '%' || p_search || '%'
      or gsi.barcode ilike '%' || p_search || '%'
      or gship.name ilike '%' || p_search || '%'
      or tg.name ilike '%' || p_search || '%'
      or (p_search ~ '^\s*\d+\s*$' and gsi.product_id = trim(p_search)::bigint)
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id as sort_id,
      jsonb_build_object(
        'global_stock_id', gs.id,
        'shipment_item_id', gsi.id,
        'shipment_id', gship.id,
        'shipment_name', gship.name,
        'item_name', gsi.name,
        'product_id', gsi.product_id,
        'product_code', gsi.product_code,
        'barcode', gsi.barcode,
        'available_atp', public.global_stock_atp_qty(gs.id),
        'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(gsi.id), 0.00),
        'already_picked', coalesce((
          select sp.quantity from public.shop_order_item_stock_picks sp
          where sp.order_item_id = p_order_item_id and sp.global_stock_id = gs.id
        ), 0),
        'pick_id', (
          select sp.id from public.shop_order_item_stock_picks sp
          where sp.order_item_id = p_order_item_id and sp.global_stock_id = gs.id
          limit 1
        ),
        'stock_grade', case
          when tg.slug is not null then jsonb_build_object('slug', tg.slug, 'label', tg.name, 'color', tg.color)
          else null
        end
      ) as row_json
    from public.global_stocks gs
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.stock_locations sl on sl.id = gs.location_id
    left join public.tags tg on tg.id = gs.grade_tag_id
    where gs.tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
      and gsi.product_id = v_product_id
      and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
      and public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
      and gship.status = 'received'
      and gs.availability = 'sellable'::public.stock_availability
      and (gs.location_id is null or sl.is_pickable = true)
      and (
        p_search is null or p_search = ''
        or gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or gship.name ilike '%' || p_search || '%'
        or tg.name ilike '%' || p_search || '%'
        or (p_search ~ '^\s*\d+\s*$' and gsi.product_id = trim(p_search)::bigint)
      )
    order by gs.id desc
    limit v_limit offset v_offset
  ) q;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', (v_offset / v_limit) + 1,
      'page_size', v_limit,
      'total_pages', greatest(1, ceil(v_total_count::numeric / v_limit::numeric)),
      'already_picked_total', v_picked_total,
      'ordered_quantity', v_ordered_qty,
      'remaining_to_pick', v_remaining,
      'product_id', v_product_id,
      'active_picks', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'id', sp.id,
            'global_stock_id', sp.global_stock_id,
            'shipment_id', sp.shipment_id,
            'shipment_name', gship.name,
            'item_name', gsi.name,
            'product_code', gsi.product_code,
            'barcode', gsi.barcode,
            'quantity', sp.quantity,
            'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(gsi.id), 0.00),
            'created_at', sp.created_at
          )
          order by sp.id asc
        )
        from public.shop_order_item_stock_picks sp
        join public.global_shipments gship on gship.id = sp.shipment_id
        join public.global_shipment_items gsi on gsi.id = sp.shipment_item_id
        where sp.order_item_id = p_order_item_id
      ), '[]'::jsonb)
    )
  );
end;
$$;

GRANT EXECUTE ON FUNCTION public.list_stock_for_order_item_pick(bigint, text, integer, integer, bigint) TO authenticated;
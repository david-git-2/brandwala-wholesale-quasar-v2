-- Catalog vendor_catalog: bill coverage, draft wholesale bill from picks, stock-pick during fulfillment.

CREATE OR REPLACE FUNCTION public._shop_order_item_target_qty(p_item_id bigint)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT greatest(
    coalesce(soi.confirmed_quantity, soi.quantity, 0),
    0
  )
  FROM public.shop_order_items soi
  WHERE soi.id = p_item_id;
$$;

CREATE OR REPLACE FUNCTION public._attribute_bill_stock_line_to_order_item(
  p_order_id bigint,
  p_line_meta jsonb,
  p_global_stock_id bigint,
  p_product_id bigint
)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_oi bigint;
  v_match_count int;
BEGIN
  v_oi := nullif(p_line_meta->>'shop_order_item_id', '')::bigint;
  IF v_oi IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.shop_order_items soi WHERE soi.id = v_oi AND soi.order_id = p_order_id
  ) THEN
    RETURN v_oi;
  END IF;

  IF p_global_stock_id IS NOT NULL THEN
    SELECT sp.order_item_id
    INTO v_oi
    FROM public.shop_order_item_stock_picks sp
    WHERE sp.order_id = p_order_id
      AND (sp.global_stock_id = p_global_stock_id OR sp.held_stock_id = p_global_stock_id)
    ORDER BY sp.id
    LIMIT 1;
    IF v_oi IS NOT NULL THEN
      RETURN v_oi;
    END IF;
  END IF;

  IF p_product_id IS NOT NULL THEN
    SELECT count(*)::int, min(soi.id)
    INTO v_match_count, v_oi
    FROM public.shop_order_items soi
    WHERE soi.order_id = p_order_id
      AND soi.product_id = p_product_id;
    IF v_match_count = 1 THEN
      RETURN v_oi;
    END IF;
  END IF;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public._shop_order_item_billed_qty(p_order_item_id bigint)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order_id bigint;
  v_net numeric := 0;
  r record;
  v_stock_id bigint;
  v_product_id bigint;
  v_oi bigint;
  v_sign numeric;
BEGIN
  SELECT soi.order_id INTO v_order_id
  FROM public.shop_order_items soi
  WHERE soi.id = p_order_item_id;
  IF v_order_id IS NULL THEN
    RETURN 0;
  END IF;

  FOR r IN
    SELECT
      b.document_kind,
      bl.quantity,
      bl.line_meta,
      bl.product_id,
      coalesce(
        bl.global_stock_id,
        nullif(bl.line_meta->'stock_ref'->>'global_stock_id', '')::bigint
      ) AS stock_id
    FROM public.bills b
    JOIN public.bill_lines bl ON bl.invoice_id = b.id
    WHERE b.invoice_status IS DISTINCT FROM 'voided'::public.global_invoice_status
      AND (
        b.shop_order_id = v_order_id
        OR (b.source_type = 'shop_order' AND b.source_id = v_order_id::text)
      )
  LOOP
  v_stock_id := r.stock_id;
  v_product_id := r.product_id;
  IF v_stock_id IS NULL AND v_product_id IS NULL THEN
    CONTINUE;
  END IF;

  v_oi := public._attribute_bill_stock_line_to_order_item(
    v_order_id,
    coalesce(r.line_meta, '{}'::jsonb),
    v_stock_id,
    v_product_id
  );
  IF v_oi IS DISTINCT FROM p_order_item_id THEN
    CONTINUE;
  END IF;

  v_sign := CASE
    WHEN r.document_kind = 'credit_note'::public.bill_document_kind THEN -1
    ELSE 1
  END;
  v_net := v_net + v_sign * coalesce(r.quantity, 0);
  END LOOP;

  RETURN greatest(v_net, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_shop_order_bill_item_coverage_for_staff(
  p_tenant_id bigint,
  p_order_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.shop_orders%rowtype;
  v_bills_count int;
  v_items jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_order_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant_id and order_id required');
  END IF;

  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  SELECT * INTO v_order FROM public.shop_orders o WHERE o.id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order not found');
  END IF;

  IF v_order.tenant_id IS DISTINCT FROM p_tenant_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant mismatch');
  END IF;

  IF v_order.shop_type_snapshot IS DISTINCT FROM 'vendor_catalog'::public.shop_type_enum THEN
    RETURN jsonb_build_object('success', false, 'error', 'catalog coverage is for vendor_catalog orders only');
  END IF;

  SELECT count(*)::int INTO v_bills_count
  FROM public.bills b
  WHERE b.invoice_status IS DISTINCT FROM 'voided'::public.global_invoice_status
    AND (
      b.shop_order_id = p_order_id
      OR (b.source_type = 'shop_order' AND b.source_id = p_order_id::text)
    );

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'order_item_id', soi.id,
        'target_quantity', public._shop_order_item_target_qty(soi.id),
        'billed_quantity', public._shop_order_item_billed_qty(soi.id),
        'remaining_quantity', greatest(
          public._shop_order_item_target_qty(soi.id) - public._shop_order_item_billed_qty(soi.id),
          0
        ),
        'picked_quantity', coalesce((
          SELECT sum(sp.quantity) FROM public.shop_order_item_stock_picks sp WHERE sp.order_item_id = soi.id
        ), 0)
      )
      ORDER BY soi.id
    ),
    '[]'::jsonb
  )
  INTO v_items
  FROM public.shop_order_items soi
  WHERE soi.order_id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'bills_count', v_bills_count,
    'items', v_items
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.build_catalog_shop_order_wholesale_draft_payload(
  p_order_id bigint,
  p_settlement_kind public.bill_settlement_kind DEFAULT 'take'::public.bill_settlement_kind
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.shop_orders%rowtype;
  v_items jsonb := '[]'::jsonb;
  v_pick record;
  v_stock_id bigint;
  v_sell numeric(12, 2);
  v_item_json jsonb;
  v_line record;
  v_settle text;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order not found');
  END IF;

  IF v_order.shop_type_snapshot IS DISTINCT FROM 'vendor_catalog'::public.shop_type_enum THEN
    RETURN jsonb_build_object('success', false, 'error', 'not a vendor_catalog order');
  END IF;

  IF v_order.profile_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'order billing profile is required');
  END IF;

  v_settle := lower(trim(coalesce(p_settlement_kind::text, 'take')));
  IF v_settle NOT IN ('take', 'condition') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid settlement_kind');
  END IF;

  FOR v_line IN
    SELECT soi.id AS order_item_id,
      coalesce(sum(sp.quantity), 0) AS pick_sum,
      greatest(public._shop_order_item_target_qty(soi.id) - public._shop_order_item_billed_qty(soi.id), 0) AS remaining
    FROM public.shop_order_items soi
    LEFT JOIN public.shop_order_item_stock_picks sp ON sp.order_item_id = soi.id AND sp.quantity > 0
    WHERE soi.order_id = v_order.id
    GROUP BY soi.id
    HAVING coalesce(sum(sp.quantity), 0) > 0
  LOOP
    IF v_line.pick_sum > v_line.remaining THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', format(
          'pick quantity %s exceeds remaining to bill %s for order item %s',
          v_line.pick_sum,
          v_line.remaining,
          v_line.order_item_id
        )
      );
    END IF;
  END LOOP;

  FOR v_pick IN
    SELECT
      sp.id AS pick_id,
      sp.order_item_id,
      sp.quantity AS pick_quantity,
      coalesce(sp.held_stock_id, sp.global_stock_id) AS bill_stock_id,
      sp.global_stock_id AS source_stock_id,
      soi.product_id,
      soi.name AS line_name,
      soi.staff_offer_amount,
      soi.final_price_amount,
      soi.unit_sell_price_amount,
      gs.shipment_item_id AS stock_shipment_item_id,
      gsi.name AS stock_name,
      gsi.barcode AS stock_barcode,
      gsi.product_code AS stock_product_code,
      sh.assigned_child_tenant_id AS stock_assigned_child
    FROM public.shop_order_item_stock_picks sp
    JOIN public.shop_order_items soi ON soi.id = sp.order_item_id
    LEFT JOIN public.global_stocks gs ON gs.id = coalesce(sp.held_stock_id, sp.global_stock_id)
    LEFT JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    LEFT JOIN public.global_shipments sh ON sh.id = gsi.shipment_id
    WHERE sp.order_id = v_order.id
      AND sp.quantity > 0
      AND coalesce(soi.is_fulfillment_unavailable, false) = false
    ORDER BY sp.id
  LOOP
    IF v_pick.bill_stock_id IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', format('pick %s is missing stock reference', v_pick.pick_id)
      );
    END IF;

    v_sell := coalesce(
      v_pick.final_price_amount,
      v_pick.staff_offer_amount,
      v_pick.unit_sell_price_amount,
      0
    );

    v_item_json := jsonb_strip_nulls(jsonb_build_object(
      'global_stock_id', v_pick.bill_stock_id,
      'product_id', v_pick.product_id,
      'shipment_item_id', v_pick.stock_shipment_item_id,
      'name_snapshot', coalesce(v_pick.stock_name, v_pick.line_name),
      'barcode_snapshot', v_pick.stock_barcode,
      'product_code_snapshot', v_pick.stock_product_code,
      'quantity', v_pick.pick_quantity,
      'sell_price_amount', v_sell,
      'line_discount_amount', 0,
      'assigned_child_tenant_id', v_pick.stock_assigned_child,
      'line_meta', jsonb_build_object(
        'shop_order_item_id', v_pick.order_item_id,
        'shop_order_item_stock_pick_id', v_pick.pick_id,
        'source_global_stock_id', v_pick.source_stock_id
      )
    ));

    v_items := v_items || jsonb_build_array(v_item_json);
  END LOOP;

  IF jsonb_array_length(v_items) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'no stock picks to bill');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'payload', jsonb_build_object(
      'invoice', jsonb_build_object(
        'invoice_type', 'wholesale',
        'profile_id', v_order.profile_id,
        'channel_meta', jsonb_build_object('delivery_kind', v_settle)
      ),
      'items', v_items,
      'issue', false
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_catalog_shop_order_wholesale_draft_bill(
  p_tenant_id bigint,
  p_order_id bigint,
  p_settlement_kind public.bill_settlement_kind DEFAULT 'take'::public.bill_settlement_kind
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.shop_orders%rowtype;
  v_built jsonb;
  v_payload jsonb;
  v_result jsonb;
  v_invoice_id bigint;
  v_bill public.bills%rowtype;
BEGIN
  IF p_tenant_id IS NULL OR p_order_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant_id and order_id required');
  END IF;

  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order not found');
  END IF;

  IF v_order.tenant_id IS DISTINCT FROM p_tenant_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant mismatch');
  END IF;

  v_built := public.build_catalog_shop_order_wholesale_draft_payload(p_order_id, p_settlement_kind);
  IF coalesce(v_built->>'success', 'false') <> 'true' THEN
    RETURN v_built;
  END IF;

  v_payload := v_built->'payload';
  v_result := public.create_sales_invoice_from_payload(p_tenant_id, v_payload);

  IF coalesce(v_result->>'success', 'false') <> 'true' THEN
    RETURN coalesce(
      v_result,
      jsonb_build_object('success', false, 'error', 'failed to create draft bill')
    );
  END IF;

  v_invoice_id := nullif(v_result->>'invoice_id', '')::bigint;
  IF v_invoice_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invoice_id missing');
  END IF;

  UPDATE public.bills
  SET
    source_type = 'shop_order',
    source_id = p_order_id::text,
    shop_order_id = p_order_id,
  updated_at = now()
  WHERE id = v_invoice_id;

  SELECT * INTO v_bill FROM public.bills WHERE id = v_invoice_id;

  RETURN jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice_id,
    'invoice_no', v_bill.invoice_no,
    'invoice_status', v_bill.invoice_status,
    'settlement_kind', v_bill.settlement_kind,
    'order_id', p_order_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_shop_order_bill_item_coverage_for_staff(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.build_catalog_shop_order_wholesale_draft_payload(bigint, public.bill_settlement_kind) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_catalog_shop_order_wholesale_draft_bill(bigint, bigint, public.bill_settlement_kind) TO authenticated;

-- Catalog stock pick: allow during fulfillment statuses; cap picks by remaining-to-bill.

CREATE OR REPLACE FUNCTION public._shop_order_allows_stock_pick(p_order public.shop_orders)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum THEN
    RETURN p_order.status IN (
      'procuring'::public.shop_order_status,
      'dispatch'::public.shop_order_status,
      'delivered'::public.shop_order_status,
      'closed'::public.shop_order_status
    );
  END IF;
  RETURN p_order.status = 'processing'::public.shop_order_status;
END;
$$;

-- Patch add_shop_order_item_stock_pick (status + qty cap for catalog)
CREATE OR REPLACE FUNCTION public.add_shop_order_item_stock_pick(
  p_order_item_id bigint,
  p_global_stock_id bigint,
  p_quantity integer,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
  v_pick_cap integer;
  v_billed numeric;
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

  if not public._shop_order_allows_stock_pick(v_order) then
    raise exception 'stock pick is not allowed for this order status';
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

  v_pick_cap := greatest(coalesce(v_item.confirmed_quantity, v_item.quantity, 0), 0)::integer;
  if v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum then
    v_billed := public._shop_order_item_billed_qty(p_order_item_id);
    v_pick_cap := least(
      v_pick_cap,
      greatest(v_pick_cap - coalesce(v_billed, 0), 0)::integer
    );
  end if;

  if v_total_picked - v_existing_qty + p_quantity > v_pick_cap then
    raise exception 'pick quantity exceeds allowed qty (allowed %, would pick %)',
      v_pick_cap, v_total_picked - v_existing_qty + p_quantity;
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
    p_notes => case
      when v_order.shop_type_snapshot = 'vendor_catalog' then 'Catalog order stock pick'
      else 'Dropship processing pick'
    end,
    p_reference_type => 'shop_order',
    p_reference_id => v_order.id::text
  );

  select gs.id into v_held_stock_id
  from public.global_stocks gs
  where gs.shipment_item_id = v_stock.shipment_item_id
    and gs.tenant_id = v_parent_tenant_id
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
  if v_order.shop_type_snapshot = 'dropship'::public.shop_type_enum then
    perform public.recompute_dropship_cod_collect_amount(v_order.id);
  end if;

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

-- Patch list_stock_for_order_item_pick meta for catalog remaining-to-bill
CREATE OR REPLACE FUNCTION public.list_stock_for_order_item_pick(
  p_order_item_id bigint,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
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
begin
  select * into v_item from public.shop_order_items where id = p_order_item_id;
  if v_item.id is null then
    raise exception 'order item not found';
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
    and gsi.product_id = v_item.product_id
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
      and gsi.product_id = v_item.product_id
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

CREATE OR REPLACE FUNCTION public.remove_shop_order_item_stock_pick(
  p_pick_id bigint,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_pick public.shop_order_item_stock_picks%rowtype;
  v_order public.shop_orders%rowtype;
  v_stock public.global_stocks%rowtype;
  v_books_tenant_id bigint;
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

  if not public._shop_order_allows_stock_pick(v_order) then
    raise exception 'pick removal is not allowed for this order status';
  end if;

  v_books_tenant_id := public.resolve_books_tenant_id(v_order.tenant_id);

  if v_pick.held_stock_id is not null then
    select * into v_stock from public.global_stocks where id = v_pick.held_stock_id for update;
    if found
       and v_stock.availability = 'held'::public.stock_availability
       and v_stock.quantity >= v_pick.quantity then
      perform public.create_and_post_stock_movement(
        p_tenant_id => v_books_tenant_id,
        p_stock_id => v_stock.id,
        p_quantity => v_pick.quantity,
        p_to_location_id => v_stock.location_id,
        p_to_availability => 'sellable'::public.stock_availability,
        p_to_grade_tag_id => v_stock.grade_tag_id,
        p_movement_type => 'availability_transfer'::public.stock_movement_type,
        p_notes => case
          when v_order.shop_type_snapshot = 'vendor_catalog' then 'Undo catalog order stock pick'
          else 'Undo dropship processing pick'
        end,
        p_reference_type => 'shop_order',
        p_reference_id => v_order.id::text
      );
    end if;
  end if;

  v_order_item_id := v_pick.order_item_id;

  delete from public.shop_order_item_stock_picks where id = p_pick_id;

  perform public._recompute_shop_order_item_fulfillment(v_order_item_id);
  if v_order.shop_type_snapshot = 'dropship'::public.shop_type_enum then
    perform public.recompute_dropship_cod_collect_amount(v_order.id);
  end if;

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
    'order_line', jsonb_build_object(
      'id', v_order_item_id,
      'confirmed_quantity', v_confirmed_qty,
      'fulfillment_resolved', v_fulfillment_resolved
    ),
    'pick_list', v_pick_list
  );
end;
$$;
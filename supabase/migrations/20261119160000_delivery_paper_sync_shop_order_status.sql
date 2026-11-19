-- Sync vendor-catalog shop order status when delivery paper is dispatched or delivered.
-- When a vendor-catalog delivery paper moves to dispatched / delivered, align the source shop order status.

CREATE OR REPLACE FUNCTION public.sync_shop_order_from_delivery_paper (
  p_delivery_paper_id bigint,
  p_paper_status      public.delivery_paper_status
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_order public.shop_orders%rowtype;
  v_procurement text;
BEGIN
  IF p_delivery_paper_id IS NULL OR p_paper_status IS NULL THEN
    RETURN;
  END IF;

  IF p_paper_status NOT IN (
    'dispatched'::public.delivery_paper_status,
    'delivered'::public.delivery_paper_status
  ) THEN
    RETURN;
  END IF;

  SELECT * INTO v_paper
  FROM public.delivery_paper dp
  WHERE dp.id = p_delivery_paper_id;

  IF NOT FOUND
    OR v_paper.source_type <> 'shop_order'::public.delivery_paper_source_type THEN
    RETURN;
  END IF;

  SELECT * INTO v_order
  FROM public.shop_orders o
  WHERE o.id = v_paper.source_id;

  IF NOT FOUND OR v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RETURN;
  END IF;

  IF v_order.status IN (
    'cancelled'::public.shop_order_status,
    'closed'::public.shop_order_status
  ) THEN
    RETURN;
  END IF;

  IF p_paper_status = 'dispatched'::public.delivery_paper_status THEN
    v_procurement := public.normalize_shop_order_procurement_status(v_order.status);
    IF v_procurement <> 'procuring' AND v_order.status <> 'dispatch'::public.shop_order_status THEN
      RETURN;
    END IF;
    IF v_order.status = 'dispatch'::public.shop_order_status THEN
      RETURN;
    END IF;

    UPDATE public.shop_orders
    SET
      status = 'dispatch'::public.shop_order_status,
      placed_at = coalesce(placed_at, now()),
      updated_at = now()
    WHERE id = v_order.id;

    PERFORM public.notify_catalog_shop_order(
      p_order_id := v_order.id,
      p_notify_staff := false,
      p_notify_customer := true,
      p_event_type := 'catalog.order.dispatch',
      p_title := format('%s is dispatching', v_order.order_no),
      p_body := 'We will update you when it is delivered.'
    );
    RETURN;
  END IF;

  IF p_paper_status = 'delivered'::public.delivery_paper_status THEN
    IF v_order.status = 'delivered'::public.shop_order_status THEN
      RETURN;
    END IF;

    UPDATE public.shop_orders
    SET
      status = 'delivered'::public.shop_order_status,
      fulfilled_at = coalesce(fulfilled_at, now()),
      updated_at = now()
    WHERE id = v_order.id;

    PERFORM public.notify_catalog_shop_order(
      p_order_id := v_order.id,
      p_notify_staff := false,
      p_notify_customer := true,
      p_event_type := 'catalog.order.delivered',
      p_title := format('Order %s delivered', v_order.order_no),
      p_body := 'Open the order for details.'
    );
  END IF;
END;
$function$;

GRANT ALL ON FUNCTION public.sync_shop_order_from_delivery_paper(bigint, public.delivery_paper_status) TO anon;

GRANT ALL ON FUNCTION public.sync_shop_order_from_delivery_paper(bigint, public.delivery_paper_status) TO authenticated;

GRANT ALL ON FUNCTION public.sync_shop_order_from_delivery_paper(bigint, public.delivery_paper_status) TO service_role;

CREATE OR REPLACE FUNCTION public.dispatch_delivery_paper (
  p_tenant_id         bigint,
  p_delivery_paper_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_line public.delivery_paper_line%rowtype;
  v_mov_id bigint;
  v_mov_payload jsonb;
  v_qty integer;
  v_landed numeric;
  v_existing bigint;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  SELECT * INTO v_paper
  FROM public.delivery_paper dp
  WHERE dp.id = p_delivery_paper_id
    AND dp.parent_tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper not found';
  END IF;

  v_existing := public.delivery_paper_dispatch_movement_id(p_delivery_paper_id);
  IF v_existing IS NOT NULL THEN
    IF v_paper.status <> 'dispatched'::public.delivery_paper_status THEN
      UPDATE public.delivery_paper dp
      SET
        status = 'dispatched'::public.delivery_paper_status,
        dispatched_at = coalesce(dp.dispatched_at, now()),
        updated_at = now()
      WHERE dp.id = p_delivery_paper_id;
    END IF;
    PERFORM public.sync_shop_order_from_delivery_paper(
      p_delivery_paper_id,
      'dispatched'::public.delivery_paper_status
    );
    RETURN jsonb_build_object(
      'success', true,
      'status', 'dispatched',
      'movement_id', v_existing,
      'idempotent', true
    );
  END IF;

  IF v_paper.status <> 'packed'::public.delivery_paper_status THEN
    RAISE EXCEPTION 'delivery paper must be packed before dispatch (current: %)', v_paper.status;
  END IF;

  v_mov_payload := public.create_stock_movement(
    p_tenant_id,
    'issue_outbound'::public.stock_movement_type,
    'Dispatch delivery paper #' || p_delivery_paper_id::text,
    'delivery_paper',
    p_delivery_paper_id::text
  );
  v_mov_id := (v_mov_payload->'movement'->>'id')::bigint;

  FOR v_line IN
    SELECT dpl.*
    FROM public.delivery_paper_line dpl
    WHERE dpl.delivery_paper_id = p_delivery_paper_id
      AND dpl.global_stock_id IS NOT NULL
  LOOP
    v_qty := public.delivery_paper_line_packed_qty(v_line.splits);
    IF v_qty <= 0 THEN
      CONTINUE;
    END IF;

    SELECT gsi.landed_cost_bdt INTO v_landed
    FROM public.global_stocks gs
    INNER JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    WHERE gs.id = v_line.global_stock_id;

    UPDATE public.delivery_paper_line dpl
    SET unit_cost_landed_snapshot = v_landed, updated_at = now()
    WHERE dpl.id = v_line.id;

    PERFORM public.add_stock_movement_line(
      v_mov_id,
      v_line.global_stock_id,
      v_qty,
      NULL,
      NULL,
      NULL,
      NULL,
      NULL,
      NULL
    );
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM public.stock_movement_lines sml WHERE sml.movement_id = v_mov_id
  ) THEN
    DELETE FROM public.stock_movements WHERE id = v_mov_id;
    RAISE EXCEPTION 'no stock lines to dispatch on paper %', p_delivery_paper_id;
  END IF;

  UPDATE public.delivery_paper_line dpl
  SET
    dispatched_global_stock_id = dpl.global_stock_id,
    updated_at = now()
  WHERE dpl.delivery_paper_id = p_delivery_paper_id
    AND dpl.global_stock_id IS NOT NULL;

  PERFORM public.post_stock_movement(v_mov_id);

  UPDATE public.delivery_paper dp
  SET
    status = 'dispatched'::public.delivery_paper_status,
    dispatched_at = now(),
    updated_at = now()
  WHERE dp.id = p_delivery_paper_id;

  PERFORM public.sync_shop_order_from_delivery_paper(
    p_delivery_paper_id,
    'dispatched'::public.delivery_paper_status
  );

  RETURN jsonb_build_object(
    'success', true,
    'status', 'dispatched',
    'movement_id', v_mov_id
  );
END;
$function$;

GRANT ALL ON FUNCTION public.dispatch_delivery_paper(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.dispatch_delivery_paper(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.dispatch_delivery_paper(bigint, bigint) TO service_role;
CREATE OR REPLACE FUNCTION public.update_delivery_paper_status (
  p_tenant_id         bigint,
  p_delivery_paper_id bigint,
  p_status            text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_new public.delivery_paper_status;
  v_dispatch jsonb;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  IF p_delivery_paper_id IS NULL THEN
    RAISE EXCEPTION 'delivery_paper_id is required';
  END IF;

  BEGIN
    v_new := lower(trim(coalesce(p_status, '')))::public.delivery_paper_status;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'invalid delivery paper status: %', p_status;
  END;

  IF v_new = 'packed'::public.delivery_paper_status THEN
    RETURN public.mark_delivery_paper_packed(p_tenant_id, p_delivery_paper_id);
  END IF;

  IF v_new = 'dispatched'::public.delivery_paper_status THEN
    RETURN public.dispatch_delivery_paper(p_tenant_id, p_delivery_paper_id);
  END IF;

  SELECT * INTO v_paper
  FROM public.delivery_paper dp
  WHERE dp.id = p_delivery_paper_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper not found';
  END IF;

  IF v_paper.status <> 'draft'::public.delivery_paper_status
     AND v_new = 'draft'::public.delivery_paper_status THEN
    RAISE EXCEPTION 'delivery paper cannot return to draft after it has left draft';
  END IF;

  IF v_paper.status = v_new THEN
    RETURN jsonb_build_object('success', true, 'status', v_new);
  END IF;

  UPDATE public.delivery_paper dp
  SET status = v_new, updated_at = now()
  WHERE dp.id = p_delivery_paper_id;

  IF v_new = 'delivered'::public.delivery_paper_status THEN
    PERFORM public.sync_shop_order_from_delivery_paper(p_delivery_paper_id, v_new);
  END IF;

  RETURN jsonb_build_object('success', true, 'status', v_new);
END;
$function$;

GRANT ALL ON FUNCTION public.update_delivery_paper_status(bigint, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.update_delivery_paper_status(bigint, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.update_delivery_paper_status(bigint, bigint, text) TO service_role;
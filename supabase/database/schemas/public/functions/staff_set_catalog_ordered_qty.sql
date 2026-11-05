CREATE FUNCTION public.staff_set_catalog_ordered_qty (
  p_order_id bigint,
  p_items    jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_order record;
  v_desk_tenant_id bigint;
  v_item_row record;
  v_target_qty integer;
  v_allocated integer;
  v_shortfall integer;
  v_product record;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  v_desk_tenant_id := coalesce(v_order.parent_tenant_id, v_order.tenant_id);

  IF NOT public.is_tenant_staff(v_desk_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_set_catalog_ordered_qty is only valid for vendor_catalog orders.';
  END IF;

  IF public.normalize_shop_order_procurement_status(v_order.status) <> 'procuring' THEN
    RAISE EXCEPTION 'order must be procuring to mark dispatch';
  END IF;

  FOR v_item_row IN
    SELECT oi.*
    FROM public.shop_order_items oi
    WHERE oi.order_id = p_order_id
  LOOP
    v_target_qty := coalesce(v_item_row.confirmed_quantity, v_item_row.quantity, 0);

    SELECT coalesce(pd.delivered_quantity, 0)
    INTO v_allocated
    FROM public.preorder_demand pd
    WHERE pd.source_type = 'shop_order_item'
      AND pd.source_id = v_item_row.id;

    v_shortfall := greatest(v_target_qty - coalesce(v_allocated, 0), 0);

    IF v_shortfall > 0 AND v_order.profile_id IS NOT NULL THEN
      SELECT p.barcode, p.product_code
      INTO v_product
      FROM public.products p
      WHERE p.id = v_item_row.product_id;

      PERFORM public.add_demand_bucket_item_internal(
        v_order.tenant_id,
        v_order.profile_id,
        v_item_row.product_id,
        'shop_order_item'::public.demand_bucket_source_type,
        v_item_row.id,
        jsonb_build_object(
          'name', coalesce(v_item_row.name, ''),
          'image_url', v_item_row.image_url,
          'barcode', v_product.barcode,
          'product_code', v_product.product_code,
          'note', null
        ),
        v_shortfall
      );

      INSERT INTO public.customer_order_backlog_items (
        tenant_id,
        profile_id,
        product_id,
        order_id,
        order_item_id,
        requested_quantity,
        fulfilled_quantity,
        backlog_status
      ) VALUES (
        v_order.tenant_id,
        v_order.profile_id,
        v_item_row.product_id,
        p_order_id,
        v_item_row.id,
        v_shortfall,
        0,
        'open'
      )
      ON CONFLICT (tenant_id, profile_id, product_id)
      DO UPDATE SET
        requested_quantity = customer_order_backlog_items.requested_quantity + excluded.requested_quantity,
        backlog_status = 'open',
        updated_at = now();
    END IF;
  END LOOP;

  UPDATE public.shop_orders
  SET
    status = 'dispatch'::public.shop_order_status,
    placed_at = coalesce(placed_at, now()),
    updated_at = now()
  WHERE id = p_order_id;

  PERFORM public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.order.dispatch',
    p_title := format('%s is dispatching', v_order.order_no),
    p_body := 'We will update you when it is delivered.'
  );

  RETURN public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
END;
$function$;

GRANT ALL ON FUNCTION public.staff_set_catalog_ordered_qty(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.staff_set_catalog_ordered_qty(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.staff_set_catalog_ordered_qty(bigint, jsonb) TO service_role;
-- Restore add_demand_bucket_item_internal (profile_id API) and fix staff_set_catalog_ordered_qty call signature.

CREATE OR REPLACE FUNCTION public.add_demand_bucket_item_internal(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_product_id bigint,
  p_source_type public.demand_bucket_source_type,
  p_source_id bigint DEFAULT NULL,
  p_snapshot jsonb DEFAULT '{}'::jsonb,
  p_quantity integer DEFAULT 1
)
RETURNS public.customer_demand_bucket_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_row public.customer_demand_bucket_items;
  v_name text;
  v_image_url text;
  v_barcode text;
  v_product_code text;
  v_note text;
  v_quantity integer;
BEGIN
  IF p_tenant_id IS NULL OR p_profile_id IS NULL OR p_product_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id, profile_id, and product_id are required';
  END IF;

  v_quantity := greatest(coalesce(p_quantity, 1), 1);

  v_name := nullif(trim(coalesce(p_snapshot->>'name', '')), '');
  v_image_url := nullif(trim(coalesce(p_snapshot->>'image_url', '')), '');
  v_barcode := nullif(trim(coalesce(p_snapshot->>'barcode', '')), '');
  v_product_code := nullif(trim(coalesce(p_snapshot->>'product_code', '')), '');
  v_note := nullif(trim(coalesce(p_snapshot->>'note', '')), '');

  IF v_name IS NULL THEN
    SELECT
      coalesce(p.name, 'Item'),
      p.image_url,
      p.barcode,
      p.product_code
    INTO v_name, v_image_url, v_barcode, v_product_code
    FROM public.products p
    WHERE p.id = p_product_id;
  END IF;

  INSERT INTO public.customer_demand_bucket_items (
    tenant_id,
    profile_id,
    product_id,
    source_type,
    source_id,
    name,
    image_url,
    barcode,
    product_code,
    note,
    quantity,
    status
  ) VALUES (
    p_tenant_id,
    p_profile_id,
    p_product_id,
    p_source_type,
    p_source_id,
    coalesce(v_name, 'Item'),
    v_image_url,
    v_barcode,
    v_product_code,
    v_note,
    v_quantity,
    'open'
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_set_catalog_ordered_qty(p_order_id bigint, p_items jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
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
$$;

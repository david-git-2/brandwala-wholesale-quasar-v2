-- Migration: Phase P4 — Catalog Procurement, Ordering, Delivery & Backlog RPCs
-- Scope: vendor_catalog only. Guard against non-catalog/dropship execution.

-- 1. Start procurement for catalog order (confirmed -> procuring)
CREATE OR REPLACE FUNCTION public.staff_start_catalog_procurement(
  p_order_id bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order record;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_start_catalog_procurement is only valid for vendor_catalog orders.';
  END IF;

  IF v_order.status <> 'confirmed' THEN
    RAISE EXCEPTION 'Order % cannot start procurement from status %', p_order_id, v_order.status;
  END IF;

  -- Default confirmed_quantity to quantity if null
  UPDATE public.shop_order_items
  SET
    confirmed_quantity = COALESCE(confirmed_quantity, quantity),
    updated_at = now()
  WHERE order_id = p_order_id;

  -- Update order status to procuring
  UPDATE public.shop_orders
  SET
    status = 'procuring'::public.shop_order_status,
    updated_at = now()
  WHERE id = p_order_id;
END;
$$;

-- 2. Set catalog ordered quantities & create backlog for shortfalls (procuring -> ordered)
CREATE OR REPLACE FUNCTION public.staff_set_catalog_ordered_qty(
  p_order_id bigint,
  p_items jsonb -- Array: [{ id: bigint, ordered_quantity: integer }]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_ordered_qty integer;
  v_item_row record;
  v_target_qty integer;
  v_shortfall integer;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_set_catalog_ordered_qty is only valid for vendor_catalog orders.';
  END IF;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id := (v_elem->>'id')::bigint;
    v_ordered_qty := (v_elem->>'ordered_quantity')::integer;

    SELECT * INTO v_item_row FROM public.shop_order_items WHERE id = v_item_id AND order_id = p_order_id;

    IF v_item_row.id IS NOT NULL THEN
      UPDATE public.shop_order_items
      SET
        ordered_quantity = COALESCE(v_ordered_qty, 0),
        updated_at = now()
      WHERE id = v_item_id;

      -- Check shortfall for backlog creation
      v_target_qty := COALESCE(v_item_row.confirmed_quantity, v_item_row.quantity, 0);
      v_shortfall := v_target_qty - COALESCE(v_ordered_qty, 0);

      IF v_shortfall > 0 AND v_order.billing_profile_id IS NOT NULL THEN
        INSERT INTO public.customer_order_backlog_items (
          tenant_id,
          billing_profile_id,
          product_id,
          order_id,
          order_item_id,
          requested_quantity,
          fulfilled_quantity,
          backlog_status
        ) VALUES (
          v_order.tenant_id,
          v_order.billing_profile_id,
          v_item_row.product_id,
          p_order_id,
          v_item_id,
          v_shortfall,
          0,
          'open'
        )
        ON CONFLICT (tenant_id, billing_profile_id, product_id)
        DO UPDATE SET
          requested_quantity = customer_order_backlog_items.requested_quantity + EXCLUDED.requested_quantity,
          backlog_status = 'open',
          updated_at = now();
      END IF;
    END IF;
  END LOOP;

  -- Transition status to ordered
  UPDATE public.shop_orders
  SET
    status = 'ordered'::public.shop_order_status,
    placed_at = COALESCE(placed_at, now()),
    updated_at = now()
  WHERE id = p_order_id;
END;
$$;

-- 3. Set catalog delivered quantities (ordered/procuring -> delivered)
CREATE OR REPLACE FUNCTION public.staff_set_catalog_delivered_qty(
  p_order_id bigint,
  p_items jsonb -- Array: [{ id: bigint, delivered_quantity: integer }]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_delivered_qty integer;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_set_catalog_delivered_qty is only valid for vendor_catalog orders.';
  END IF;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id := (v_elem->>'id')::bigint;
    v_delivered_qty := (v_elem->>'delivered_quantity')::integer;

    UPDATE public.shop_order_items
    SET
      delivered_quantity = COALESCE(v_delivered_qty, 0),
      updated_at = now()
    WHERE id = v_item_id AND order_id = p_order_id;
  END LOOP;

  -- Transition status to delivered
  UPDATE public.shop_orders
  SET
    status = 'delivered'::public.shop_order_status,
    fulfilled_at = COALESCE(fulfilled_at, now()),
    updated_at = now()
  WHERE id = p_order_id;
END;
$$;

-- 4. List open backlog items for a billing profile
CREATE OR REPLACE FUNCTION public.list_customer_order_backlog_items(
  p_tenant_id bigint,
  p_billing_profile_id bigint
)
RETURNS TABLE (
  id bigint,
  tenant_id bigint,
  billing_profile_id bigint,
  product_id bigint,
  order_id bigint,
  order_item_id bigint,
  requested_quantity integer,
  fulfilled_quantity integer,
  open_quantity integer,
  backlog_status text,
  name text,
  image_url text,
  barcode text,
  product_code text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.id,
    b.tenant_id,
    b.billing_profile_id,
    b.product_id,
    b.order_id,
    b.order_item_id,
    b.requested_quantity,
    b.fulfilled_quantity,
    (b.requested_quantity - b.fulfilled_quantity) AS open_quantity,
    b.backlog_status,
    p.name,
    p.image_url,
    p.barcode,
    p.product_code,
    b.created_at
  FROM customer_order_backlog_items b
  JOIN products p ON p.id = b.product_id
  WHERE b.tenant_id = p_tenant_id
    AND b.billing_profile_id = p_billing_profile_id
    AND b.backlog_status IN ('open', 'partially_fulfilled')
  ORDER BY b.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_start_catalog_procurement(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_set_catalog_ordered_qty(bigint, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_set_catalog_delivered_qty(bigint, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_customer_order_backlog_items(bigint, bigint) TO authenticated;

NOTIFY pgrst, 'reload schema';

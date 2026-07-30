-- Phase 1: Catalog Shop Negotiation RPCs
-- Scope: vendor_catalog only. Guard against non-catalog/dropship execution.

-- 1. Ensure submit_shop_order_from_cart initializes catalog orders with status = 'submitted'
CREATE OR REPLACE FUNCTION public.submit_shop_order_from_cart(
  p_cart_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_recipient_phone_secondary text DEFAULT NULL,
  p_shipping_district text DEFAULT NULL,
  p_shipping_thana text DEFAULT NULL,
  p_billing_profile_id bigint DEFAULT NULL,
  p_is_prepaid boolean DEFAULT false,
  p_delivery_instructions text DEFAULT NULL,
  p_cod_charge_amount numeric DEFAULT 0,
  p_delivery_charge_amount numeric DEFAULT 0,
  p_print_charge_amount numeric DEFAULT 0,
  p_packing_charge_amount numeric DEFAULT 0,
  p_discount_amount numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_cart record;
  v_shop record;
  v_order_id bigint;
  v_order_no text;
  v_initial_status public.shop_order_status;
  v_item record;
BEGIN
  -- Fetch cart
  SELECT * INTO v_cart FROM public.shop_carts WHERE id = p_cart_id AND is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active cart not found for ID %', p_cart_id;
  END IF;

  -- Fetch shop
  SELECT * INTO v_shop FROM public.shops WHERE id = v_cart.shop_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shop not found for ID %', v_cart.shop_id;
  END IF;

  -- Determine status based on shop_type
  IF v_shop.shop_type = 'vendor_catalog' THEN
    v_initial_status := 'submitted'::public.shop_order_status;
  ELSE
    -- Dropship / default behavior
    v_initial_status := 'draft'::public.shop_order_status;
  END IF;

  -- Generate order_no
  v_order_no := 'ORD-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random() * 100000)::text, 5, '0');

  -- Create shop order
  INSERT INTO public.shop_orders (
    tenant_id,
    shop_id,
    cart_id,
    order_no,
    status,
    shop_type_snapshot,
    billing_profile_id,
    recipient_name,
    recipient_phone,
    recipient_phone_secondary,
    shipping_address,
    shipping_district,
    shipping_thana,
    is_prepaid_snapshot,
    delivery_instructions,
    cod_charge_amount,
    delivery_charge_amount,
    print_charge_amount,
    packing_charge_amount,
    discount_amount,
    created_at,
    updated_at
  ) VALUES (
    v_cart.tenant_id,
    v_cart.shop_id,
    p_cart_id,
    v_order_no,
    v_initial_status,
    v_shop.shop_type,
    p_billing_profile_id,
    p_recipient_name,
    p_recipient_phone,
    p_recipient_phone_secondary,
    p_shipping_address,
    p_shipping_district,
    p_shipping_thana,
    p_is_prepaid,
    p_delivery_instructions,
    p_cod_charge_amount,
    p_delivery_charge_amount,
    p_print_charge_amount,
    p_packing_charge_amount,
    p_discount_amount,
    now(),
    now()
  )
  RETURNING id INTO v_order_id;

  -- Copy cart items to shop order items
  FOR v_item IN SELECT * FROM public.shop_cart_items WHERE cart_id = p_cart_id LOOP
    INSERT INTO public.shop_order_items (
      tenant_id,
      order_id,
      product_id,
      variant_id,
      quantity,
      unit_price_snapshot,
      customer_notes,
      created_at,
      updated_at
    ) VALUES (
      v_cart.tenant_id,
      v_order_id,
      v_item.product_id,
      v_item.variant_id,
      v_item.quantity,
      v_item.unit_price,
      v_item.notes,
      now(),
      now()
    );
  END LOOP;

  -- Deactivate cart
  UPDATE public.shop_carts SET is_active = false, updated_at = now() WHERE id = p_cart_id;

  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_initial_status
  );
END;
$$;


-- 2. staff_price_shop_order for vendor_catalog
CREATE OR REPLACE FUNCTION public.staff_price_shop_order(
  p_order_id bigint,
  p_items jsonb,
  p_profit_basis text DEFAULT NULL,
  p_fx_rate numeric DEFAULT NULL,
  p_cargo_rate numeric DEFAULT NULL,
  p_profit_pct numeric DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_offer_amount numeric;
  v_offer_currency_id bigint;
  v_gross_weight numeric;
  v_cbm numeric;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_price_shop_order is only valid for vendor_catalog orders.';
  END IF;

  -- Update order level rates if provided
  UPDATE public.shop_orders
  SET
    profit_basis = COALESCE(p_profit_basis, profit_basis),
    status = 'priced'::public.shop_order_status,
    updated_at = now()
  WHERE id = p_order_id;

  -- Update item pricing & weights
  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id := (v_elem->>'id')::bigint;
    v_offer_amount := (v_elem->>'staff_offer_amount')::numeric;
    v_offer_currency_id := (v_elem->>'staff_offer_currency_id')::bigint;
    v_gross_weight := CASE WHEN v_elem ? 'gross_weight_kg' THEN (v_elem->>'gross_weight_kg')::numeric ELSE NULL END;
    v_cbm := CASE WHEN v_elem ? 'cbm' THEN (v_elem->>'cbm')::numeric ELSE NULL END;

    UPDATE public.shop_order_items
    SET
      staff_offer_amount = v_offer_amount,
      staff_offer_currency_id = v_offer_currency_id,
      gross_weight_kg = COALESCE(v_gross_weight, gross_weight_kg),
      cbm = COALESCE(v_cbm, cbm),
      updated_at = now()
    WHERE id = v_item_id AND order_id = p_order_id;
  END LOOP;
END;
$$;


-- 3. staff_finalize_catalog_prices for vendor_catalog
CREATE OR REPLACE FUNCTION public.staff_finalize_catalog_prices(
  p_order_id bigint,
  p_items jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_final_amount numeric;
  v_final_currency_id bigint;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_finalize_catalog_prices is only valid for vendor_catalog orders.';
  END IF;

  -- Update items final offer
  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id := (v_elem->>'id')::bigint;
    v_final_amount := (v_elem->>'final_offer_amount')::numeric;
    v_final_currency_id := (v_elem->>'final_offer_currency_id')::bigint;

    UPDATE public.shop_order_items
    SET
      final_offer_amount = v_final_amount,
      final_offer_currency_id = v_final_currency_id,
      updated_at = now()
    WHERE id = v_item_id AND order_id = p_order_id;
  END LOOP;

  -- Update status to final_offered
  UPDATE public.shop_orders
  SET
    status = 'final_offered'::public.shop_order_status,
    updated_at = now()
  WHERE id = p_order_id;
END;
$$;


-- 4. customer_confirm_shop_order for vendor_catalog
CREATE OR REPLACE FUNCTION public.customer_confirm_shop_order(
  p_order_id bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order record;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'customer_confirm_shop_order is only valid for vendor_catalog orders.';
  END IF;

  IF v_order.status <> 'final_offered' AND v_order.status <> 'priced' THEN
    RAISE EXCEPTION 'Order % cannot be confirmed from status %', p_order_id, v_order.status;
  END IF;

  -- Set confirmed_quantity = quantity where confirmed_quantity is null
  UPDATE public.shop_order_items
  SET
    confirmed_quantity = COALESCE(confirmed_quantity, quantity),
    updated_at = now()
  WHERE order_id = p_order_id;

  -- Update order status to confirmed
  UPDATE public.shop_orders
  SET
    status = 'confirmed'::public.shop_order_status,
    updated_at = now()
  WHERE id = p_order_id;
END;
$$;

-- Fix shop_order_items columns in submit_shop_order_from_cart RPC
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
BEGIN
  -- Fetch cart
  SELECT * INTO v_cart FROM public.shop_carts WHERE id = p_cart_id AND status = 'active';
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
    customer_group_id,
    shop_id,
    cart_id,
    order_no,
    name,
    status,
    shop_type_snapshot,
    order_mode_snapshot,
    is_negotiable_snapshot,
    billing_profile_id,
    created_by_email,
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
    v_cart.customer_group_id,
    v_cart.shop_id,
    p_cart_id,
    v_order_no,
    'Order for ' || coalesce(nullif(trim(coalesce(p_recipient_name, '')), ''), 'customer'),
    v_initial_status,
    v_shop.shop_type,
    v_shop.order_mode,
    v_shop.is_negotiable,
    p_billing_profile_id,
    public.current_user_email(),
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

  -- Copy cart items to shop order items using correct shop_order_items schema
  INSERT INTO public.shop_order_items (
    order_id, product_id, global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    ordered_quantity
  )
  SELECT
    v_order_id, ci.product_id, ci.global_stock_id, ci.global_stock_allocation_id,
    ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    CASE WHEN v_shop.shop_type = 'dropship' THEN ci.customer_sell_price_amount ELSE NULL END,
    CASE WHEN v_shop.shop_type = 'dropship' THEN ci.customer_sell_price_currency_id ELSE NULL END,
    CASE
      WHEN v_initial_status = 'confirmed' THEN COALESCE(ci.customer_sell_price_amount, ci.unit_sell_price_amount, ci.unit_list_price_amount)
      ELSE NULL
    END,
    CASE
      WHEN v_initial_status = 'confirmed' THEN COALESCE(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id, ci.unit_list_price_currency_id)
      ELSE NULL
    END,
    ci.quantity
  FROM public.shop_cart_items ci
  WHERE ci.cart_id = p_cart_id;

  -- Deactivate cart
  UPDATE public.shop_carts SET status = 'converted', updated_at = now() WHERE id = p_cart_id;

  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_initial_status
  );
END;
$$;

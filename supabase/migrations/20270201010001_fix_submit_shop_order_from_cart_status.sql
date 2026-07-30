-- Fix submit_shop_order_from_cart column names for shop_carts (status = 'active' and status = 'converted')
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
  UPDATE public.shop_carts SET status = 'converted', updated_at = now() WHERE id = p_cart_id;

  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_initial_status
  );
END;
$$;

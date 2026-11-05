CREATE FUNCTION public.staff_add_to_shop_cart (
  p_shop_id                         bigint,
  p_customer_group_id               bigint,
  p_product_id                      bigint,
  p_global_stock_allocation_id      bigint  DEFAULT NULL::bigint,
  p_quantity                        integer DEFAULT 1,
  p_customer_sell_price_amount      numeric DEFAULT NULL::numeric,
  p_customer_sell_price_currency_id bigint  DEFAULT NULL::bigint,
  p_global_stock_id                 bigint  DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_cart_id bigint;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_buy_currency_id bigint;
  v_prod_name text;
  v_prod_image text;
  v_prod_price_amount numeric;
  v_prod_price_currency_id bigint;
  v_listing_id bigint;
  v_global_stock_id bigint;
  v_sell_price_amount numeric;
  v_sell_price_currency_id bigint;
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
  v_landed_cost numeric;
  v_available_to_sell integer;
  v_existing_item_id bigint;
  v_existing_item_qty integer;
  v_target_qty integer;
  v_can_set_dropship_price boolean;
  v_customer_sell_price_amount numeric;
  v_customer_sell_price_currency_id bigint;
BEGIN
  PERFORM public.assert_staff_can_place_dropship_order_on_behalf(p_shop_id, p_customer_group_id);

  v_cart_id := (public.staff_get_or_create_shop_cart(p_shop_id, p_customer_group_id)->'cart'->>'id')::bigint;

  SELECT tenant_id, shop_type, buy_currency_id
  INTO v_tenant_id, v_shop_type, v_buy_currency_id
  FROM public.shops
  WHERE id = p_shop_id;

  IF v_shop_type <> 'dropship' THEN
    RAISE EXCEPTION 'staff manual cart only supports dropship shops';
  END IF;

  SELECT can_set_dropship_price
  INTO v_can_set_dropship_price
  FROM public.get_shop_permissions_for_customer_group(p_shop_id, p_customer_group_id);

  SELECT name, image_url, list_price_amount, list_price_currency_id
  INTO v_prod_name, v_prod_image, v_prod_price_amount, v_prod_price_currency_id
  FROM public.products
  WHERE id = p_product_id;

  IF v_prod_name IS NULL THEN
    RAISE EXCEPTION 'product not found';
  END IF;

  v_global_stock_id := coalesce(p_global_stock_id, p_global_stock_allocation_id);

  IF v_global_stock_id IS NULL THEN
    RAISE EXCEPTION 'global stock required for this shop type';
  END IF;

  SELECT
    l.id, l.sell_price_amount, l.sell_price_currency_id,
    l.minimum_sell_price_amount, l.minimum_sell_price_currency_id
  INTO
    v_listing_id, v_sell_price_amount, v_sell_price_currency_id,
    v_min_sell_price_amount, v_min_sell_price_currency_id
  FROM public.shop_product_listings l
  WHERE l.shop_id = p_shop_id
    AND l.global_stock_id = v_global_stock_id
    AND l.product_id = p_product_id
    AND l.is_active = true;

  IF v_listing_id IS NULL THEN
    RAISE EXCEPTION 'active product listing not found on this shop';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.shop_listing_group_hides h
    WHERE h.listing_id = v_listing_id
      AND h.customer_group_id = p_customer_group_id
  ) THEN
    RAISE EXCEPTION 'product not available for this customer';
  END IF;

  SELECT coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gs.shipment_item_id))
  INTO v_landed_cost
  FROM public.global_stocks gs
  JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  WHERE gs.id = v_global_stock_id;

  SELECT id, quantity INTO v_existing_item_id, v_existing_item_qty
  FROM public.shop_cart_items
  WHERE cart_id = v_cart_id
    AND global_stock_id = v_global_stock_id;

  v_existing_item_qty := coalesce(v_existing_item_qty, 0);
  v_target_qty := v_existing_item_qty + p_quantity;
  v_available_to_sell := greatest(0, floor(public.global_stock_atp_qty(v_global_stock_id))::integer);

  IF v_target_qty > v_available_to_sell THEN
    RAISE EXCEPTION 'insufficient stock: requested %, available %', v_target_qty, v_available_to_sell;
  END IF;

  IF coalesce(v_can_set_dropship_price, true) THEN
    IF p_customer_sell_price_amount IS NOT NULL THEN
      v_customer_sell_price_amount := p_customer_sell_price_amount;
      v_customer_sell_price_currency_id := p_customer_sell_price_currency_id;
    ELSE
      IF v_sell_price_currency_id = v_min_sell_price_currency_id THEN
        v_customer_sell_price_amount := greatest(v_sell_price_amount, coalesce(v_min_sell_price_amount, 0));
      ELSE
        v_customer_sell_price_amount := v_sell_price_amount;
      END IF;
      v_customer_sell_price_currency_id := v_sell_price_currency_id;
    END IF;

    IF v_customer_sell_price_currency_id = v_min_sell_price_currency_id
       AND v_customer_sell_price_amount < v_min_sell_price_amount THEN
      RAISE EXCEPTION 'price cannot be lower than the minimum sell price %', v_min_sell_price_amount;
    END IF;
  ELSE
    v_customer_sell_price_amount := v_sell_price_amount;
    v_customer_sell_price_currency_id := v_sell_price_currency_id;
  END IF;

  IF v_existing_item_id IS NOT NULL THEN
    UPDATE public.shop_cart_items
    SET
      quantity = v_target_qty,
      unit_sell_price_amount = v_sell_price_amount,
      customer_sell_price_amount = coalesce(v_customer_sell_price_amount, customer_sell_price_amount),
      customer_sell_price_currency_id = coalesce(v_customer_sell_price_currency_id, customer_sell_price_currency_id),
      updated_at = now()
    WHERE id = v_existing_item_id;
  ELSE
    INSERT INTO public.shop_cart_items (
      cart_id, product_id, global_stock_id, global_stock_allocation_id,
      quantity, minimum_quantity,
      unit_list_price_amount, unit_list_price_currency_id,
      unit_sell_price_amount, unit_sell_price_currency_id,
      unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
      customer_sell_price_amount, customer_sell_price_currency_id,
      name, image_url
    )
    VALUES (
      v_cart_id, p_product_id, v_global_stock_id, NULL,
      p_quantity, 1,
      coalesce(v_landed_cost, v_prod_price_amount), v_buy_currency_id,
      v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      v_prod_name, v_prod_image
    );
  END IF;

  RETURN public.staff_shop_cart_response_json(v_cart_id);
END;
$function$;

GRANT ALL ON FUNCTION public.staff_add_to_shop_cart(bigint, bigint, bigint, bigint, integer, numeric, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.staff_add_to_shop_cart(bigint, bigint, bigint, bigint, integer, numeric, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.staff_add_to_shop_cart(bigint, bigint, bigint, bigint, integer, numeric, bigint, bigint) TO service_role;
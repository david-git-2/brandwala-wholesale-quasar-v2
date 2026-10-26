-- Staff manual create: resell from payload, display-aware stock, listing/stock adjust
CREATE OR REPLACE FUNCTION public.staff_create_dropship_order(
  p_shop_id bigint,
  p_customer_group_id bigint,
  p_items jsonb,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_recipient_phone_secondary text DEFAULT NULL,
  p_shipping_district text DEFAULT NULL,
  p_shipping_thana text DEFAULT NULL,
  p_shipping_post_code text DEFAULT NULL,
  p_profile_id bigint DEFAULT NULL,
  p_is_prepaid boolean DEFAULT false,
  p_delivery_instructions text DEFAULT NULL,
  p_cod_charge_amount numeric DEFAULT 0,
  p_delivery_charge_amount numeric DEFAULT 0,
  p_print_charge_amount numeric DEFAULT 0,
  p_packing_charge_amount numeric DEFAULT 0,
  p_discount_amount numeric DEFAULT 0,
  p_recipient_pays_delivery boolean DEFAULT true,
  p_recipient_pays_cod boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_shop public.shops%rowtype;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_result jsonb;
  v_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci public.shop_order_items%rowtype;
  v_deduct_delivery_from_margin boolean;
  v_deduct_cod_from_margin boolean;
  v_order_item_id bigint;
  v_available_after integer;
  v_grade_tag_id bigint;
  v_listing_id bigint;
  v_billing_profile_warning boolean := false;
  v_elem jsonb;
  v_product_id bigint;
  v_global_stock_id bigint;
  v_qty integer;
  v_prod_name text;
  v_prod_image text;
  v_listing_id_new bigint;
  v_sell_price_amount numeric;
  v_sell_price_currency_id bigint;
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
  v_customer_sell_price_amount numeric;
  v_customer_sell_price_currency_id bigint;
  v_landed_cost numeric;
  v_can_set_dropship_price boolean;
BEGIN
  PERFORM public.assert_staff_can_place_dropship_order_on_behalf(p_shop_id, p_customer_group_id);

  SELECT * INTO v_shop FROM public.shops WHERE id = p_shop_id AND is_active = true;
  IF v_shop.id IS NULL THEN RAISE EXCEPTION 'shop not found or inactive'; END IF;
  IF v_shop.shop_type <> 'dropship' THEN RAISE EXCEPTION 'shop is not dropship'; END IF;

  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'order must include at least one item';
  END IF;

  IF nullif(trim(coalesce(p_recipient_name, '')), '') IS NULL THEN RAISE EXCEPTION 'recipient name is required'; END IF;
  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  IF v_phone IS NULL THEN RAISE EXCEPTION 'recipient phone is required'; END IF;
  IF nullif(trim(coalesce(p_shipping_address, '')), '') IS NULL THEN RAISE EXCEPTION 'shipping address is required'; END IF;

  IF EXISTS (
    SELECT 1
    FROM (
      SELECT
        nullif((e->>'listing_id')::bigint, 0) AS listing_id,
        (e->>'product_id')::bigint AS product_id,
        sum(greatest(1, coalesce((e->>'quantity')::int, 1))) AS qty
      FROM jsonb_array_elements(p_items) AS e
      GROUP BY 1, 2
    ) agg
    JOIN public.shop_product_listings l ON l.id = agg.listing_id AND l.shop_id = p_shop_id
    LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
    WHERE agg.listing_id IS NOT NULL
      AND agg.qty > coalesce(
        l.display_quantity_override,
        public.shop_product_grade_available_units(
          v_shop.tenant_id,
          agg.product_id,
          coalesce(l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id())
        )
      )
  ) THEN
    RAISE EXCEPTION 'insufficient stock for one or more items';
  END IF;

  SELECT can_set_dropship_price INTO v_can_set_dropship_price
  FROM public.get_shop_permissions_for_customer_group(p_shop_id, p_customer_group_id)
  LIMIT 1;
  v_can_set_dropship_price := coalesce(v_can_set_dropship_price, true);

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_elem->>'product_id')::bigint;
    v_listing_id_new := nullif((v_elem->>'listing_id')::bigint, 0);
    v_global_stock_id := nullif((v_elem->>'global_stock_id')::bigint, 0);
    v_qty := greatest(1, coalesce((v_elem->>'quantity')::int, 1));
    IF v_product_id IS NULL OR (v_listing_id_new IS NULL AND v_global_stock_id IS NULL) THEN
      RAISE EXCEPTION 'each item requires product_id and listing_id';
    END IF;

    IF v_listing_id_new IS NOT NULL THEN
      SELECT
        l.id, l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id
      INTO
        v_listing_id_new, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id
      FROM public.shop_product_listings l
      WHERE l.id = v_listing_id_new
        AND l.shop_id = p_shop_id
        AND l.product_id = v_product_id
        AND l.is_active = true;
    ELSE
      SELECT
        l.id, l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id
      INTO
        v_listing_id_new, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id
      FROM public.shop_product_listings l
      WHERE l.shop_id = p_shop_id
        AND l.global_stock_id = v_global_stock_id
        AND l.product_id = v_product_id
        AND l.is_active = true;
    END IF;

    IF v_listing_id_new IS NULL THEN
      RAISE EXCEPTION 'active product listing not found on this shop';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.shop_listing_group_hides h
      WHERE h.listing_id = v_listing_id_new AND h.customer_group_id = p_customer_group_id
    ) THEN
      RAISE EXCEPTION 'product not available for this customer';
    END IF;

    IF nullif(v_elem->>'customer_sell_price_amount', '') IS NOT NULL THEN
      v_customer_sell_price_amount := (v_elem->>'customer_sell_price_amount')::numeric;
      v_customer_sell_price_currency_id := coalesce((v_elem->>'customer_sell_price_currency_id')::bigint, v_sell_price_currency_id);
    ELSIF v_can_set_dropship_price AND v_sell_price_currency_id = v_min_sell_price_currency_id THEN
      v_customer_sell_price_amount := greatest(v_sell_price_amount, coalesce(v_min_sell_price_amount, 0));
      v_customer_sell_price_currency_id := v_sell_price_currency_id;
    ELSE
      v_customer_sell_price_amount := v_sell_price_amount;
      v_customer_sell_price_currency_id := v_sell_price_currency_id;
    END IF;

    IF coalesce(v_min_sell_price_amount, 0) > 0
       AND v_customer_sell_price_currency_id = v_min_sell_price_currency_id
       AND v_customer_sell_price_amount < v_min_sell_price_amount THEN
      RAISE EXCEPTION 'price floor violation: item priced below minimum sell price';
    END IF;
  END LOOP;

  v_profile_id := p_profile_id;
  IF v_profile_id IS NULL THEN
    v_profile_id := public.resolve_customer_profile_for_group(v_shop.tenant_id, p_customer_group_id);
  END IF;
  IF v_profile_id IS NULL THEN
    v_billing_profile_warning := true;
  END IF;

  IF v_shop.order_mode = 'checkout_fixed' THEN v_order_status := 'confirmed';
  ELSE v_order_status := 'submitted'; END IF;

  v_deduct_delivery_from_margin := NOT coalesce(p_recipient_pays_delivery, true);
  v_deduct_cod_from_margin := NOT coalesce(p_recipient_pays_cod, true);

  SELECT public.generate_shop_order_number(v_shop.tenant_id, v_shop.id) INTO v_order_no;

  v_profile := public.upsert_recipient_profile_and_address(
    p_tenant_id => v_shop.tenant_id, p_name => p_recipient_name, p_phone => v_phone,
    p_phone_secondary => p_recipient_phone_secondary, p_address => p_shipping_address,
    p_district => p_shipping_district, p_thana => p_shipping_thana
  );
  v_recipient_profile_id := (v_profile->>'id')::bigint;

  INSERT INTO public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id, order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot, status, negotiate_round,
    recipient_name, recipient_phone, recipient_phone_secondary,
    shipping_address, shipping_district, shipping_thana,
    recipient_profile_id, profile_id, created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  ) VALUES (
    v_shop.tenant_id, v_shop.id, p_customer_group_id, NULL, v_order_no,
    'Order for ' || nullif(trim(coalesce(p_recipient_name, '')), ''),
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable, v_order_status, 0,
    nullif(trim(coalesce(p_recipient_name, '')), ''), v_phone,
    nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''),
    nullif(trim(coalesce(p_shipping_address, '')), ''),
    nullif(trim(coalesce(p_shipping_district, '')), ''),
    nullif(trim(coalesce(p_shipping_thana, '')), ''),
    v_recipient_profile_id, v_profile_id, public.current_user_email(),
    coalesce(p_cod_charge_amount, 0), coalesce(p_delivery_charge_amount, 0),
    coalesce(p_print_charge_amount, 0), coalesce(p_packing_charge_amount, 0), coalesce(p_discount_amount, 0),
    coalesce(p_is_prepaid, false), nullif(trim(coalesce(p_delivery_instructions, '')), ''),
    v_shop.deduct_charges_from_margin, v_deduct_cod_from_margin, v_deduct_delivery_from_margin,
    v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
  ) RETURNING id INTO v_order_id;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_elem->>'product_id')::bigint;
    v_listing_id_new := nullif((v_elem->>'listing_id')::bigint, 0);
    v_global_stock_id := nullif((v_elem->>'global_stock_id')::bigint, 0);
    v_qty := greatest(1, coalesce((v_elem->>'quantity')::int, 1));

    SELECT name, image_url INTO v_prod_name, v_prod_image FROM public.products WHERE id = v_product_id;

    IF v_listing_id_new IS NOT NULL THEN
      SELECT
        l.id, l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id,
        coalesce(l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id()),
        l.global_stock_id
      INTO
        v_listing_id_new, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id,
        v_grade_tag_id, v_global_stock_id
      FROM public.shop_product_listings l
      LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
      WHERE l.id = v_listing_id_new
        AND l.shop_id = p_shop_id
        AND l.product_id = v_product_id
        AND l.is_active = true;
    ELSE
      SELECT
        l.id, l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id,
        coalesce(l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id()),
        l.global_stock_id
      INTO
        v_listing_id_new, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id,
        v_grade_tag_id, v_global_stock_id
      FROM public.shop_product_listings l
      LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
      WHERE l.shop_id = p_shop_id
        AND l.global_stock_id = v_global_stock_id
        AND l.product_id = v_product_id
        AND l.is_active = true;
    END IF;

    IF v_global_stock_id IS NOT NULL THEN
      SELECT coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gs.shipment_item_id))
      INTO v_landed_cost
      FROM public.global_stocks gs
      JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
      WHERE gs.id = v_global_stock_id;
    ELSE
      v_landed_cost := public.shop_product_grade_avg_landed_cost(
        v_shop.tenant_id, v_product_id, v_grade_tag_id
      );
    END IF;

    IF nullif(v_elem->>'customer_sell_price_amount', '') IS NOT NULL THEN
      v_customer_sell_price_amount := (v_elem->>'customer_sell_price_amount')::numeric;
      v_customer_sell_price_currency_id := coalesce((v_elem->>'customer_sell_price_currency_id')::bigint, v_sell_price_currency_id);
    ELSIF v_can_set_dropship_price AND v_sell_price_currency_id = v_min_sell_price_currency_id THEN
      v_customer_sell_price_amount := greatest(v_sell_price_amount, coalesce(v_min_sell_price_amount, 0));
      v_customer_sell_price_currency_id := v_sell_price_currency_id;
    ELSE
      v_customer_sell_price_amount := v_sell_price_amount;
      v_customer_sell_price_currency_id := v_sell_price_currency_id;
    END IF;

    INSERT INTO public.shop_order_items (
      order_id, product_id, listing_id, grade_tag_id, global_stock_id, global_stock_allocation_id,
      name, image_url, quantity,
      unit_list_price_amount, unit_list_price_currency_id,
      unit_sell_price_amount, unit_sell_price_currency_id,
      unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
      customer_sell_price_amount, customer_sell_price_currency_id,
      customer_offer_amount, customer_offer_currency_id,
      final_price_amount, final_price_currency_id,
      cost_price_amount, cost_price_currency_id, confirmed_quantity
    ) VALUES (
      v_order_id, v_product_id, v_listing_id_new,
      coalesce(v_grade_tag_id, public.default_stock_grade_tag_id()),
      v_global_stock_id, NULL, v_prod_name, v_prod_image, v_qty,
      coalesce(v_landed_cost, 0), v_shop.buy_currency_id,
      v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      CASE WHEN v_order_status = 'confirmed' THEN v_customer_sell_price_amount ELSE NULL END,
      CASE WHEN v_order_status = 'confirmed' THEN v_customer_sell_price_currency_id ELSE NULL END,
      coalesce(v_landed_cost, public.shop_product_grade_avg_landed_cost(
        v_shop.tenant_id, v_product_id, coalesce(v_grade_tag_id, public.default_stock_grade_tag_id())
      )),
      v_shop.buy_currency_id, 0
    );
  END LOOP;

  FOR v_ci IN SELECT * FROM public.shop_order_items WHERE order_id = v_order_id LOOP
    v_grade_tag_id := coalesce(
      v_ci.grade_tag_id,
      (SELECT l.grade_tag_id FROM public.shop_product_listings l WHERE l.id = v_ci.listing_id),
      (SELECT gs.grade_tag_id FROM public.global_stocks gs WHERE gs.id = v_ci.global_stock_id),
      public.default_stock_grade_tag_id()
    );
    v_listing_id := coalesce(
      v_ci.listing_id,
      (SELECT l.id FROM public.shop_product_listings l WHERE l.shop_id = v_shop.id AND l.product_id = v_ci.product_id
        AND coalesce(l.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id ORDER BY l.id ASC LIMIT 1),
      (SELECT l.id FROM public.shop_product_listings l WHERE l.shop_id = v_shop.id AND l.product_id = v_ci.product_id
        AND l.global_stock_id = v_ci.global_stock_id LIMIT 1)
    );

    IF v_listing_id IS NOT NULL THEN
      UPDATE public.shop_product_listings
      SET display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      WHERE id = v_listing_id AND display_quantity_override IS NOT NULL;
    ELSIF v_ci.global_stock_id IS NOT NULL THEN
      UPDATE public.shop_product_listings
      SET display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      WHERE shop_id = v_shop.id
        AND product_id = v_ci.product_id
        AND global_stock_id = v_ci.global_stock_id
        AND display_quantity_override IS NOT NULL;
    END IF;

    IF v_ci.global_stock_id IS NOT NULL THEN
      UPDATE public.global_stocks
      SET quantity = greatest(0, quantity - v_ci.quantity)
      WHERE id = v_ci.global_stock_id;
    END IF;

    UPDATE public.shop_order_items
    SET listing_id = coalesce(listing_id, v_listing_id), grade_tag_id = coalesce(grade_tag_id, v_grade_tag_id)
    WHERE id = v_ci.id;

    IF v_listing_id IS NOT NULL THEN
      v_available_after := public.shop_product_grade_available_units(v_shop.tenant_id, v_ci.product_id, v_grade_tag_id);
      IF coalesce((SELECT display_quantity_override FROM public.shop_product_listings WHERE id = v_listing_id), v_available_after, 0) <= 0 THEN
        UPDATE public.shop_product_listings SET is_active = false WHERE id = v_listing_id;
      END IF;
    ELSIF v_ci.global_stock_id IS NOT NULL THEN
      SELECT coalesce(sum(gs.quantity), 0) INTO v_available_after
      FROM public.global_stocks gs
      WHERE gs.shipment_item_id = (SELECT shipment_item_id FROM public.global_stocks WHERE id = v_ci.global_stock_id)
        AND gs.availability = 'sellable'::public.stock_availability;
      IF coalesce(
        (SELECT display_quantity_override FROM public.shop_product_listings
         WHERE shop_id = v_shop.id AND product_id = v_ci.product_id AND global_stock_id = v_ci.global_stock_id),
        v_available_after,
        0
      ) <= 0 THEN
        UPDATE public.shop_product_listings SET is_active = false
        WHERE shop_id = v_shop.id AND product_id = v_ci.product_id AND global_stock_id = v_ci.global_stock_id;
      END IF;
    END IF;
  END LOOP;

  PERFORM public.recompute_dropship_cod_collect_amount(v_order_id);

  SELECT jsonb_build_object(
    'order_id', v_order_id, 'order_no', v_order_no, 'status', v_order_status,
    'shop_id', v_shop.id, 'billing_profile_warning', v_billing_profile_warning
  ) INTO v_result;
  RETURN v_result;
END;
$$;

ALTER FUNCTION public.staff_create_dropship_order(
  bigint, bigint, jsonb, text, text, text, text, text, text, text, bigint, boolean, text,
  numeric, numeric, numeric, numeric, numeric, boolean, boolean
) OWNER TO postgres;


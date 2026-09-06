-- Dropship place order: grade-based hold + display qty; release on cancel/delete.

-- 1. Backfill active dropship cart lines missing listing_id / grade_tag_id
UPDATE public.shop_cart_items ci
SET
  grade_tag_id = coalesce(
    ci.grade_tag_id,
    src.listing_grade_tag_id,
    src.stock_grade_tag_id,
    public.default_stock_grade_tag_id()
  ),
  listing_id = coalesce(ci.listing_id, src.listing_id)
FROM (
  SELECT
    ci2.id AS cart_item_id,
    l.grade_tag_id AS listing_grade_tag_id,
    gs.grade_tag_id AS stock_grade_tag_id,
    l.id AS listing_id
  FROM public.shop_cart_items ci2
  JOIN public.shop_carts c ON c.id = ci2.cart_id
  JOIN public.shops s ON s.id = c.shop_id
  LEFT JOIN public.global_stocks gs ON gs.id = ci2.global_stock_id
  LEFT JOIN public.shop_product_listings l ON l.shop_id = s.id
    AND l.product_id = ci2.product_id
    AND coalesce(l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id())
      = coalesce(ci2.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id())
  WHERE c.status = 'active'
    AND s.shop_type = 'dropship'
    AND (ci2.grade_tag_id IS NULL OR ci2.listing_id IS NULL)
) src
WHERE ci.id = src.cart_item_id;

-- 2. Shared release helper (cancel + delete)
CREATE OR REPLACE FUNCTION public.release_dropship_order_stock(
  p_order_id bigint,
  p_restore_display boolean DEFAULT true
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.shop_orders%rowtype;
  v_item record;
  v_skip_stock_release boolean := false;
  v_invoice_status public.global_invoice_status;
  v_parent_tenant_id bigint;
  v_stock public.global_stocks%rowtype;
  v_new_override_qty integer;
  v_new_sellable_qty integer;
  v_grade_tag_id bigint;
BEGIN
  SELECT * INTO v_order
  FROM public.shop_orders
  WHERE id = p_order_id;

  IF v_order.id IS NULL THEN
    RETURN;
  END IF;

  IF coalesce(v_order.shop_type_snapshot, (
    SELECT shop_type FROM public.shops WHERE id = v_order.shop_id
  )) <> 'dropship' THEN
    RETURN;
  END IF;

  IF v_order.global_invoice_id IS NOT NULL THEN
    SELECT invoice_status INTO v_invoice_status
    FROM public.global_invoices
    WHERE id = v_order.global_invoice_id;

    IF v_invoice_status = 'issued'::public.global_invoice_status THEN
      v_skip_stock_release := true;
    END IF;
  END IF;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  FOR v_item IN
    SELECT * FROM public.shop_order_items WHERE order_id = p_order_id
  LOOP
    v_grade_tag_id := coalesce(
      v_item.grade_tag_id,
      (SELECT gs.grade_tag_id FROM public.global_stocks gs WHERE gs.id = v_item.global_stock_id),
      public.default_stock_grade_tag_id()
    );

    IF p_restore_display THEN
      IF v_item.listing_id IS NOT NULL THEN
        UPDATE public.shop_product_listings
        SET display_quantity_override = display_quantity_override + v_item.quantity
        WHERE id = v_item.listing_id
          AND display_quantity_override IS NOT NULL;
      ELSIF v_item.product_id IS NOT NULL AND v_item.global_stock_id IS NOT NULL THEN
        UPDATE public.shop_product_listings
        SET display_quantity_override = display_quantity_override + v_item.quantity
        WHERE shop_id = v_order.shop_id
          AND product_id = v_item.product_id
          AND global_stock_id = v_item.global_stock_id
          AND display_quantity_override IS NOT NULL;
      ELSIF v_item.product_id IS NOT NULL AND v_item.global_stock_allocation_id IS NOT NULL THEN
        UPDATE public.shop_product_listings
        SET display_quantity_override = display_quantity_override + v_item.quantity
        WHERE shop_id = v_order.shop_id
          AND product_id = v_item.product_id
          AND global_stock_allocation_id = v_item.global_stock_allocation_id
          AND display_quantity_override IS NOT NULL;
      END IF;
    END IF;

    IF NOT v_skip_stock_release AND v_item.global_stock_id IS NOT NULL THEN
      SELECT * INTO v_stock
      FROM public.global_stocks
      WHERE id = v_item.global_stock_id
      FOR UPDATE;

      IF found
         AND v_stock.availability = 'held'::public.stock_availability
         AND v_stock.quantity >= v_item.quantity THEN
        PERFORM public.create_and_post_stock_movement(
          p_tenant_id => v_parent_tenant_id,
          p_stock_id => v_stock.id,
          p_quantity => v_item.quantity,
          p_to_location_id => v_stock.location_id,
          p_to_availability => 'sellable'::public.stock_availability,
          p_to_grade_tag_id => v_stock.grade_tag_id,
          p_movement_type => 'availability_transfer'::public.stock_movement_type,
          p_notes => 'Dropship order release',
          p_reference_type => 'shop_order',
          p_reference_id => p_order_id::text
        );
      END IF;
    END IF;

    IF v_item.listing_id IS NOT NULL THEN
      v_new_sellable_qty := public.shop_product_grade_available_units(
        v_order.tenant_id, v_item.product_id, v_grade_tag_id
      );

      SELECT display_quantity_override INTO v_new_override_qty
      FROM public.shop_product_listings
      WHERE id = v_item.listing_id;

      IF coalesce(v_new_override_qty, v_new_sellable_qty, 0) > 0 THEN
        UPDATE public.shop_product_listings
        SET is_active = true
        WHERE id = v_item.listing_id;
      END IF;
    ELSIF v_item.product_id IS NOT NULL AND v_item.global_stock_id IS NOT NULL THEN
      v_new_sellable_qty := 0;
      SELECT coalesce(sum(gs.quantity), 0) INTO v_new_sellable_qty
      FROM public.global_stocks gs
      WHERE gs.shipment_item_id = (
        SELECT shipment_item_id FROM public.global_stocks WHERE id = v_item.global_stock_id
      )
        AND gs.availability = 'sellable'::public.stock_availability;

      SELECT display_quantity_override INTO v_new_override_qty
      FROM public.shop_product_listings
      WHERE shop_id = v_order.shop_id
        AND product_id = v_item.product_id
        AND global_stock_id = v_item.global_stock_id;

      IF coalesce(v_new_override_qty, v_new_sellable_qty, 0) > 0 THEN
        UPDATE public.shop_product_listings
        SET is_active = true
        WHERE shop_id = v_order.shop_id
          AND product_id = v_item.product_id
          AND global_stock_id = v_item.global_stock_id;
      END IF;
    ELSIF v_item.product_id IS NOT NULL AND v_item.global_stock_allocation_id IS NOT NULL THEN
      SELECT gsa.quantity INTO v_new_sellable_qty
      FROM public.global_stock_allocations gsa
      WHERE gsa.id = v_item.global_stock_allocation_id;

      SELECT display_quantity_override INTO v_new_override_qty
      FROM public.shop_product_listings
      WHERE shop_id = v_order.shop_id
        AND product_id = v_item.product_id
        AND global_stock_allocation_id = v_item.global_stock_allocation_id;

      IF coalesce(v_new_override_qty, v_new_sellable_qty, 0) > 0 THEN
        UPDATE public.shop_product_listings
        SET is_active = true
        WHERE shop_id = v_order.shop_id
          AND product_id = v_item.product_id
          AND global_stock_allocation_id = v_item.global_stock_allocation_id;
      END IF;
    END IF;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.release_dropship_order_stock(bigint, boolean) TO authenticated;

-- 3. submit_dropship_order_from_cart: grade hold + listing display qty
CREATE OR REPLACE FUNCTION public.submit_dropship_order_from_cart(
  p_shop_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_recipient_phone_secondary text DEFAULT NULL,
  p_shipping_district text DEFAULT NULL,
  p_shipping_thana text DEFAULT NULL,
  p_shipping_post_code text DEFAULT NULL,
  p_billing_profile_id bigint DEFAULT NULL,
  p_is_prepaid boolean DEFAULT false,
  p_delivery_instructions text DEFAULT NULL,
  p_cod_charge_amount numeric DEFAULT 0,
  p_delivery_charge_amount numeric DEFAULT 0,
  p_print_charge_amount numeric DEFAULT 0,
  p_packing_charge_amount numeric DEFAULT 0,
  p_discount_amount numeric DEFAULT 0,
  p_recipient_pays_delivery boolean DEFAULT true,
  p_recipient_pays_cod boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_shop public.shops%rowtype;
  v_cart public.shop_carts%rowtype;
  v_customer_group_id bigint;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_can_place_order boolean;
  v_item_count integer;
  v_result jsonb;
  v_billing_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci record;
  v_deduct_delivery_from_margin boolean;
  v_deduct_cod_from_margin boolean;
  v_parent_tenant_id bigint;
  v_stock public.global_stocks%rowtype;
  v_held_stock_id bigint;
  v_order_item_id bigint;
  v_available_after integer;
  v_grade_tag_id bigint;
  v_listing_id bigint;
BEGIN
  SELECT * INTO v_shop
  FROM public.shops
  WHERE id = p_shop_id
    AND is_active = true;

  IF v_shop.id IS NULL THEN
    RAISE EXCEPTION 'shop not found or inactive';
  END IF;

  IF v_shop.shop_type <> 'dropship' THEN
    RAISE EXCEPTION 'shop is not dropship';
  END IF;

  IF NOT public.can_customer_access_shop(p_shop_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  SELECT access.customer_group_id INTO v_customer_group_id
  FROM public.shop_customer_group_access access
  JOIN public.customer_groups cg ON cg.id = access.customer_group_id
  JOIN public.customer_group_members cgm ON cgm.customer_group_id = cg.id
  WHERE access.shop_id = p_shop_id
    AND access.status = true
    AND cg.is_active = true
    AND cgm.is_active = true
    AND lower(trim(cgm.email)) = public.current_user_email()
  ORDER BY access.created_at ASC
  LIMIT 1;

  IF v_customer_group_id IS NULL THEN
    RAISE EXCEPTION 'no customer group access found';
  END IF;

  SELECT * INTO v_cart
  FROM public.shop_carts c
  WHERE c.tenant_id = v_shop.tenant_id
    AND c.shop_id = p_shop_id
    AND c.customer_group_id = v_customer_group_id
    AND c.status = 'active'
  ORDER BY c.id DESC
  LIMIT 1;

  IF v_cart.id IS NULL THEN
    RAISE EXCEPTION 'active cart not found';
  END IF;

  IF NOT public.is_cart_owner(v_cart.customer_group_id, v_cart.tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  SELECT can_place_order INTO v_can_place_order
  FROM public.get_shop_permissions_for_customer(p_shop_id);

  IF coalesce(v_can_place_order, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'checkout not allowed for this customer group';
  END IF;

  SELECT count(*) INTO v_item_count
  FROM public.shop_cart_items
  WHERE cart_id = v_cart.id;

  IF v_item_count = 0 THEN
    RAISE EXCEPTION 'cart is empty';
  END IF;

  IF nullif(trim(coalesce(p_recipient_name, '')), '') IS NULL THEN
    RAISE EXCEPTION 'recipient name is required';
  END IF;

  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  IF v_phone IS NULL THEN
    RAISE EXCEPTION 'recipient phone is required';
  END IF;

  IF nullif(trim(coalesce(p_shipping_address, '')), '') IS NULL THEN
    RAISE EXCEPTION 'shipping address is required';
  END IF;

  IF nullif(trim(coalesce(p_shipping_district, '')), '') IS NULL THEN
    RAISE EXCEPTION 'shipping district is required';
  END IF;

  IF nullif(trim(coalesce(p_shipping_thana, '')), '') IS NULL THEN
    RAISE EXCEPTION 'shipping thana is required';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.shop_cart_items ci
    WHERE ci.cart_id = v_cart.id
      AND coalesce(ci.unit_minimum_sell_price_amount, 0) > 0
      AND coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
        < ci.unit_minimum_sell_price_amount
  ) THEN
    RAISE EXCEPTION 'price floor violation: some items are priced below the minimum sell price';
  END IF;

  v_billing_profile_id := p_billing_profile_id;
  IF v_billing_profile_id IS NULL THEN
    v_billing_profile_id := public.resolve_billing_profile_for_customer_group(
      v_cart.tenant_id, v_cart.customer_group_id
    );
  END IF;

  IF v_shop.order_mode = 'checkout_fixed' THEN
    v_order_status := 'confirmed';
  ELSE
    v_order_status := 'submitted';
  END IF;

  v_deduct_delivery_from_margin := NOT coalesce(p_recipient_pays_delivery, true);
  v_deduct_cod_from_margin := NOT coalesce(p_recipient_pays_cod, true);
  v_parent_tenant_id := public.resolve_parent_tenant_id(v_cart.tenant_id);

  SELECT public.generate_shop_order_number(v_cart.tenant_id, v_cart.shop_id) INTO v_order_no;

  v_profile := public.upsert_recipient_profile_and_address(
    p_tenant_id => v_cart.tenant_id,
    p_name => p_recipient_name,
    p_phone => v_phone,
    p_phone_secondary => p_recipient_phone_secondary,
    p_address => p_shipping_address,
    p_district => p_shipping_district,
    p_thana => p_shipping_thana
  );
  v_recipient_profile_id := (v_profile->>'id')::bigint;

  INSERT INTO public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id,
    order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot,
    status, negotiate_round,
    recipient_name, recipient_phone, recipient_phone_secondary,
    shipping_address, shipping_district, shipping_thana,
    recipient_profile_id, billing_profile_id,
    created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  )
  VALUES (
    v_cart.tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id,
    v_order_no, 'Order for ' || nullif(trim(coalesce(p_recipient_name, '')), ''),
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable,
    v_order_status, 0,
    nullif(trim(coalesce(p_recipient_name, '')), ''), v_phone,
    nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''),
    nullif(trim(coalesce(p_shipping_address, '')), ''),
    nullif(trim(coalesce(p_shipping_district, '')), ''),
    nullif(trim(coalesce(p_shipping_thana, '')), ''),
    v_recipient_profile_id, v_billing_profile_id,
    public.current_user_email(),
    coalesce(p_cod_charge_amount, 0), coalesce(p_delivery_charge_amount, 0),
    coalesce(p_print_charge_amount, 0), coalesce(p_packing_charge_amount, 0),
    coalesce(p_discount_amount, 0),
    coalesce(p_is_prepaid, false), nullif(trim(coalesce(p_delivery_instructions, '')), ''),
    v_shop.deduct_charges_from_margin,
    v_deduct_cod_from_margin, v_deduct_delivery_from_margin,
    v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
  )
  RETURNING id INTO v_order_id;

  INSERT INTO public.shop_order_items (
    order_id, product_id, listing_id, grade_tag_id,
    global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    cost_price_amount, cost_price_currency_id
  )
  SELECT
    v_order_id,
    ci.product_id,
    ci.listing_id,
    coalesce(ci.grade_tag_id, l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id()),
    NULL,
    NULL,
    ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    CASE
      WHEN v_order_status = 'confirmed' THEN coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount)
      ELSE NULL
    END,
    CASE
      WHEN v_order_status = 'confirmed' THEN coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id)
      ELSE NULL
    END,
    coalesce(
      ci.unit_list_price_amount,
      public.shop_product_grade_avg_landed_cost(
        v_cart.tenant_id,
        ci.product_id,
        coalesce(ci.grade_tag_id, l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id())
      )
    ),
    v_shop.buy_currency_id
  FROM public.shop_cart_items ci
  LEFT JOIN public.shop_product_listings l ON l.id = ci.listing_id
  LEFT JOIN public.global_stocks gs ON gs.id = ci.global_stock_id
  WHERE ci.cart_id = v_cart.id;

  FOR v_ci IN SELECT * FROM public.shop_cart_items WHERE cart_id = v_cart.id LOOP
    v_grade_tag_id := coalesce(
      v_ci.grade_tag_id,
      (SELECT l.grade_tag_id FROM public.shop_product_listings l WHERE l.id = v_ci.listing_id),
      (SELECT gs.grade_tag_id FROM public.global_stocks gs WHERE gs.id = v_ci.global_stock_id),
      public.default_stock_grade_tag_id()
    );

    v_listing_id := coalesce(
      v_ci.listing_id,
      (
        SELECT l.id
        FROM public.shop_product_listings l
        WHERE l.shop_id = v_shop.id
          AND l.product_id = v_ci.product_id
          AND coalesce(l.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
        ORDER BY l.id ASC
        LIMIT 1
      ),
      (
        SELECT l.id
        FROM public.shop_product_listings l
        WHERE l.shop_id = v_shop.id
          AND l.product_id = v_ci.product_id
          AND l.global_stock_id = v_ci.global_stock_id
        LIMIT 1
      )
    );

    IF v_listing_id IS NOT NULL THEN
      UPDATE public.shop_product_listings
      SET display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      WHERE id = v_listing_id
        AND display_quantity_override IS NOT NULL;
    ELSIF v_ci.global_stock_id IS NOT NULL THEN
      UPDATE public.shop_product_listings
      SET display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      WHERE shop_id = v_shop.id
        AND product_id = v_ci.product_id
        AND global_stock_id = v_ci.global_stock_id
        AND display_quantity_override IS NOT NULL;
    END IF;

    IF v_grade_tag_id IS NOT NULL THEN
      v_held_stock_id := public.hold_shop_grade_stock_for_order(
        v_parent_tenant_id,
        v_cart.tenant_id,
        v_ci.product_id,
        v_grade_tag_id,
        v_ci.quantity,
        v_order_id,
        'Dropship order hold'
      );
    ELSIF v_ci.global_stock_id IS NOT NULL THEN
      SELECT * INTO v_stock
      FROM public.global_stocks
      WHERE id = v_ci.global_stock_id
      FOR UPDATE;

      IF NOT found THEN
        RAISE EXCEPTION 'stock not found for cart item %', v_ci.name;
      END IF;

      IF v_stock.availability <> 'sellable'::public.stock_availability THEN
        RAISE EXCEPTION 'insufficient sellable stock for %', v_ci.name;
      END IF;

      IF v_stock.quantity < v_ci.quantity THEN
        RAISE EXCEPTION 'insufficient stock quantity for % (requested %, available %)',
          v_ci.name, v_ci.quantity, v_stock.quantity;
      END IF;

      PERFORM public.create_and_post_stock_movement(
        p_tenant_id => v_parent_tenant_id,
        p_stock_id => v_ci.global_stock_id,
        p_quantity => v_ci.quantity,
        p_to_location_id => v_stock.location_id,
        p_to_availability => 'held'::public.stock_availability,
        p_to_grade_tag_id => v_stock.grade_tag_id,
        p_movement_type => 'availability_transfer'::public.stock_movement_type,
        p_notes => 'Dropship order hold',
        p_reference_type => 'shop_order',
        p_reference_id => v_order_id::text
      );

      SELECT gs.id INTO v_held_stock_id
      FROM public.global_stocks gs
      WHERE gs.shipment_item_id = v_stock.shipment_item_id
        AND gs.parent_tenant_id = v_parent_tenant_id
        AND gs.availability = 'held'::public.stock_availability
        AND gs.location_id IS NOT DISTINCT FROM v_stock.location_id
        AND coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id())
          = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id())
      ORDER BY gs.id DESC
      LIMIT 1;
    ELSE
      RAISE EXCEPTION 'cart line missing grade for %', v_ci.name;
    END IF;

    SELECT soi.id INTO v_order_item_id
    FROM public.shop_order_items soi
    WHERE soi.order_id = v_order_id
      AND soi.product_id = v_ci.product_id
      AND soi.listing_id IS NOT DISTINCT FROM v_ci.listing_id
    ORDER BY soi.id ASC
    LIMIT 1;

    IF v_order_item_id IS NULL THEN
      SELECT soi.id INTO v_order_item_id
      FROM public.shop_order_items soi
      WHERE soi.order_id = v_order_id
        AND soi.product_id = v_ci.product_id
      ORDER BY soi.id ASC
      LIMIT 1;
    END IF;

    IF v_order_item_id IS NOT NULL THEN
      UPDATE public.shop_order_items
      SET
        listing_id = coalesce(listing_id, v_listing_id),
        grade_tag_id = coalesce(grade_tag_id, v_grade_tag_id),
        global_stock_id = v_held_stock_id,
        cost_price_amount = coalesce(
          cost_price_amount,
          public.resolve_shop_order_item_landed_cost(v_held_stock_id, NULL, unit_list_price_amount)
        )
      WHERE id = v_order_item_id;
    END IF;

    IF v_listing_id IS NOT NULL THEN
      v_available_after := public.shop_product_grade_available_units(
        v_cart.tenant_id, v_ci.product_id, v_grade_tag_id
      );
      IF coalesce((
        SELECT display_quantity_override
        FROM public.shop_product_listings
        WHERE id = v_listing_id
      ), v_available_after, 0) <= 0 THEN
        UPDATE public.shop_product_listings
        SET is_active = false
        WHERE id = v_listing_id;
      END IF;
    ELSIF v_ci.global_stock_id IS NOT NULL THEN
      SELECT coalesce(sum(gs.quantity), 0) INTO v_available_after
      FROM public.global_stocks gs
      WHERE gs.shipment_item_id = (
        SELECT shipment_item_id FROM public.global_stocks WHERE id = v_ci.global_stock_id
      )
        AND gs.availability = 'sellable'::public.stock_availability;

      IF coalesce((
        SELECT display_quantity_override
        FROM public.shop_product_listings
        WHERE shop_id = v_shop.id
          AND product_id = v_ci.product_id
          AND global_stock_id = v_ci.global_stock_id
      ), v_available_after, 0) <= 0 THEN
        UPDATE public.shop_product_listings
        SET is_active = false
        WHERE shop_id = v_shop.id
          AND product_id = v_ci.product_id
          AND global_stock_id = v_ci.global_stock_id;
      END IF;
    END IF;
  END LOOP;

  DELETE FROM public.shop_stock_reservations
  WHERE cart_item_id IN (SELECT id FROM public.shop_cart_items WHERE cart_id = v_cart.id);

  UPDATE public.shop_carts
  SET status = 'converted', updated_at = now()
  WHERE id = v_cart.id;

  SELECT jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_order_status,
    'cart_id', v_cart.id,
    'shop_id', v_shop.id
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- 4. Cancel releases held stock + display qty
CREATE OR REPLACE FUNCTION public.advance_dropship_order_status(
  p_order_id bigint,
  p_target_status public.shop_order_status,
  p_remittance_ref text DEFAULT NULL,
  p_bank_trx_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.shop_orders;
  v_invoice public.global_invoices;
  v_current_status public.shop_order_status;
  v_is_valid boolean := false;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found');
  END IF;

  IF v_order.shop_type_snapshot <> 'dropship' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order is not a dropship order');
  END IF;

  v_current_status := v_order.status;

  IF v_current_status = p_target_status THEN
    RETURN jsonb_build_object('success', true, 'message', 'Status unchanged', 'new_status', p_target_status);
  END IF;

  IF v_current_status IN ('submitted', 'draft', 'placed', 'confirmed')
     AND p_target_status IN ('processing', 'cancelled') THEN
    v_is_valid := true;
  ELSIF v_current_status IN ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received') THEN
    IF p_target_status IN (
      'processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received', 'cancelled'
    ) THEN
      v_is_valid := true;
    END IF;
  END IF;

  IF NOT v_is_valid THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format(
        'Invalid status transition for dropship order from %s to %s',
        v_current_status,
        p_target_status
      )
    );
  END IF;

  UPDATE public.shop_orders
  SET
    status = p_target_status,
    delivered_at = CASE WHEN p_target_status = 'delivered' THEN now() ELSE delivered_at END,
    courier_remittance_ref = coalesce(p_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(p_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  WHERE id = p_order_id;

  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;

  IF p_target_status = 'cancelled' THEN
    PERFORM public.release_dropship_order_stock(p_order_id, true);
  END IF;

  IF p_target_status = 'processing' AND v_order.global_invoice_id IS NOT NULL THEN
    SELECT * INTO v_invoice FROM public.global_invoices WHERE id = v_order.global_invoice_id;
    IF v_invoice.invoice_status = 'issued'::public.global_invoice_status THEN
      PERFORM public.unpost_global_invoice(v_order.global_invoice_id);
    END IF;

    DELETE FROM public.universal_wallet_ledger
    WHERE source_type = 'shop_order'
      AND (
        source_id = p_order_id::text
        OR source_id = v_order.order_no
        OR source_id = v_invoice.invoice_no
      )
      AND tenant_id = v_order.tenant_id;

    UPDATE public.shop_orders
    SET global_invoice_id = NULL, updated_at = now()
    WHERE id = p_order_id;

    DELETE FROM public.global_return_items WHERE invoice_id = v_order.global_invoice_id;
    DELETE FROM public.global_invoice_items WHERE invoice_id = v_order.global_invoice_id;
    DELETE FROM public.global_invoices WHERE id = v_order.global_invoice_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'new_status', p_target_status);
END;
$$;

-- 5. Delete trigger delegates to release helper
CREATE OR REPLACE FUNCTION public.restock_dropship_order_on_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_dropship boolean := false;
BEGIN
  IF OLD.shop_type_snapshot = 'dropship' THEN
    v_is_dropship := true;
  ELSE
    SELECT (shop_type = 'dropship') INTO v_is_dropship
    FROM public.shops
    WHERE id = OLD.shop_id;
  END IF;

  IF NOT coalesce(v_is_dropship, false) THEN
    RETURN OLD;
  END IF;

  PERFORM public.release_dropship_order_stock(
    OLD.id,
    OLD.status IS DISTINCT FROM 'cancelled'
  );

  RETURN OLD;
END;
$$;

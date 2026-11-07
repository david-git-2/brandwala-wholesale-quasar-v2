-- shop_orders.placement_scope (shop = storefront cart, app = staff manual create)
ALTER TABLE public.shop_orders
  ADD COLUMN IF NOT EXISTS placement_scope text NOT NULL DEFAULT 'shop';

ALTER TABLE public.shop_orders
  DROP CONSTRAINT IF EXISTS shop_orders_placement_scope_check;

ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_placement_scope_check
    CHECK (placement_scope = ANY (ARRAY['shop'::text, 'app'::text]));

COMMENT ON COLUMN public.shop_orders.placement_scope IS
  'shop = customer storefront cart checkout; app = tenant staff manual create on behalf of customer group.';

UPDATE public.shop_orders
SET placement_scope = 'app'
WHERE cart_id IS NULL
  AND placement_scope = 'shop';

DROP FUNCTION IF EXISTS public.list_customer_shop_orders(bigint, integer, integer, text);

CREATE OR REPLACE FUNCTION public.staff_create_vendor_catalog_order (
  p_shop_id                bigint,
  p_customer_group_id      bigint,
  p_items                  jsonb,
  p_order_name             text    DEFAULT NULL::text,
  p_profile_id             bigint  DEFAULT NULL::bigint,
  p_recorded_at            timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_hidden_from_customer   boolean DEFAULT true,
  p_create_mode            text    DEFAULT 'standard'::text,
  p_initial_status         text    DEFAULT NULL::text,
  p_rates                  jsonb   DEFAULT NULL::jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_shop public.shops%rowtype;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status := 'submitted';
  v_profile_id bigint;
  v_billing_profile_warning boolean := false;
  v_can_negotiate boolean;
  v_is_negotiable boolean;
  v_ts timestamptz;
  v_elem jsonb;
  v_product_id bigint;
  v_qty integer;
  v_sell_price numeric;
  v_cost_price numeric;
  v_buy_currency_id bigint;
  v_prod_name text;
  v_prod_image text;
  v_prod_price_amount numeric;
  v_prod_price_currency_id bigint;
  v_product_available_units integer;
  v_item_count integer;
  v_result jsonb;
  v_order_name text;
  v_create_mode text;
  v_is_old_order boolean;
  v_sell_currency_id bigint;
  v_line_negotiation_status text;
  v_notify_title text;
  v_notify_body text;
  v_old_profit_rate numeric;
BEGIN
  PERFORM public.assert_staff_can_place_catalog_order_on_behalf(p_shop_id, p_customer_group_id);

  v_create_mode := lower(trim(coalesce(p_create_mode, 'standard')));
  v_is_old_order := v_create_mode = 'old_order';

  IF v_create_mode NOT IN ('standard', 'old_order') THEN
    RAISE EXCEPTION 'invalid create mode: %', p_create_mode;
  END IF;

  SELECT * INTO v_shop FROM public.shops WHERE id = p_shop_id AND is_active = true;
  IF v_shop.id IS NULL THEN
    RAISE EXCEPTION 'shop not found or inactive';
  END IF;

  IF v_shop.shop_type <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'shop is not vendor catalog';
  END IF;

  IF v_shop.order_mode <> 'procurement_intent' THEN
    RAISE EXCEPTION 'invalid order mode for vendor catalog shop';
  END IF;

  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'order must include at least one item';
  END IF;

  v_sell_currency_id := v_shop.sell_currency_id;
  v_buy_currency_id := v_shop.buy_currency_id;

  IF v_is_old_order THEN
    IF p_rates IS NULL THEN
      RAISE EXCEPTION 'rates required for old order create';
    END IF;
    IF p_initial_status IS NULL OR trim(p_initial_status) = '' THEN
      v_order_status := 'procuring'::public.shop_order_status;
    ELSE
      IF p_initial_status NOT IN ('procuring', 'delivered', 'closed') THEN
        RAISE EXCEPTION 'invalid initial status for old order: %', p_initial_status;
      END IF;
      v_order_status := p_initial_status::public.shop_order_status;
    END IF;
    v_is_negotiable := false;
    v_line_negotiation_status := 'confirmed';
    v_old_profit_rate := coalesce(
      nullif(p_rates->>'profit_rate', '')::numeric,
      nullif(p_rates->>'first_offer_rate', '')::numeric,
      nullif(p_rates->>'final_offer_rate', '')::numeric
    );
  ELSE
    SELECT can_negotiate INTO v_can_negotiate
    FROM public.get_shop_permissions_for_customer_group(p_shop_id, p_customer_group_id)
    LIMIT 1;

    v_is_negotiable := coalesce(v_shop.is_negotiable, false) AND coalesce(v_can_negotiate, false);
    v_order_status := 'submitted'::public.shop_order_status;
    v_line_negotiation_status := 'pending';
  END IF;

  v_profile_id := p_profile_id;
  IF v_profile_id IS NULL THEN
    v_profile_id := public.resolve_customer_profile_for_group(v_shop.tenant_id, p_customer_group_id);
  END IF;
  IF v_profile_id IS NULL THEN
    v_billing_profile_warning := true;
  END IF;

  v_ts := coalesce(p_recorded_at, now());

  v_order_name := nullif(trim(coalesce(p_order_name, '')), '');
  IF v_order_name IS NULL THEN
    v_order_name := 'Catalog order';
  END IF;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_elem->>'product_id')::bigint;
    v_qty := greatest(1, coalesce((v_elem->>'quantity')::int, 1));
    IF v_product_id IS NULL THEN
      RAISE EXCEPTION 'each item requires product_id';
    END IF;

    IF v_is_old_order THEN
      v_sell_price := (v_elem->>'sell_price_amount')::numeric;
      IF v_sell_price IS NULL OR v_sell_price < 0 THEN
        RAISE EXCEPTION 'each old order item requires sell_price_amount >= 0';
      END IF;
    END IF;

    SELECT
      p.name,
      p.image_url,
      p.list_price_amount,
      p.list_price_currency_id,
      p.available_units
    INTO
      v_prod_name,
      v_prod_image,
      v_prod_price_amount,
      v_prod_price_currency_id,
      v_product_available_units
    FROM public.products p
    WHERE p.id = v_product_id;

    IF v_prod_name IS NULL THEN
      RAISE EXCEPTION 'product not found: %', v_product_id;
    END IF;

    IF NOT v_is_old_order
       AND NOT public.shop_catalog_meets_min_available_units(v_shop.min_available_units, v_product_available_units) THEN
      RAISE EXCEPTION 'product % does not meet minimum available units requirement', v_product_id;
    END IF;
  END LOOP;

  SELECT public.generate_shop_order_number(v_shop.tenant_id, v_shop.id) INTO v_order_no;

  INSERT INTO public.shop_orders (
    tenant_id,
    shop_id,
    customer_group_id,
    cart_id,
    order_no,
    name,
    shop_type_snapshot,
    order_mode_snapshot,
    is_negotiable_snapshot,
    status,
    negotiate_round,
    profile_id,
    created_by_email,
    placement_scope,
    hidden_from_customer,
    catalog_manual_price_entry,
    conversion_rate,
    cargo_rate,
    profit_rate,
    first_offer_rate,
    final_offer_rate,
    profit_basis,
    placed_at,
    created_at,
    updated_at
  ) VALUES (
    v_shop.tenant_id,
    v_shop.id,
    p_customer_group_id,
    NULL,
    v_order_no,
    v_order_name,
    v_shop.shop_type,
    v_shop.order_mode,
    v_is_negotiable,
    v_order_status,
    0,
    v_profile_id,
    public.current_user_email(),
    'app',
    coalesce(p_hidden_from_customer, true),
    v_is_old_order,
    CASE WHEN v_is_old_order THEN (p_rates->>'conversion_rate')::numeric ELSE NULL END,
    CASE WHEN v_is_old_order THEN (p_rates->>'cargo_rate')::numeric ELSE NULL END,
    CASE WHEN v_is_old_order THEN v_old_profit_rate ELSE NULL END,
    CASE WHEN v_is_old_order THEN v_old_profit_rate ELSE NULL END,
    CASE WHEN v_is_old_order THEN v_old_profit_rate ELSE NULL END,
    CASE WHEN v_is_old_order THEN nullif(p_rates->>'profit_basis', '') ELSE NULL END,
    v_ts,
    v_ts,
    v_ts
  )
  RETURNING id INTO v_order_id;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_elem->>'product_id')::bigint;
    v_qty := greatest(1, coalesce((v_elem->>'quantity')::int, 1));
    v_sell_price := coalesce((v_elem->>'sell_price_amount')::numeric, NULL);
    v_cost_price := nullif(v_elem->>'cost_price_amount', '')::numeric;

    SELECT
      p.name,
      p.image_url,
      p.list_price_amount,
      p.list_price_currency_id
    INTO
      v_prod_name,
      v_prod_image,
      v_prod_price_amount,
      v_prod_price_currency_id
    FROM public.products p
    WHERE p.id = v_product_id;

    IF v_is_old_order THEN
      INSERT INTO public.shop_order_items (
        order_id,
        product_id,
        listing_id,
        grade_tag_id,
        global_stock_id,
        global_stock_allocation_id,
        name,
        image_url,
        quantity,
        unit_list_price_amount,
        unit_list_price_currency_id,
        customer_sell_price_amount,
        customer_sell_price_currency_id,
        staff_offer_amount,
        staff_offer_currency_id,
        final_price_amount,
        final_price_currency_id,
        cost_price_amount,
        cost_price_currency_id,
        negotiation_status,
        is_first_offer_manual,
        is_final_offer_manual,
        staff_offer_at,
        final_offer_at
      ) VALUES (
        v_order_id,
        v_product_id,
        NULL,
        NULL,
        NULL,
        NULL,
        v_prod_name,
        v_prod_image,
        v_qty,
        v_prod_price_amount,
        v_prod_price_currency_id,
        v_sell_price,
        v_sell_currency_id,
        v_sell_price,
        v_sell_currency_id,
        v_sell_price,
        v_sell_currency_id,
        v_cost_price,
        CASE WHEN v_cost_price IS NOT NULL THEN v_buy_currency_id ELSE NULL END,
        v_line_negotiation_status,
        true,
        true,
        v_ts,
        v_ts
      );
    ELSE
      INSERT INTO public.shop_order_items (
        order_id,
        product_id,
        listing_id,
        grade_tag_id,
        global_stock_id,
        global_stock_allocation_id,
        name,
        image_url,
        quantity,
        unit_list_price_amount,
        unit_list_price_currency_id,
        unit_sell_price_amount,
        unit_sell_price_currency_id,
        unit_minimum_sell_price_amount,
        unit_minimum_sell_price_currency_id,
        customer_sell_price_amount,
        customer_sell_price_currency_id,
        customer_offer_amount,
        customer_offer_currency_id,
        final_price_amount,
        final_price_currency_id,
        cost_price_amount,
        cost_price_currency_id,
        negotiation_status
      ) VALUES (
        v_order_id,
        v_product_id,
        NULL,
        NULL,
        NULL,
        NULL,
        v_prod_name,
        v_prod_image,
        v_qty,
        v_prod_price_amount,
        v_prod_price_currency_id,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        v_line_negotiation_status
      );
    END IF;
  END LOOP;

  SELECT count(*)::integer INTO v_item_count FROM public.shop_order_items WHERE order_id = v_order_id;

  IF v_is_old_order THEN
    v_notify_title := format('Backfill order %s', v_order_no);
    v_notify_body := format('%s items, status %s', v_item_count, v_order_status::text);
  ELSE
    v_notify_title := format('New order %s', v_order_no);
    v_notify_body := format('%s items to price', v_item_count);
  END IF;

  PERFORM public.notify_catalog_shop_order(
    p_order_id := v_order_id,
    p_notify_staff := true,
    p_notify_customer := NOT coalesce(p_hidden_from_customer, true),
    p_event_type := 'catalog.order.created',
    p_title := v_notify_title,
    p_body := v_notify_body
  );

  SELECT jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_order_status,
    'shop_id', v_shop.id,
    'billing_profile_warning', v_billing_profile_warning
  ) INTO v_result;

  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.staff_create_vendor_catalog_order(
  bigint,
  bigint,
  jsonb,
  text,
  bigint,
  timestamp with time zone,
  boolean,
  text,
  text,
  jsonb
) TO anon;

GRANT ALL ON FUNCTION public.staff_create_vendor_catalog_order(
  bigint,
  bigint,
  jsonb,
  text,
  bigint,
  timestamp with time zone,
  boolean,
  text,
  text,
  jsonb
) TO authenticated;

GRANT ALL ON FUNCTION public.staff_create_vendor_catalog_order(
  bigint,
  bigint,
  jsonb,
  text,
  bigint,
  timestamp with time zone,
  boolean,
  text,
  text,
  jsonb
) TO service_role;

CREATE OR REPLACE FUNCTION public.staff_create_dropship_order (
  p_shop_id                   bigint,
  p_customer_group_id         bigint,
  p_items                     jsonb,
  p_recipient_name            text,
  p_recipient_phone           text,
  p_shipping_address          text,
  p_recipient_phone_secondary text    DEFAULT NULL::text,
  p_shipping_district         text    DEFAULT NULL::text,
  p_shipping_thana            text    DEFAULT NULL::text,
  p_shipping_post_code        text    DEFAULT NULL::text,
  p_profile_id                bigint  DEFAULT NULL::bigint,
  p_is_prepaid                boolean DEFAULT false,
  p_delivery_instructions     text    DEFAULT NULL::text,
  p_cod_charge_amount         numeric DEFAULT 0,
  p_delivery_charge_amount    numeric DEFAULT 0,
  p_print_charge_amount       numeric DEFAULT 0,
  p_packing_charge_amount     numeric DEFAULT 0,
  p_discount_amount           numeric DEFAULT 0,
  p_recipient_pays_delivery   boolean DEFAULT true,
  p_recipient_pays_cod        boolean DEFAULT true
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
    recipient_profile_id, profile_id, created_by_email, placement_scope,
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
    v_recipient_profile_id, v_profile_id, public.current_user_email(), 'app',
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
$function$;

GRANT ALL ON FUNCTION
  public.staff_create_dropship_order(bigint, bigint, jsonb, text, text, text, text, text, text, text, bigint, boolean, text, numeric, numeric, numeric, numeric, numeric, boolean,
  boolean) TO anon;

GRANT ALL ON FUNCTION
  public.staff_create_dropship_order(bigint, bigint, jsonb, text, text, text, text, text, text, text, bigint, boolean, text, numeric, numeric, numeric, numeric, numeric, boolean,
  boolean) TO authenticated;

GRANT ALL ON FUNCTION
  public.staff_create_dropship_order(bigint, bigint, jsonb, text, text, text, text, text, text, text, bigint, boolean, text, numeric, numeric, numeric, numeric, numeric, boolean,
  boolean) TO service_role;
CREATE OR REPLACE FUNCTION public.submit_shop_order_from_cart (
  p_cart_id                   bigint,
  p_recipient_name            text,
  p_recipient_phone           text,
  p_shipping_address          text,
  p_recipient_phone_secondary text    DEFAULT NULL::text,
  p_shipping_district         text    DEFAULT NULL::text,
  p_shipping_thana            text    DEFAULT NULL::text,
  p_profile_id                bigint  DEFAULT NULL::bigint,
  p_is_prepaid                boolean DEFAULT false,
  p_delivery_instructions     text    DEFAULT NULL::text,
  p_cod_charge_amount         numeric DEFAULT 0,
  p_delivery_charge_amount    numeric DEFAULT 0,
  p_print_charge_amount       numeric DEFAULT 0,
  p_packing_charge_amount     numeric DEFAULT 0,
  p_discount_amount           numeric DEFAULT 0
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_cart public.shop_carts%rowtype;
  v_shop public.shops%rowtype;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_item_count integer;
  v_result jsonb;
  v_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci record;
  v_rem_alloc_qty integer;
  v_rem_override_qty integer;
begin
  select * into v_cart from public.shop_carts where id = p_cart_id and status = 'active';
  if v_cart.id is null then
    raise exception 'active cart not found';
  end if;

  if not public.is_cart_owner(v_cart.customer_group_id, v_cart.tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_shop from public.shops where id = v_cart.shop_id;
  if v_shop.id is null or not v_shop.is_active then
    raise exception 'shop not found or inactive';
  end if;

  select can_place_order, can_negotiate
  into v_can_place_order, v_can_negotiate
  from public.get_shop_permissions_for_customer(v_shop.id);

  if coalesce(v_can_place_order, false) is not true then
    raise exception 'checkout not allowed for this customer group';
  end if;

  select count(*) into v_item_count from public.shop_cart_items where cart_id = p_cart_id;
  if v_item_count = 0 then
    raise exception 'cart is empty';
  end if;

  if v_shop.shop_type = 'dropship' then
    if exists (
      select 1 from public.shop_cart_items ci
      where ci.cart_id = p_cart_id
        and ci.customer_sell_price_currency_id = ci.unit_minimum_sell_price_currency_id
        and ci.customer_sell_price_amount < ci.unit_minimum_sell_price_amount
    ) then
      raise exception 'price floor violation: some items are priced below the minimum sell price';
    end if;
  end if;

  v_profile_id := p_profile_id;
  if v_profile_id is null then
    v_profile_id := public.resolve_customer_profile_for_group(v_cart.tenant_id, v_cart.customer_group_id);
  end if;

  if v_shop.shop_type = 'vendor_catalog' then
    if v_shop.order_mode <> 'procurement_intent' then
      raise exception 'invalid order mode for vendor catalog shop';
    end if;
    -- Catalog orders always start at submitted (CATALOG_NEGOTIATION.md §2.1); negotiation begins at priced.
    v_order_status := 'submitted';
  else
    if v_shop.order_mode = 'checkout_fixed' then
      v_order_status := 'confirmed';
    else
      v_order_status := 'submitted';
    end if;
  end if;

  select public.generate_shop_order_number(v_cart.tenant_id, v_cart.shop_id) into v_order_no;

  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  if v_phone is not null then
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
  end if;

  insert into public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id,
    order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot,
    status, negotiate_round,
    recipient_name, recipient_phone, recipient_phone_secondary,
    shipping_address, shipping_district, shipping_thana,
    recipient_profile_id, profile_id,
    created_by_email, placement_scope,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  )
  values (
    v_cart.tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id,
    v_order_no, 'Order for ' || coalesce(nullif(trim(coalesce(p_recipient_name, '')), ''), 'customer'),
    v_shop.shop_type, v_shop.order_mode,
    coalesce(v_shop.is_negotiable, false) and coalesce(v_can_negotiate, false),
    v_order_status, case when v_order_status = 'negotiating' then 1 else 0 end,
    nullif(trim(coalesce(p_recipient_name, '')), ''), v_phone, nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''),
    nullif(trim(coalesce(p_shipping_address, '')), ''), nullif(trim(coalesce(p_shipping_district, '')), ''), nullif(trim(coalesce(p_shipping_thana, '')), ''),
    v_recipient_profile_id, v_profile_id,
    public.current_user_email(),
    'shop',
    p_cod_charge_amount, p_delivery_charge_amount, p_print_charge_amount, p_packing_charge_amount, p_discount_amount,
    p_is_prepaid, p_delivery_instructions, v_shop.deduct_charges_from_margin,
    false, false, v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
  )
  returning id into v_order_id;

  insert into public.shop_order_items (
    order_id, product_id, global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    cost_price_amount, cost_price_currency_id
  )
  select
    v_order_id, ci.product_id, ci.global_stock_id, ci.global_stock_allocation_id,
    ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    case when v_shop.shop_type = 'dropship' then ci.customer_sell_price_amount else null end,
    case when v_shop.shop_type = 'dropship' then ci.customer_sell_price_currency_id else null end,
    case
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, ci.unit_list_price_amount)
      else null
    end,
    case
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id, ci.unit_list_price_currency_id)
      else null
    end,
    case when v_shop.shop_type = 'dropship' then public.resolve_shop_order_item_landed_cost(ci.global_stock_id, null, ci.unit_list_price_amount) else null end,
    case when v_shop.shop_type = 'dropship' then v_shop.buy_currency_id else null end
  from public.shop_cart_items ci
  where ci.cart_id = p_cart_id;

  if v_shop.shop_type = 'dropship' then
    for v_ci in select * from public.shop_cart_items where cart_id = p_cart_id loop
      if v_ci.product_id is not null and v_ci.global_stock_allocation_id is not null then
        update public.shop_product_listings
        set display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
        where shop_id = v_shop.id
          and product_id = v_ci.product_id
          and global_stock_allocation_id = v_ci.global_stock_allocation_id
          and display_quantity_override is not null;
      end if;

      if v_ci.global_stock_allocation_id is not null then
        update public.global_stock_allocations
        set quantity = greatest(0, quantity - v_ci.quantity)
        where id = v_ci.global_stock_allocation_id;
      end if;

      if v_ci.global_stock_id is not null then
        update public.global_stocks
        set quantity = greatest(0, quantity - v_ci.quantity)
        where id = v_ci.global_stock_id;
      end if;

      if v_ci.product_id is not null and v_ci.global_stock_allocation_id is not null then
        select gsa.quantity into v_rem_alloc_qty
        from public.global_stock_allocations gsa
        where gsa.id = v_ci.global_stock_allocation_id;

        select display_quantity_override into v_rem_override_qty
        from public.shop_product_listings
        where shop_id = v_shop.id
          and product_id = v_ci.product_id
          and global_stock_allocation_id = v_ci.global_stock_allocation_id;

        if coalesce(v_rem_override_qty, v_rem_alloc_qty, 0) <= 0 then
          update public.shop_product_listings
          set is_active = false
          where shop_id = v_shop.id
            and product_id = v_ci.product_id
            and global_stock_allocation_id = v_ci.global_stock_allocation_id;
        end if;
      end if;
    end loop;
  end if;

  delete from public.shop_stock_reservations
  where cart_item_id in (select id from public.shop_cart_items where cart_id = p_cart_id);

  update public.shop_carts
  set status = 'converted', updated_at = now()
  where id = p_cart_id;

  if v_shop.shop_type = 'vendor_catalog' then
    perform public.notify_catalog_shop_order(
      p_order_id := v_order_id,
      p_notify_staff := true,
      p_notify_customer := false,
      p_event_type := 'catalog.order.created',
      p_title := format('New order %s', v_order_no),
      p_body := format('%s items to price', v_item_count)
    );
  end if;

  select jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_order_status
  ) into v_result;

  return v_result;
end;
$function$;

GRANT ALL ON FUNCTION public.submit_shop_order_from_cart(bigint, text, text, text, text, text, text, bigint, boolean, text, numeric, numeric, numeric, numeric, numeric) TO anon;

GRANT ALL ON FUNCTION public.submit_shop_order_from_cart(bigint, text, text, text, text, text, text, bigint, boolean, text, numeric, numeric, numeric, numeric, numeric) TO
  authenticated;

GRANT ALL ON FUNCTION public.submit_shop_order_from_cart(bigint, text, text, text, text, text, text, bigint, boolean, text, numeric, numeric, numeric, numeric, numeric) TO
  service_role;
CREATE OR REPLACE FUNCTION public.list_customer_shop_orders (
  p_tenant_id     bigint,
  p_limit         integer DEFAULT 20,
  p_offset        integer DEFAULT 0,
  p_status_bucket text    DEFAULT NULL::text
)
  RETURNS TABLE (
    id                     bigint,
    shop_id                bigint,
    shop_name              text,
    shop_slug              text,
    shop_type_snapshot     public.shop_type_enum,
    is_negotiable_snapshot boolean,
    order_no               text,
    status                 public.shop_order_status,
    item_count             bigint,
    can_see_buy_price      boolean,
    can_see_sell_price     boolean,
    sell_currency_id       bigint,
    currency_symbol        text,
    total_amount           numeric,
    created_at             timestamp with time zone,
    placement_scope        text,
    created_by_email       text
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_group_id bigint;
  v_limit integer;
  v_offset integer;
BEGIN
  IF p_tenant_id IS NULL THEN
    RETURN;
  END IF;

  IF p_status_bucket IS NOT NULL
     AND p_status_bucket NOT IN ('needs_you', 'in_progress', 'done') THEN
    RETURN;
  END IF;

  v_group_id := public.current_customer_group_id(p_tenant_id);
  IF v_group_id IS NULL THEN
    RETURN;
  END IF;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  RETURN QUERY
  SELECT
    o.id,
    o.shop_id,
    s.name AS shop_name,
    s.slug AS shop_slug,
    o.shop_type_snapshot,
    o.is_negotiable_snapshot,
    o.order_no,
    o.status,
    (
      SELECT count(*)::bigint
      FROM public.shop_order_items soi
      WHERE soi.order_id = o.id
    ) AS item_count,
    CASE
      WHEN o.shop_type_snapshot = 'dropship' THEN true
      WHEN o.cart_id IS NOT NULL THEN coalesce(c.can_see_buy_price_snapshot, false)
      ELSE coalesce(live_perm.can_see_buy_price, false)
    END AS can_see_buy_price,
    CASE
      WHEN o.shop_type_snapshot = 'dropship' THEN true
      WHEN o.cart_id IS NOT NULL THEN coalesce(c.can_see_sell_price_snapshot, false)
      ELSE coalesce(live_perm.can_see_sell_price, false)
    END AS can_see_sell_price,
    s.sell_currency_id,
    gc.symbol AS currency_symbol,
    CASE
      WHEN (
        CASE
          WHEN o.shop_type_snapshot = 'dropship' THEN true
          WHEN o.cart_id IS NOT NULL THEN coalesce(c.can_see_sell_price_snapshot, false)
          ELSE coalesce(live_perm.can_see_sell_price, false)
        END
      ) THEN
        coalesce(
          (
            SELECT sum(
              coalesce(
                soi.final_price_amount,
                soi.customer_offer_amount,
                soi.unit_sell_price_amount,
                soi.unit_list_price_amount
              ) * soi.quantity
            )
            FROM public.shop_order_items soi
            WHERE soi.order_id = o.id
          ),
          0
        )::numeric
      ELSE NULL
    END AS total_amount,
    o.created_at,
    o.placement_scope,
    o.created_by_email
  FROM public.shop_orders o
  JOIN public.shops s ON s.id = o.shop_id
  LEFT JOIN public.shop_carts c ON c.id = o.cart_id
  LEFT JOIN LATERAL (
    SELECT p.can_see_buy_price, p.can_see_sell_price
    FROM public.get_shop_permissions_for_customer(o.shop_id) p
    LIMIT 1
  ) live_perm ON true
  LEFT JOIN public.global_currencies gc ON gc.id = s.sell_currency_id
  WHERE o.tenant_id = p_tenant_id
    AND o.customer_group_id = v_group_id
    AND NOT o.hidden_from_customer
    AND o.status IS DISTINCT FROM 'draft'
    AND (
      p_status_bucket IS NULL
      OR public.customer_shop_order_glance_bucket(o.status) = p_status_bucket
    )
  ORDER BY o.created_at DESC
  LIMIT v_limit
  OFFSET v_offset;
END;
$function$;

GRANT ALL ON FUNCTION public.list_customer_shop_orders(bigint, integer, integer, text) TO anon;

GRANT ALL ON FUNCTION public.list_customer_shop_orders(bigint, integer, integer, text) TO authenticated;

GRANT ALL ON FUNCTION public.list_customer_shop_orders(bigint, integer, integer, text) TO service_role;
CREATE OR REPLACE FUNCTION public.get_customer_shop_order (
  p_tenant_id bigint,
  p_order_id  bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_group_id bigint;
  v_order public.shop_orders%rowtype;
  v_shop_name text;
  v_shop_slug text;
  v_sell_currency_id bigint;
  v_buy_currency_id bigint;
  v_sell_symbol text;
  v_buy_symbol text;
  v_item_count bigint;
  v_total_amount numeric;
  v_items jsonb;
  v_order_json jsonb;
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;

  v_group_id := public.current_customer_group_id(p_tenant_id);
  if v_group_id is null then
    raise exception 'access denied';
  end if;

  select *
  into v_order
  from public.shop_orders o
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  if v_order.customer_group_id is distinct from v_group_id then
    raise exception 'order not found';
  end if;

  if v_order.hidden_from_customer then
    raise exception 'order not found';
  end if;

  select
    s.name,
    s.slug,
    s.sell_currency_id,
    s.buy_currency_id,
    sell_gc.symbol,
    buy_gc.symbol
  into
    v_shop_name,
    v_shop_slug,
    v_sell_currency_id,
    v_buy_currency_id,
    v_sell_symbol,
    v_buy_symbol
  from public.shops s
  left join public.global_currencies sell_gc on sell_gc.id = s.sell_currency_id
  left join public.global_currencies buy_gc on buy_gc.id = s.buy_currency_id
  where s.id = v_order.shop_id;

  if v_order.shop_type_snapshot = 'dropship'::public.shop_type_enum then
    v_can_see_buy_price := true;
    v_can_see_sell_price := true;
  else
    select
      case
        when v_order.cart_id is not null then coalesce(c.can_see_buy_price_snapshot, perm.can_see_buy_price, false)
        else coalesce(perm.can_see_buy_price, false)
      end,
      case
        when v_order.cart_id is not null then coalesce(c.can_see_sell_price_snapshot, perm.can_see_sell_price, false)
        else coalesce(perm.can_see_sell_price, false)
      end
    into v_can_see_buy_price, v_can_see_sell_price
    from public.get_shop_permissions_for_customer(v_order.shop_id) perm
    left join public.shop_carts c on c.id = v_order.cart_id;
  end if;

  v_can_see_buy_price := coalesce(v_can_see_buy_price, false);
  v_can_see_sell_price := coalesce(v_can_see_sell_price, false);

  select count(*)::bigint
  into v_item_count
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    sum(
      coalesce(
        soi.final_price_amount,
        soi.customer_offer_amount,
        soi.unit_sell_price_amount,
        case
          when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum and not v_can_see_buy_price then null
          else soi.unit_list_price_amount
        end
      ) * soi.quantity
    ),
    0
  )
  into v_total_amount
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', soi.id,
        'order_id', soi.order_id,
        'product_id', soi.product_id,
        'global_stock_id', soi.global_stock_id,
        'global_stock_allocation_id', soi.global_stock_allocation_id,
        'name', soi.name,
        'image_url', soi.image_url,
        'quantity', soi.quantity,
        'unit_list_price_amount', case when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum and not v_can_see_buy_price then null else soi.unit_list_price_amount end,
        'unit_list_price_currency_id', case when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum and not v_can_see_buy_price then null else soi.unit_list_price_currency_id end,
        'unit_sell_price_amount', soi.unit_sell_price_amount,
        'unit_sell_price_currency_id', soi.unit_sell_price_currency_id,
        'unit_minimum_sell_price_amount', soi.unit_minimum_sell_price_amount,
        'unit_minimum_sell_price_currency_id', soi.unit_minimum_sell_price_currency_id,
        'customer_sell_price_amount', soi.customer_sell_price_amount,
        'customer_sell_price_currency_id', soi.customer_sell_price_currency_id,
        'customer_offer_amount', soi.customer_offer_amount,
        'customer_offer_currency_id', soi.customer_offer_currency_id,
        'staff_offer_amount', soi.staff_offer_amount,
        'staff_offer_currency_id', soi.staff_offer_currency_id,
        'is_first_offer_manual', soi.is_first_offer_manual,
        'final_price_amount', soi.final_price_amount,
        'final_price_currency_id', soi.final_price_currency_id,
        'final_offer_amount', soi.final_price_amount,
        'is_final_offer_manual', soi.is_final_offer_manual,
        'confirmed_quantity', soi.confirmed_quantity,
        'weight_kg', soi.weight_kg,
        'customer_decision_status', soi.customer_decision_status,
        'customer_decision_at', soi.customer_decision_at,
        'negotiation_status', soi.negotiation_status,
        'staff_offer_at', soi.staff_offer_at,
        'customer_counter_at', soi.customer_counter_at,
        'final_offer_at', soi.final_offer_at,
        'returned_quantity', soi.returned_quantity,
        'sku', p.product_code,
        'brand', p.brand,
        'barcode', p.barcode,
        'minimum_order_quantity', p.minimum_order_quantity,
        'created_at', soi.created_at,
        'updated_at', soi.updated_at
      )
      order by soi.created_at, soi.id
    ),
    '[]'::jsonb
  )
  into v_items
  from public.shop_order_items soi
  left join public.products p on p.id = soi.product_id
  where soi.order_id = v_order.id;

  v_order_json :=
    jsonb_build_object(
      'id', v_order.id,
      'tenant_id', v_order.tenant_id,
      'shop_id', v_order.shop_id,
      'shop_name', v_shop_name,
      'shop_slug', v_shop_slug,
      'customer_group_id', v_order.customer_group_id,
      'cart_id', v_order.cart_id,
      'order_no', v_order.order_no,
      'name', v_order.name,
      'shop_type_snapshot', v_order.shop_type_snapshot,
      'order_mode_snapshot', v_order.order_mode_snapshot,
      'is_negotiable_snapshot', v_order.is_negotiable_snapshot,
      'status', v_order.status,
      'negotiate_round', v_order.negotiate_round,
      'cargo_rate', v_order.cargo_rate,
      'conversion_rate', v_order.conversion_rate,
      'profit_rate', v_order.profit_rate,
      'first_offer_rate', v_order.first_offer_rate,
      'final_offer_rate', v_order.final_offer_rate,
      'profit_basis', v_order.profit_basis,
      'package_weight_kg', v_order.package_weight_kg,
      'recipient_name', v_order.recipient_name,
      'recipient_phone', v_order.recipient_phone,
      'recipient_phone_secondary', v_order.recipient_phone_secondary,
      'shipping_address', v_order.shipping_address,
      'shipping_district', v_order.shipping_district,
      'shipping_thana', v_order.shipping_thana,
      'recipient_profile_id', v_order.recipient_profile_id,
      'profile_id', v_order.profile_id,
      'placed_at', v_order.placed_at,
      'fulfilled_at', v_order.fulfilled_at,
      'shop_sell_currency_id', v_sell_currency_id,
      'shop_buy_currency_id', v_buy_currency_id,
      'shop_sell_currency_symbol', v_sell_symbol,
      'shop_buy_currency_symbol', v_buy_symbol,
      'can_see_buy_price', v_can_see_buy_price,
      'can_see_sell_price', v_can_see_sell_price
    )
    || jsonb_build_object(
      'created_at', v_order.created_at,
      'updated_at', v_order.updated_at,
      'cod_charge_amount', v_order.cod_charge_amount,
      'delivery_charge_amount', v_order.delivery_charge_amount,
      'print_charge_amount', v_order.print_charge_amount,
      'packing_charge_amount', v_order.packing_charge_amount,
      'discount_amount', v_order.discount_amount,
      'is_prepaid_snapshot', v_order.is_prepaid_snapshot,
      'delivery_instructions', v_order.delivery_instructions,
      'deduct_charges_from_margin', v_order.deduct_charges_from_margin,
      'deduct_cod_from_margin', v_order.deduct_cod_from_margin,
      'deduct_delivery_from_margin', v_order.deduct_delivery_from_margin,
      'deduct_print_from_margin', v_order.deduct_print_from_margin,
      'deduct_packing_from_margin', v_order.deduct_packing_from_margin,
      'item_count', v_item_count,
      'total_amount', case
        when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum
          and not v_can_see_buy_price
          and not v_can_see_sell_price then null
        when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum
          and not v_can_see_buy_price
          and v_total_amount = 0 then null
        else v_total_amount
      end,
      'cod_collect_amount', v_order.cod_collect_amount,
      'courier_name', v_order.courier_name,
      'courier_awb_number', v_order.courier_awb_number,
      'tracking_url', v_order.tracking_url,
      'payout_settlement_status', v_order.payout_settlement_status,
      'cancel_reason', v_order.cancel_reason,
      'recipient_call_attempt_count', coalesce(v_order.recipient_call_attempt_count, 0),
      'recipient_verified_at', v_order.recipient_verified_at,
      'placement_scope', v_order.placement_scope,
      'created_by_email', v_order.created_by_email
    );

  return jsonb_build_object(
    'order', v_order_json,
    'items', v_items
  );
end;
$function$;

GRANT ALL ON FUNCTION public.get_customer_shop_order(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_customer_shop_order(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_customer_shop_order(bigint, bigint) TO service_role;
CREATE OR REPLACE FUNCTION public.list_shop_orders_staff_page (
  p_tenant_id         bigint,
  p_parent_tenant_id  bigint                   DEFAULT NULL::bigint,
  p_limit             integer                  DEFAULT 30,
  p_search            text                     DEFAULT NULL::text,
  p_status            text                     DEFAULT NULL::text,
  p_shop_id           bigint                   DEFAULT NULL::bigint,
  p_shop_type         text                     DEFAULT NULL::text,
  p_profile_id        bigint                   DEFAULT NULL::bigint,
  p_cursor_created_at timestamp with time zone DEFAULT NULL::timestamp WITH time zone,
  p_cursor_id         bigint                   DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_limit integer := greatest(1, least(coalesce(p_limit, 30), 100));
  v_fetch integer := v_limit + 1;
  v_is_parent_query boolean;
  v_shops jsonb := '[]'::jsonb;
  v_orders jsonb := '[]'::jsonb;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
BEGIN
  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  v_is_parent_query := (p_parent_tenant_id IS NOT NULL AND p_parent_tenant_id = p_tenant_id);

  IF p_cursor_created_at IS NULL AND p_cursor_id IS NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.memberships m
      WHERE (m.tenant_id = p_tenant_id OR m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id))
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
    ) THEN
      RAISE EXCEPTION 'not allowed';
    END IF;

    IF v_is_parent_query THEN
      SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.name), '[]'::jsonb)
      INTO v_shops
      FROM (
        SELECT
          s.id,
          s.tenant_id,
          s.name,
          s.slug,
          s.shop_type,
          coalesce(t.name, '')::text AS tenant_name
        FROM public.shops s
        LEFT JOIN public.tenants t ON t.id = s.tenant_id
        WHERE (
          s.tenant_id = p_parent_tenant_id
          OR s.tenant_id IN (SELECT public.list_child_tenant_ids(p_parent_tenant_id))
        )
          AND s.deleted_at IS NULL
        ORDER BY s.name
        LIMIT 500
      ) x;
    ELSE
      SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.name), '[]'::jsonb)
      INTO v_shops
      FROM (
        SELECT
          s.id,
          s.tenant_id,
          s.name,
          s.slug,
          s.shop_type,
          coalesce(t.name, '')::text AS tenant_name
        FROM public.shops s
        LEFT JOIN public.tenants t ON t.id = s.tenant_id
        WHERE s.tenant_id = p_tenant_id
          AND s.deleted_at IS NULL
        ORDER BY s.name
        LIMIT 500
      ) x;
    END IF;
  END IF;

  WITH base AS (
    SELECT
      o.id,
      o.tenant_id,
      o.shop_id,
      s.name AS shop_name,
      o.customer_group_id,
      cg.name AS customer_group_name,
      o.order_no,
      o.name,
      o.shop_type_snapshot,
      o.is_negotiable_snapshot,
      o.status,
      o.created_at,
      o.updated_at,
      o.hidden_from_customer,
      o.catalog_manual_price_entry,
      o.placement_scope,
      o.created_by_email,
      (SELECT count(*)::bigint FROM public.shop_order_items WHERE order_id = o.id) AS item_count,
      coalesce(t.name, '')::text AS tenant_name
    FROM public.shop_orders o
    JOIN public.shops s ON s.id = o.shop_id
    JOIN public.customer_groups cg ON cg.id = o.customer_group_id
    LEFT JOIN public.tenants t ON t.id = o.tenant_id
    WHERE (
      (
        v_is_parent_query
        AND (
          o.tenant_id = p_parent_tenant_id
          OR o.tenant_id IN (SELECT public.list_child_tenant_ids(p_parent_tenant_id))
        )
      )
      OR (NOT v_is_parent_query AND o.tenant_id = p_tenant_id)
    )
      AND (p_status IS NULL OR o.status::text = p_status)
      AND (p_shop_id IS NULL OR o.shop_id = p_shop_id)
      AND (p_shop_type IS NULL OR s.shop_type::text = p_shop_type)
      AND (p_profile_id IS NULL OR o.profile_id = p_profile_id)
      AND (
        p_search IS NULL
        OR o.order_no ILIKE ('%' || p_search || '%')
        OR o.name ILIKE ('%' || p_search || '%')
        OR s.name ILIKE ('%' || p_search || '%')
        OR cg.name ILIKE ('%' || p_search || '%')
        OR t.name ILIKE ('%' || p_search || '%')
      )
      AND (
        p_cursor_created_at IS NULL
        OR (o.created_at, o.id) < (p_cursor_created_at, p_cursor_id)
      )
    ORDER BY o.created_at DESC, o.id DESC
    LIMIT v_fetch
  ),
  page AS (
    SELECT * FROM base ORDER BY created_at DESC, id DESC LIMIT v_limit
  ),
  tail AS (
    SELECT created_at, id FROM page ORDER BY created_at ASC, id ASC LIMIT 1
  )
  SELECT
    coalesce(
      (SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at DESC, p.id DESC) FROM page p),
      '[]'::jsonb
    ),
    (SELECT count(*) > v_limit FROM base),
    CASE
      WHEN (SELECT count(*) FROM base) > v_limit THEN
        (SELECT jsonb_build_object('created_at', created_at, 'id', id) FROM tail)
      ELSE NULL
    END
  INTO v_orders, v_has_more, v_next_cursor;

  RETURN jsonb_build_object(
    'shops', v_shops,
    'orders', v_orders,
    'meta', jsonb_build_object(
      'limit', v_limit,
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    )
  );
END;
$function$;

GRANT ALL ON FUNCTION public.list_shop_orders_staff_page(bigint, bigint, integer, text, text, bigint, text, bigint, timestamp WITH time zone, bigint) TO anon;

GRANT ALL ON FUNCTION public.list_shop_orders_staff_page(bigint, bigint, integer, text, text, bigint, text, bigint, timestamp WITH time zone, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_shop_orders_staff_page(bigint, bigint, integer, text, text, bigint, text, bigint, timestamp WITH time zone, bigint) TO service_role;
CREATE OR REPLACE FUNCTION public.get_shop_order_for_staff (
  p_tenant_id bigint,
  p_order_id  bigint,
  p_items_limit integer DEFAULT NULL::integer,
  p_items_cursor_created_at timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_items_cursor_id bigint DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_shop_name text;
  v_sell_currency_id bigint;
  v_buy_currency_id bigint;
  v_sell_code text;
  v_sell_symbol text;
  v_buy_code text;
  v_buy_symbol text;
  v_customer_group_name text;
  v_item_count bigint;
  v_total_amount numeric;
  v_collection_source public.collection_source_type;
  v_items jsonb;
  v_items_limit integer;
  v_items_fetch integer;
  v_items_has_more boolean := false;
  v_items_next_cursor jsonb := null;
  v_invoices jsonb;
  v_shipments jsonb;
  v_order_json jsonb;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select *
  into v_order
  from public.shop_orders o
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  select
    s.name,
    s.sell_currency_id,
    s.buy_currency_id,
    sell_gc.code,
    sell_gc.symbol,
    buy_gc.code,
    buy_gc.symbol
  into
    v_shop_name,
    v_sell_currency_id,
    v_buy_currency_id,
    v_sell_code,
    v_sell_symbol,
    v_buy_code,
    v_buy_symbol
  from public.shops s
  left join public.global_currencies sell_gc on sell_gc.id = s.sell_currency_id
  left join public.global_currencies buy_gc on buy_gc.id = s.buy_currency_id
  where s.id = v_order.shop_id;

  select cg.name
  into v_customer_group_name
  from public.customer_groups cg
  where cg.id = v_order.customer_group_id;

  v_collection_source := v_order.collection_source;
  if v_collection_source is null and v_order.global_invoice_id is not null then
    select inv.collection_source
    into v_collection_source
    from public.bills inv
    where inv.id = v_order.global_invoice_id;
  end if;
  if v_collection_source is null and v_order.is_prepaid_snapshot then
    v_collection_source := 'profile'::public.collection_source_type;
  end if;

  select count(*)::bigint
  into v_item_count
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    sum(
      coalesce(
        soi.final_price_amount,
        soi.staff_offer_amount,
        soi.customer_offer_amount,
        soi.unit_sell_price_amount,
        soi.unit_list_price_amount
      ) * soi.quantity
    ),
    0
  )
  into v_total_amount
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  if v_order.global_invoice_id is not null then
    v_invoices := jsonb_build_array(jsonb_build_object('id', v_order.global_invoice_id));
  else
    v_invoices := '[]'::jsonb;
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object('id', x.shipment_id) order by x.shipment_id),
    '[]'::jsonb
  )
  into v_shipments
  from (
    select distinct gship.id as shipment_id
    from public.shop_order_items soi
    join public.global_stocks gs on gs.id = soi.global_stock_id
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    join public.global_shipments gship on gship.id = gsi.shipment_id
    where soi.order_id = v_order.id
  ) x;

  if p_items_limit is not null then
    v_items_limit := greatest(1, least(p_items_limit, 100));
    v_items_fetch := v_items_limit + 1;
  end if;

  with item_source as (
    select
      soi.created_at as item_created_at,
      soi.id as item_id,
      jsonb_build_object(
        'id', soi.id,
        'order_id', soi.order_id,
        'name', soi.name,
        'image_url', soi.image_url,
        'quantity', soi.quantity,
        'created_at', soi.created_at,
        'updated_at', soi.updated_at,
        'product', jsonb_build_object(
          'id', soi.product_id,
          'sku', p.product_code,
          'brand', p.brand,
          'barcode', p.barcode,
          'weight_gm', p.product_weight,
          'package_weight_gm', p.package_weight,
          'minimum_order_quantity', coalesce(p.minimum_order_quantity, 1)
        ),
        'pricing', jsonb_build_object(
          'cost', jsonb_build_object(
            'amount', coalesce(soi.cost_price_amount, soi.unit_list_price_amount, p.reference_cost_amount),
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = coalesce(
                soi.cost_price_currency_id,
                soi.unit_list_price_currency_id
              )
              limit 1
            )
          ),
          'list', jsonb_build_object(
            'amount', soi.unit_list_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.unit_list_price_currency_id
              limit 1
            )
          ),
          'sell', jsonb_build_object(
            'amount', soi.unit_sell_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.unit_sell_price_currency_id
              limit 1
            )
          ),
          'minimum_sell', jsonb_build_object(
            'amount', soi.unit_minimum_sell_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.unit_minimum_sell_price_currency_id
              limit 1
            )
          )
        ),
        'negotiation', jsonb_build_object(
          'status', soi.negotiation_status,
          'customer_decision', soi.customer_decision_status,
          'staff_offer', case
            when soi.staff_offer_amount is not null then jsonb_build_object(
              'amount', soi.staff_offer_amount,
              'currency', (
                select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
                from public.global_currencies gc
                where gc.id = soi.staff_offer_currency_id
                limit 1
              ),
              'at', soi.staff_offer_at,
              'is_manual', soi.is_first_offer_manual
            )
            else null
          end,
          'customer_offer', case
            when soi.customer_offer_amount is not null then jsonb_build_object(
              'amount', soi.customer_offer_amount,
              'currency', (
                select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
                from public.global_currencies gc
                where gc.id = soi.customer_offer_currency_id
                limit 1
              ),
              'at', soi.customer_counter_at
            )
            else null
          end,
          'final_offer', case
            when soi.final_price_amount is not null then jsonb_build_object(
              'amount', soi.final_price_amount,
              'currency', (
                select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
                from public.global_currencies gc
                where gc.id = soi.final_price_currency_id
                limit 1
              ),
              'at', soi.final_offer_at,
              'is_manual', soi.is_final_offer_manual
            )
            else null
          end,
          'weight_kg', soi.weight_kg,
          'confirmed_quantity', soi.confirmed_quantity
        ),
        'fulfillment', jsonb_build_object(
          'returned', soi.returned_quantity,
          'procurement_pulled', soi.procurement_pulled
        ),
        'stock', case
          when soi.global_stock_id is not null then jsonb_build_object(
            'global_stock_id', soi.global_stock_id,
            'global_stock_allocation_id', soi.global_stock_allocation_id,
            'shipment_item_id', gsi.id,
            'shipment_id', gship.id
          )
          else null
        end
      ) as item_json
    from public.shop_order_items soi
    left join public.products p on p.id = soi.product_id
    left join public.global_stocks gs on gs.id = soi.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments gship on gship.id = gsi.shipment_id
    where soi.order_id = v_order.id
      and (
        p_items_cursor_created_at is null
        or (soi.created_at, soi.id) > (p_items_cursor_created_at, p_items_cursor_id)
      )
    order by soi.created_at, soi.id
    limit case when v_items_fetch is not null then v_items_fetch end
  ),
  item_page as (
    select *
    from item_source
    order by item_created_at, item_id
    limit case when v_items_limit is not null then v_items_limit end
  ),
  item_tail as (
    select item_created_at, item_id
    from item_page
    order by item_created_at desc, item_id desc
    limit 1
  )
  select
    coalesce(
      (select jsonb_agg(ip.item_json order by ip.item_created_at, ip.item_id) from item_page ip),
      '[]'::jsonb
    ),
    case
      when v_items_limit is not null then (select count(*) > v_items_limit from item_source)
      else false
    end,
    case
      when v_items_limit is not null and (select count(*) from item_source) > v_items_limit then
        (select jsonb_build_object('created_at', item_created_at, 'id', item_id) from item_tail)
      else null
    end
  into v_items, v_items_has_more, v_items_next_cursor;

  v_order_json := jsonb_build_object(
    'id', v_order.id,
    'tenant_id', v_order.tenant_id,
    'order_no', v_order.order_no,
    'name', v_order.name,
    'cart_id', v_order.cart_id,
    'created_by_email', v_order.created_by_email,
    'placement_scope', v_order.placement_scope,
    'created_at', v_order.created_at,
    'updated_at', v_order.updated_at,
    'placed_at', v_order.placed_at,
    'fulfilled_at', v_order.fulfilled_at,
    'global_invoice_id', v_order.global_invoice_id,
    'collection_source', v_collection_source,
    'hidden_from_customer', v_order.hidden_from_customer,
    'catalog_manual_price_entry', v_order.catalog_manual_price_entry,
    'shop', jsonb_build_object(
      'id', v_order.shop_id,
      'name', v_shop_name,
      'type', v_order.shop_type_snapshot,
      'order_mode', v_order.order_mode_snapshot,
      'is_negotiable', v_order.is_negotiable_snapshot,
      'sell_currency', case
        when v_sell_currency_id is not null then jsonb_build_object(
          'id', v_sell_currency_id,
          'code', v_sell_code,
          'symbol', v_sell_symbol
        )
        else null
      end,
      'buy_currency', case
        when v_buy_currency_id is not null then jsonb_build_object(
          'id', v_buy_currency_id,
          'code', v_buy_code,
          'symbol', v_buy_symbol
        )
        else null
      end
    ),
    'customer', jsonb_build_object(
      'group_id', v_order.customer_group_id,
      'group_name', v_customer_group_name,
      'profile_id', v_order.profile_id
    ),
    'status', jsonb_build_object(
      'value', v_order.status,
      'negotiate_round', v_order.negotiate_round
    ),
    'rates', jsonb_build_object(
      'cargo', v_order.cargo_rate,
      'conversion', v_order.conversion_rate,
      'profit', v_order.profit_rate,
      'first_offer', v_order.first_offer_rate,
      'final_offer', v_order.final_offer_rate,
      'profit_basis', v_order.profit_basis,
      'package_weight_kg', v_order.package_weight_kg
    ),
    'recipient', jsonb_build_object(
      'name', v_order.recipient_name,
      'phone', v_order.recipient_phone,
      'phone_secondary', v_order.recipient_phone_secondary,
      'address', v_order.shipping_address,
      'district', v_order.shipping_district,
      'thana', v_order.shipping_thana,
      'profile_id', v_order.recipient_profile_id,
      'delivery_instructions', v_order.delivery_instructions,
      'is_prepaid', v_order.is_prepaid_snapshot
    ),
    'charges', jsonb_build_object(
      'cod', v_order.cod_charge_amount,
      'delivery', v_order.delivery_charge_amount,
      'print', v_order.print_charge_amount,
      'packing', v_order.packing_charge_amount,
      'discount', v_order.discount_amount,
      'deduct_from_margin', jsonb_build_object(
        'charges', v_order.deduct_charges_from_margin,
        'cod', v_order.deduct_cod_from_margin,
        'delivery', v_order.deduct_delivery_from_margin,
        'print', v_order.deduct_print_from_margin,
        'packing', v_order.deduct_packing_from_margin
      )
    ),
    'totals', jsonb_build_object(
      'item_count', v_item_count,
      'amount', v_total_amount,
      'currency', case
        when v_sell_currency_id is not null then jsonb_build_object(
          'id', v_sell_currency_id,
          'code', v_sell_code,
          'symbol', v_sell_symbol
        )
        else null
      end
    ),
    'courier', jsonb_build_object(
      'service_id', v_order.courier_service_id,
      'name', v_order.courier_name,
      'awb_number', v_order.courier_awb_number,
      'tracking_url', v_order.tracking_url,
      'order_ref', v_order.courier_order_ref,
      'tracking_number', v_order.courier_tracking_number,
      'consignment_id', v_order.courier_consignment_id,
      'cost_amount', v_order.courier_cost_amount,
      'delivered_at', v_order.delivered_at,
      'returned_at', v_order.returned_at
    ),
    'pickup', jsonb_build_object(
      'sender_name', v_order.sender_name,
      'phone', v_order.pickup_phone,
      'address', v_order.pickup_address,
      'default_sender_name', v_order.default_sender_name,
      'default_phone', v_order.default_pickup_phone,
      'default_address', v_order.default_pickup_address
    ),
    'payout', jsonb_build_object(
      'account_type', v_order.payout_account_type,
      'account_info', v_order.payout_account_info,
      'default_account_type', v_order.default_payout_account_type,
      'default_account_info', v_order.default_payout_account_info,
      'settlement_status', v_order.payout_settlement_status,
      'cod_collect_amount', v_order.cod_collect_amount,
      'courier_remittance_ref', v_order.courier_remittance_ref,
      'courier_bank_trx_id', v_order.courier_bank_trx_id
    ),
    'parcel', jsonb_build_object(
      'weight_band', v_order.package_weight_band,
      'item_category', v_order.item_category,
      'description', v_order.parcel_description,
      'delivery_zone', v_order.delivery_zone,
      'allow_open_box', v_order.allow_open_box,
      'driver_notes', v_order.driver_notes,
      'delivery_instruction_notes', v_order.delivery_instruction_notes
    ),
    'return_info', jsonb_build_object(
      'sub_state', v_order.return_sub_state,
      'override_reason', v_order.return_override_reason,
      'ref', v_order.return_ref,
      'charge_amount', v_order.return_charge_amount,
      'deduct_charge_from_middle_man', v_order.deduct_return_charge_from_middle_man,
      'replacement_of_order_id', v_order.replacement_of_order_id,
      'middle_man_reference', v_order.middle_man_reference
    ),
    'links', jsonb_build_object(
      'invoices', v_invoices,
      'shipments', v_shipments
    )
  );

  return jsonb_build_object(
    'order', v_order_json,
    'items', v_items,
    'items_meta', case
      when p_items_limit is not null then jsonb_build_object(
        'limit', v_items_limit,
        'has_more', v_items_has_more,
        'next_cursor', v_items_next_cursor
      )
      else null
    end
  );
end;
$function$;

GRANT ALL ON FUNCTION public.get_shop_order_for_staff(bigint, bigint, integer, timestamp with time zone, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_shop_order_for_staff(bigint, bigint, integer, timestamp with time zone, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_shop_order_for_staff(bigint, bigint, integer, timestamp with time zone, bigint) TO service_role;
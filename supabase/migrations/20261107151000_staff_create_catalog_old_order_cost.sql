-- Old-order create: optional cost_price_amount on lines
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
    coalesce(p_hidden_from_customer, true),
    v_is_old_order,
    CASE WHEN v_is_old_order THEN (p_rates->>'conversion_rate')::numeric ELSE NULL END,
    CASE WHEN v_is_old_order THEN (p_rates->>'cargo_rate')::numeric ELSE NULL END,
    CASE WHEN v_is_old_order THEN coalesce((p_rates->>'profit_rate')::numeric, (p_rates->>'first_offer_rate')::numeric) ELSE NULL END,
    CASE WHEN v_is_old_order THEN (p_rates->>'first_offer_rate')::numeric ELSE NULL END,
    CASE WHEN v_is_old_order THEN (p_rates->>'final_offer_rate')::numeric ELSE NULL END,
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

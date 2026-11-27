-- Snapshot pending resell discount requests on order lines at place order.

alter table public.shop_order_items
  add column if not exists requested_resell_discount_price_amount numeric(12, 4),
  add column if not exists requested_resell_discount_price_currency_id bigint references public.global_currencies (id),
  add column if not exists resell_discount_request_reason text,
  add column if not exists resell_discount_requested_at timestamptz;

update public.shop_order_items soi
set
  requested_resell_discount_price_amount = ci.requested_resell_discount_price_amount,
  requested_resell_discount_price_currency_id = ci.requested_resell_discount_price_currency_id,
  resell_discount_request_reason = ci.resell_discount_request_reason,
  resell_discount_requested_at = ci.resell_discount_requested_at
from public.shop_orders o
join public.shop_cart_items ci on ci.cart_id = o.cart_id
where soi.order_id = o.id
  and ci.product_id = soi.product_id
  and o.cart_id is not null
  and ci.requested_resell_discount_price_amount is not null
  and soi.requested_resell_discount_price_amount is null;

CREATE OR REPLACE FUNCTION "public"."staff_submit_dropship_order_from_cart"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text" DEFAULT NULL::"text", "p_shipping_district" "text" DEFAULT NULL::"text", "p_shipping_thana" "text" DEFAULT NULL::"text", "p_shipping_post_code" "text" DEFAULT NULL::"text", "p_profile_id" bigint DEFAULT NULL::bigint, "p_is_prepaid" boolean DEFAULT false, "p_delivery_instructions" "text" DEFAULT NULL::"text", "p_cod_charge_amount" numeric DEFAULT 0, "p_delivery_charge_amount" numeric DEFAULT 0, "p_print_charge_amount" numeric DEFAULT 0, "p_packing_charge_amount" numeric DEFAULT 0, "p_discount_amount" numeric DEFAULT 0, "p_recipient_pays_delivery" boolean DEFAULT true, "p_recipient_pays_cod" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shop public.shops%rowtype;
  v_cart public.shop_carts%rowtype;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_item_count integer;
  v_result jsonb;
  v_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci record;
  v_deduct_delivery_from_margin boolean;
  v_deduct_cod_from_margin boolean;
  v_order_item_id bigint;
  v_available_after integer;
  v_grade_tag_id bigint;
  v_listing_id bigint;
  v_billing_profile_warning boolean := false;
  v_order_tenant_id bigint;
BEGIN
  PERFORM public.assert_staff_can_place_dropship_order_on_behalf(p_shop_id, p_customer_group_id);

  SELECT * INTO v_shop FROM public.shops WHERE id = p_shop_id AND is_active = true;
  IF v_shop.id IS NULL THEN RAISE EXCEPTION 'shop not found or inactive'; END IF;
  IF v_shop.shop_type <> 'dropship' THEN RAISE EXCEPTION 'shop is not dropship'; END IF;

  SELECT * INTO v_cart
  FROM public.shop_carts c
  WHERE c.shop_id = p_shop_id
    AND c.customer_group_id = p_customer_group_id
    AND c.status = 'active'
  ORDER BY c.id DESC
  LIMIT 1;

  IF v_cart.id IS NULL THEN RAISE EXCEPTION 'active cart not found'; END IF;
  v_order_tenant_id := public.resolve_parent_tenant_id(v_cart.tenant_id);

  SELECT count(*) INTO v_item_count FROM public.shop_cart_items WHERE cart_id = v_cart.id;
  IF v_item_count = 0 THEN RAISE EXCEPTION 'cart is empty'; END IF;

  IF nullif(trim(coalesce(p_recipient_name, '')), '') IS NULL THEN RAISE EXCEPTION 'recipient name is required'; END IF;
  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  IF v_phone IS NULL THEN RAISE EXCEPTION 'recipient phone is required'; END IF;
  IF nullif(trim(coalesce(p_shipping_address, '')), '') IS NULL THEN RAISE EXCEPTION 'shipping address is required'; END IF;

  IF EXISTS (
    SELECT 1 FROM public.shop_cart_items ci
    WHERE ci.cart_id = v_cart.id
      AND coalesce(ci.unit_minimum_sell_price_amount, 0) > 0
      AND coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0) < ci.unit_minimum_sell_price_amount
  ) THEN
    RAISE EXCEPTION 'price floor violation: some items are priced below the minimum sell price';
  END IF;

  v_profile_id := p_profile_id;
  IF v_profile_id IS NULL THEN
    v_profile_id := public.resolve_customer_profile_for_group(v_cart.tenant_id, v_cart.customer_group_id);
  END IF;

  IF v_profile_id IS NULL THEN
    v_billing_profile_warning := true;
  END IF;

  IF v_shop.order_mode = 'checkout_fixed' THEN v_order_status := 'confirmed';
  ELSE v_order_status := 'submitted'; END IF;

  v_deduct_delivery_from_margin := NOT coalesce(p_recipient_pays_delivery, true);
  v_deduct_cod_from_margin := NOT coalesce(p_recipient_pays_cod, true);

  SELECT public.generate_shop_order_number(v_order_tenant_id, v_cart.shop_id) INTO v_order_no;

  v_profile := public.upsert_recipient_profile_and_address(
    p_tenant_id => v_cart.tenant_id, p_name => p_recipient_name, p_phone => v_phone,
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
    v_order_tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id, v_order_no,
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

  INSERT INTO public.shop_order_items (
    order_id, product_id, listing_id, grade_tag_id, global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    cost_price_amount, cost_price_currency_id, confirmed_quantity,
    requested_resell_discount_price_amount, requested_resell_discount_price_currency_id,
    resell_discount_request_reason, resell_discount_requested_at
  )
  SELECT
    v_order_id, ci.product_id, ci.listing_id,
    coalesce(ci.grade_tag_id, l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id()),
    NULL, NULL, ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    CASE WHEN v_order_status = 'confirmed' THEN coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount) ELSE NULL END,
    CASE WHEN v_order_status = 'confirmed' THEN coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id) ELSE NULL END,
    coalesce(ci.unit_list_price_amount, public.shop_product_grade_avg_landed_cost(
      v_cart.tenant_id, ci.product_id,
      coalesce(ci.grade_tag_id, l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id())
    )),
    v_shop.buy_currency_id, 0,
    ci.requested_resell_discount_price_amount,
    ci.requested_resell_discount_price_currency_id,
    ci.resell_discount_request_reason,
    ci.resell_discount_requested_at
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
      WHERE shop_id = v_shop.id AND product_id = v_ci.product_id AND global_stock_id = v_ci.global_stock_id
        AND display_quantity_override IS NOT NULL;
    END IF;

    SELECT soi.id INTO v_order_item_id FROM public.shop_order_items soi
    WHERE soi.order_id = v_order_id AND soi.product_id = v_ci.product_id
      AND soi.listing_id IS NOT DISTINCT FROM v_ci.listing_id ORDER BY soi.id ASC LIMIT 1;
    IF v_order_item_id IS NULL THEN
      SELECT soi.id INTO v_order_item_id FROM public.shop_order_items soi
      WHERE soi.order_id = v_order_id AND soi.product_id = v_ci.product_id ORDER BY soi.id ASC LIMIT 1;
    END IF;
    IF v_order_item_id IS NOT NULL THEN
      UPDATE public.shop_order_items
      SET listing_id = coalesce(listing_id, v_listing_id), grade_tag_id = coalesce(grade_tag_id, v_grade_tag_id)
      WHERE id = v_order_item_id;
    END IF;

    IF v_listing_id IS NOT NULL THEN
      v_available_after := public.shop_product_grade_available_units(v_cart.tenant_id, v_ci.product_id, v_grade_tag_id);
      IF coalesce((SELECT display_quantity_override FROM public.shop_product_listings WHERE id = v_listing_id), v_available_after, 0) <= 0 THEN
        UPDATE public.shop_product_listings SET is_active = false WHERE id = v_listing_id;
      END IF;
    ELSIF v_ci.global_stock_id IS NOT NULL THEN
      SELECT coalesce(sum(gs.quantity), 0) INTO v_available_after FROM public.global_stocks gs
      WHERE gs.shipment_item_id = (SELECT shipment_item_id FROM public.global_stocks WHERE id = v_ci.global_stock_id)
        AND gs.availability = 'sellable'::public.stock_availability;
      IF coalesce((SELECT display_quantity_override FROM public.shop_product_listings
        WHERE shop_id = v_shop.id AND product_id = v_ci.product_id AND global_stock_id = v_ci.global_stock_id),
        v_available_after, 0) <= 0 THEN
        UPDATE public.shop_product_listings SET is_active = false
        WHERE shop_id = v_shop.id AND product_id = v_ci.product_id AND global_stock_id = v_ci.global_stock_id;
      END IF;
    END IF;
  END LOOP;

  DELETE FROM public.shop_stock_reservations
  WHERE cart_item_id IN (SELECT id FROM public.shop_cart_items WHERE cart_id = v_cart.id);
  UPDATE public.shop_carts SET status = 'converted', updated_at = now() WHERE id = v_cart.id;

  PERFORM public.recompute_dropship_cod_collect_amount(v_order_id);

  SELECT jsonb_build_object(
    'order_id', v_order_id, 'order_no', v_order_no, 'status', v_order_status,
    'cart_id', v_cart.id, 'shop_id', v_shop.id,
    'billing_profile_warning', v_billing_profile_warning
  ) INTO v_result;
  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."staff_submit_dropship_order_from_cart"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text", "p_shipping_district" "text", "p_shipping_thana" "text", "p_shipping_post_code" "text", "p_profile_id" bigint, "p_is_prepaid" boolean, "p_delivery_instructions" "text", "p_cod_charge_amount" numeric, "p_delivery_charge_amount" numeric, "p_print_charge_amount" numeric, "p_packing_charge_amount" numeric, "p_discount_amount" numeric, "p_recipient_pays_delivery" boolean, "p_recipient_pays_cod" boolean) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."submit_dropship_order_from_cart"("p_shop_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text" DEFAULT NULL::"text", "p_shipping_district" "text" DEFAULT NULL::"text", "p_shipping_thana" "text" DEFAULT NULL::"text", "p_shipping_post_code" "text" DEFAULT NULL::"text", "p_profile_id" bigint DEFAULT NULL::bigint, "p_is_prepaid" boolean DEFAULT false, "p_delivery_instructions" "text" DEFAULT NULL::"text", "p_cod_charge_amount" numeric DEFAULT 0, "p_delivery_charge_amount" numeric DEFAULT 0, "p_print_charge_amount" numeric DEFAULT 0, "p_packing_charge_amount" numeric DEFAULT 0, "p_discount_amount" numeric DEFAULT 0, "p_recipient_pays_delivery" boolean DEFAULT true, "p_recipient_pays_cod" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop public.shops%rowtype;
  v_cart public.shop_carts%rowtype;
  v_customer_group_id bigint;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_can_place_order boolean;
  v_item_count integer;
  v_result jsonb;
  v_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci record;
  v_deduct_delivery_from_margin boolean;
  v_deduct_cod_from_margin boolean;
  v_order_item_id bigint;
  v_available_after integer;
  v_grade_tag_id bigint;
  v_listing_id bigint;
  v_order_tenant_id bigint;
begin
  select * into v_shop from public.shops where id = p_shop_id and is_active = true;
  if v_shop.id is null then raise exception 'shop not found or inactive'; end if;
  if v_shop.shop_type <> 'dropship' then raise exception 'shop is not dropship'; end if;
  if not public.can_customer_access_shop(p_shop_id) then raise exception 'access denied'; end if;

  select access.customer_group_id into v_customer_group_id
  from public.shop_customer_group_access access
  join public.customer_groups cg on cg.id = access.customer_group_id
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  where access.shop_id = p_shop_id and access.status = true and cg.is_active = true
    and cgm.is_active = true and lower(trim(cgm.email)) = public.current_user_email()
  order by access.created_at asc limit 1;

  if v_customer_group_id is null then raise exception 'no customer group access found'; end if;

  select * into v_cart from public.shop_carts c
  where c.shop_id = p_shop_id
    and c.customer_group_id = v_customer_group_id and c.status = 'active'
  order by c.id desc limit 1;

  if v_cart.id is null then raise exception 'active cart not found'; end if;
  v_order_tenant_id := public.resolve_parent_tenant_id(v_cart.tenant_id);
  if not public.is_cart_owner(v_cart.customer_group_id, v_cart.tenant_id) then raise exception 'access denied'; end if;

  select can_place_order into v_can_place_order from public.get_shop_permissions_for_customer(p_shop_id);
  if coalesce(v_can_place_order, false) is not true then raise exception 'checkout not allowed for this customer group'; end if;

  select count(*) into v_item_count from public.shop_cart_items where cart_id = v_cart.id;
  if v_item_count = 0 then raise exception 'cart is empty'; end if;

  if nullif(trim(coalesce(p_recipient_name, '')), '') is null then raise exception 'recipient name is required'; end if;
  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  if v_phone is null then raise exception 'recipient phone is required'; end if;
  if nullif(trim(coalesce(p_shipping_address, '')), '') is null then raise exception 'shipping address is required'; end if;

  if exists (
    select 1 from public.shop_cart_items ci
    where ci.cart_id = v_cart.id
      and coalesce(ci.unit_minimum_sell_price_amount, 0) > 0
      and coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0) < ci.unit_minimum_sell_price_amount
  ) then
    raise exception 'price floor violation: some items are priced below the minimum sell price';
  end if;

  v_profile_id := p_profile_id;
  if v_profile_id is null then
    v_profile_id := public.resolve_customer_profile_for_group(v_cart.tenant_id, v_cart.customer_group_id);
  end if;

  if v_shop.order_mode = 'checkout_fixed' then v_order_status := 'confirmed';
  else v_order_status := 'submitted'; end if;

  v_deduct_delivery_from_margin := not coalesce(p_recipient_pays_delivery, true);
  v_deduct_cod_from_margin := not coalesce(p_recipient_pays_cod, true);

  select public.generate_shop_order_number(v_order_tenant_id, v_cart.shop_id) into v_order_no;

  v_profile := public.upsert_recipient_profile_and_address(
    p_tenant_id => v_cart.tenant_id, p_name => p_recipient_name, p_phone => v_phone,
    p_phone_secondary => p_recipient_phone_secondary, p_address => p_shipping_address,
    p_district => p_shipping_district, p_thana => p_shipping_thana
  );
  v_recipient_profile_id := (v_profile->>'id')::bigint;

  insert into public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id, order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot, status, negotiate_round,
    recipient_name, recipient_phone, recipient_phone_secondary,
    shipping_address, shipping_district, shipping_thana,
    recipient_profile_id, profile_id, created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  ) values (
    v_order_tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id, v_order_no,
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
  ) returning id into v_order_id;

  insert into public.shop_order_items (
    order_id, product_id, listing_id, grade_tag_id, global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    cost_price_amount, cost_price_currency_id, confirmed_quantity,
    requested_resell_discount_price_amount, requested_resell_discount_price_currency_id,
    resell_discount_request_reason, resell_discount_requested_at
  )
  select
    v_order_id, ci.product_id, ci.listing_id,
    coalesce(ci.grade_tag_id, l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id()),
    null, null, ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    case when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount) else null end,
    case when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id) else null end,
    coalesce(ci.unit_list_price_amount, public.shop_product_grade_avg_landed_cost(
      v_cart.tenant_id, ci.product_id,
      coalesce(ci.grade_tag_id, l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id())
    )),
    v_shop.buy_currency_id, 0,
    ci.requested_resell_discount_price_amount,
    ci.requested_resell_discount_price_currency_id,
    ci.resell_discount_request_reason,
    ci.resell_discount_requested_at
  from public.shop_cart_items ci
  left join public.shop_product_listings l on l.id = ci.listing_id
  left join public.global_stocks gs on gs.id = ci.global_stock_id
  where ci.cart_id = v_cart.id;

  for v_ci in select * from public.shop_cart_items where cart_id = v_cart.id loop
    v_grade_tag_id := coalesce(
      v_ci.grade_tag_id,
      (select l.grade_tag_id from public.shop_product_listings l where l.id = v_ci.listing_id),
      (select gs.grade_tag_id from public.global_stocks gs where gs.id = v_ci.global_stock_id),
      public.default_stock_grade_tag_id()
    );
    v_listing_id := coalesce(
      v_ci.listing_id,
      (select l.id from public.shop_product_listings l where l.shop_id = v_shop.id and l.product_id = v_ci.product_id
        and coalesce(l.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id order by l.id asc limit 1),
      (select l.id from public.shop_product_listings l where l.shop_id = v_shop.id and l.product_id = v_ci.product_id
        and l.global_stock_id = v_ci.global_stock_id limit 1)
    );

    if v_listing_id is not null then
      update public.shop_product_listings
      set display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      where id = v_listing_id and display_quantity_override is not null;
    elsif v_ci.global_stock_id is not null then
      update public.shop_product_listings
      set display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      where shop_id = v_shop.id and product_id = v_ci.product_id and global_stock_id = v_ci.global_stock_id
        and display_quantity_override is not null;
    end if;

    select soi.id into v_order_item_id from public.shop_order_items soi
    where soi.order_id = v_order_id and soi.product_id = v_ci.product_id
      and soi.listing_id is not distinct from v_ci.listing_id order by soi.id asc limit 1;
    if v_order_item_id is null then
      select soi.id into v_order_item_id from public.shop_order_items soi
      where soi.order_id = v_order_id and soi.product_id = v_ci.product_id order by soi.id asc limit 1;
    end if;
    if v_order_item_id is not null then
      update public.shop_order_items
      set listing_id = coalesce(listing_id, v_listing_id), grade_tag_id = coalesce(grade_tag_id, v_grade_tag_id)
      where id = v_order_item_id;
    end if;

    if v_listing_id is not null then
      v_available_after := public.shop_product_grade_available_units(v_cart.tenant_id, v_ci.product_id, v_grade_tag_id);
      if coalesce((select display_quantity_override from public.shop_product_listings where id = v_listing_id), v_available_after, 0) <= 0 then
        update public.shop_product_listings set is_active = false where id = v_listing_id;
      end if;
    elsif v_ci.global_stock_id is not null then
      select coalesce(sum(gs.quantity), 0) into v_available_after from public.global_stocks gs
      where gs.shipment_item_id = (select shipment_item_id from public.global_stocks where id = v_ci.global_stock_id)
        and gs.availability = 'sellable'::public.stock_availability;
      if coalesce((select display_quantity_override from public.shop_product_listings
        where shop_id = v_shop.id and product_id = v_ci.product_id and global_stock_id = v_ci.global_stock_id),
        v_available_after, 0) <= 0 then
        update public.shop_product_listings set is_active = false
        where shop_id = v_shop.id and product_id = v_ci.product_id and global_stock_id = v_ci.global_stock_id;
      end if;
    end if;
  end loop;

  delete from public.shop_stock_reservations
  where cart_item_id in (select id from public.shop_cart_items where cart_id = v_cart.id);
  update public.shop_carts set status = 'converted', updated_at = now() where id = v_cart.id;

  perform public.recompute_dropship_cod_collect_amount(v_order_id);

  select jsonb_build_object(
    'order_id', v_order_id, 'order_no', v_order_no, 'status', v_order_status,
    'cart_id', v_cart.id, 'shop_id', v_shop.id
  ) into v_result;
  return v_result;
end;
$$;



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
        'requested_resell_discount_price_amount', soi.requested_resell_discount_price_amount,
        'requested_resell_discount_price_currency_id', soi.requested_resell_discount_price_currency_id,
        'resell_discount_request_reason', soi.resell_discount_request_reason,
        'resell_discount_requested_at', soi.resell_discount_requested_at,
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

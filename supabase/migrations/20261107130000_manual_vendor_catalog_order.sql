-- Manual vendor catalog orders: hidden_from_customer + staff create RPC

ALTER TABLE public.shop_orders
  ADD COLUMN IF NOT EXISTS hidden_from_customer boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.shop_orders.hidden_from_customer IS 'When true, order is omitted from customer storefront lists and detail (staff-recorded / backfill).';
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
    created_at             timestamp with time zone
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
    o.created_at
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
      'recipient_verified_at', v_order.recipient_verified_at
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
CREATE OR REPLACE FUNCTION public.assert_staff_can_place_catalog_order_on_behalf (
  p_shop_id           bigint,
  p_customer_group_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_shop public.shops%rowtype;
BEGIN
  SELECT * INTO v_shop
  FROM public.shops
  WHERE id = p_shop_id
    AND is_active = true
    AND deleted_at IS NULL;

  IF v_shop.id IS NULL THEN
    RAISE EXCEPTION 'shop not found or inactive';
  END IF;

  IF v_shop.shop_type <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'shop is not vendor catalog';
  END IF;

  IF NOT public.membership_has_module_action(v_shop.tenant_id, 'shop_order_mgmt', 'edit')
     AND NOT (
       v_shop.parent_tenant_id IS NOT NULL
       AND public.membership_has_module_action(v_shop.parent_tenant_id, 'shop_order_mgmt', 'edit')
     )
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.customer_groups cg
    WHERE cg.id = p_customer_group_id
      AND cg.is_active = true
      AND cg.deleted_at IS NULL
      AND coalesce(cg.parent_tenant_id, cg.tenant_id) = public.resolve_parent_tenant_id(v_shop.tenant_id)
  ) THEN
    RAISE EXCEPTION 'customer group not found';
  END IF;
END;
$function$;

GRANT ALL ON FUNCTION public.assert_staff_can_place_catalog_order_on_behalf(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.assert_staff_can_place_catalog_order_on_behalf(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.assert_staff_can_place_catalog_order_on_behalf(bigint, bigint) TO service_role;

CREATE OR REPLACE FUNCTION public.staff_create_vendor_catalog_order (
  p_shop_id                bigint,
  p_customer_group_id      bigint,
  p_items                  jsonb,
  p_order_name             text    DEFAULT NULL::text,
  p_profile_id             bigint  DEFAULT NULL::bigint,
  p_recorded_at            timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_hidden_from_customer   boolean DEFAULT true
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
  v_prod_name text;
  v_prod_image text;
  v_prod_price_amount numeric;
  v_prod_price_currency_id bigint;
  v_product_available_units integer;
  v_item_count integer;
  v_result jsonb;
  v_order_name text;
BEGIN
  PERFORM public.assert_staff_can_place_catalog_order_on_behalf(p_shop_id, p_customer_group_id);

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

  SELECT can_negotiate INTO v_can_negotiate
  FROM public.get_shop_permissions_for_customer_group(p_shop_id, p_customer_group_id)
  LIMIT 1;

  v_is_negotiable := coalesce(v_shop.is_negotiable, false) AND coalesce(v_can_negotiate, false);

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

    IF NOT public.shop_catalog_meets_min_available_units(v_shop.min_available_units, v_product_available_units) THEN
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
    v_ts,
    v_ts,
    v_ts
  )
  RETURNING id INTO v_order_id;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_elem->>'product_id')::bigint;
    v_qty := greatest(1, coalesce((v_elem->>'quantity')::int, 1));

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
      cost_price_currency_id
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
      NULL
    );
  END LOOP;

  SELECT count(*)::integer INTO v_item_count FROM public.shop_order_items WHERE order_id = v_order_id;

  PERFORM public.notify_catalog_shop_order(
    p_order_id := v_order_id,
    p_notify_staff := true,
    p_notify_customer := NOT coalesce(p_hidden_from_customer, true),
    p_event_type := 'catalog.order.created',
    p_title := format('New order %s', v_order_no),
    p_body := format('%s items to price', v_item_count)
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
  boolean
) TO anon;

GRANT ALL ON FUNCTION public.staff_create_vendor_catalog_order(
  bigint,
  bigint,
  jsonb,
  text,
  bigint,
  timestamp with time zone,
  boolean
) TO authenticated;

GRANT ALL ON FUNCTION public.staff_create_vendor_catalog_order(
  bigint,
  bigint,
  jsonb,
  text,
  bigint,
  timestamp with time zone,
  boolean
) TO service_role;

DROP FUNCTION IF EXISTS public.list_shop_orders_staff_page(
  bigint,
  integer,
  text,
  text,
  bigint,
  text,
  timestamp with time zone,
  bigint
);

CREATE OR REPLACE FUNCTION public.list_shop_orders_staff_page(
  p_tenant_id         bigint,
  p_limit             integer                  DEFAULT 30,
  p_search            text                     DEFAULT NULL::text,
  p_status            text                     DEFAULT NULL::text,
  p_shop_id           bigint                   DEFAULT NULL::bigint,
  p_shop_type         text                     DEFAULT NULL::text,
  p_profile_id        bigint                   DEFAULT NULL::bigint,
  p_cursor_created_at timestamp with time zone DEFAULT NULL::timestamp with time zone,
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
  v_shops jsonb := '[]'::jsonb;
  v_orders jsonb := '[]'::jsonb;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
BEGIN
  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

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
      (SELECT count(*)::bigint FROM public.shop_order_items WHERE order_id = o.id) AS item_count,
      coalesce(t.name, '')::text AS tenant_name
    FROM public.shop_orders o
    JOIN public.shops s ON s.id = o.shop_id
    JOIN public.customer_groups cg ON cg.id = o.customer_group_id
    LEFT JOIN public.tenants t ON t.id = o.tenant_id
    WHERE o.tenant_id = p_tenant_id
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

ALTER FUNCTION public.list_shop_orders_staff_page(
  bigint,
  integer,
  text,
  text,
  bigint,
  text,
  bigint,
  timestamp with time zone,
  bigint
) OWNER TO postgres;

GRANT ALL ON FUNCTION public.list_shop_orders_staff_page(
  bigint,
  integer,
  text,
  text,
  bigint,
  text,
  bigint,
  timestamp with time zone,
  bigint
) TO anon;

GRANT ALL ON FUNCTION public.list_shop_orders_staff_page(
  bigint,
  integer,
  text,
  text,
  bigint,
  text,
  bigint,
  timestamp with time zone,
  bigint
) TO authenticated;

GRANT ALL ON FUNCTION public.list_shop_orders_staff_page(
  bigint,
  integer,
  text,
  text,
  bigint,
  text,
  bigint,
  timestamp with time zone,
  bigint
) TO service_role;

-- Staff manual dropship order entry (US-9)

CREATE OR REPLACE FUNCTION public.assert_staff_can_place_dropship_order_on_behalf(
  p_shop_id bigint,
  p_customer_group_id bigint
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
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

  IF v_shop.shop_type <> 'dropship' THEN
    RAISE EXCEPTION 'shop is not dropship';
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
$$;

ALTER FUNCTION public.assert_staff_can_place_dropship_order_on_behalf(bigint, bigint) OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.get_shop_permissions_for_customer_group(
  p_shop_id bigint,
  p_customer_group_id bigint
) RETURNS TABLE(
  can_browse boolean,
  can_see_buy_price boolean,
  can_see_sell_price boolean,
  can_see_resell_minimum_price boolean,
  can_add_to_cart boolean,
  can_place_order boolean,
  can_negotiate boolean,
  can_view_quantity boolean,
  can_set_dropship_price boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_shop_active boolean;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_shop_allows_negotiate boolean;
BEGIN
  SELECT is_active, tenant_id, shop_type
  INTO v_shop_active, v_tenant_id, v_shop_type
  FROM public.shops
  WHERE id = p_shop_id;

  IF v_shop_active IS NOT true THEN
    RETURN QUERY SELECT false, false, false, false, false, false, false, false, false;
    RETURN;
  END IF;

  v_shop_allows_negotiate := v_shop_type = 'vendor_catalog';

  RETURN QUERY
  SELECT
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE coalesce(access.can_browse, profile.default_can_browse, true)
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE public.resolve_shop_can_see_buy_price(
          v_shop_type,
          access.can_see_buy_price,
          access.can_see_sell_price,
          profile.default_can_see_buy_price,
          profile.default_can_see_sell_price
        )
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE CASE
          WHEN v_shop_type = 'dropship' THEN true
          ELSE coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, true)
        END
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE coalesce(access.can_see_resell_minimum_price, profile.default_can_see_resell_minimum_price, true)
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE coalesce(access.can_add_to_cart, profile.default_can_add_to_cart, true)
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE coalesce(access.can_place_order, profile.default_can_place_order, true)
      END,
      true
    ),
    coalesce(
      (
        CASE
          WHEN access.id IS NOT NULL AND access.status = false THEN false
          WHEN coalesce(profile.is_active, true) = false THEN false
          ELSE coalesce(access.can_negotiate, profile.default_can_negotiate, false)
        END
      ) AND v_shop_allows_negotiate,
      false
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE coalesce(access.can_view_quantity, profile.default_can_view_quantity, true)
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE CASE
          WHEN v_shop_type = 'dropship' THEN true
          ELSE coalesce(access.can_set_dropship_price, profile.default_can_set_dropship_price, true)
        END
      END,
      true
    )
  FROM public.customer_groups cg
  LEFT JOIN public.shop_customer_group_access access
    ON access.customer_group_id = cg.id
   AND access.shop_id = p_shop_id
  LEFT JOIN public.customer_group_shop_profiles profile
    ON profile.customer_group_id = cg.id
   AND profile.operating_tenant_id = v_tenant_id
  WHERE cg.id = p_customer_group_id
    AND cg.is_active = true
    AND cg.deleted_at IS NULL
    AND coalesce(cg.parent_tenant_id, cg.tenant_id) = public.resolve_parent_tenant_id(v_tenant_id);
END;
$$;

ALTER FUNCTION public.get_shop_permissions_for_customer_group(bigint, bigint) OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.staff_shop_cart_response_json(p_cart_id bigint) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_result jsonb;
  v_perm record;
  v_can_see_buy_price_snapshot boolean;
  v_can_see_sell_price_snapshot boolean;
  v_shop_id bigint;
  v_customer_group_id bigint;
BEGIN
  SELECT c.shop_id, c.customer_group_id, c.can_see_buy_price_snapshot, c.can_see_sell_price_snapshot
  INTO v_shop_id, v_customer_group_id, v_can_see_buy_price_snapshot, v_can_see_sell_price_snapshot
  FROM public.shop_carts c
  WHERE c.id = p_cart_id;

  IF v_shop_id IS NULL THEN
    RAISE EXCEPTION 'cart not found';
  END IF;

  SELECT *
  INTO v_perm
  FROM public.get_shop_permissions_for_customer_group(v_shop_id, v_customer_group_id)
  LIMIT 1;

  SELECT jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'customer_group_id', c.customer_group_id,
      'can_see_buy_price_snapshot', v_can_see_buy_price_snapshot,
      'can_see_sell_price_snapshot', v_can_see_sell_price_snapshot,
      'status', c.status,
      'created_at', c.created_at,
      'updated_at', c.updated_at,
      'shop_type', s.shop_type,
      'allow_delivery', s.allow_delivery,
      'default_print_charge_amount', s.default_print_charge_amount,
      'default_packing_charge_amount', s.default_packing_charge_amount,
      'deduct_charges_from_margin', s.deduct_charges_from_margin,
      'deduct_print_from_margin', s.deduct_print_from_margin,
      'deduct_packing_from_margin', s.deduct_packing_from_margin
    ),
    'items', coalesce(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', ci.id,
            'cart_id', ci.cart_id,
            'product_id', ci.product_id,
            'listing_id', ci.listing_id,
            'grade_tag_id', ci.grade_tag_id,
            'global_stock_id', ci.global_stock_id,
            'global_stock_allocation_id', ci.global_stock_allocation_id,
            'quantity', ci.quantity,
            'minimum_quantity', ci.minimum_quantity,
            'minimum_order_quantity', p.minimum_order_quantity,
            'unit_list_price_amount', CASE WHEN v_can_see_buy_price_snapshot THEN ci.unit_list_price_amount ELSE NULL END,
            'unit_list_price_currency_id', CASE WHEN v_can_see_buy_price_snapshot THEN ci.unit_list_price_currency_id ELSE NULL END,
            'unit_sell_price_amount', CASE WHEN v_can_see_sell_price_snapshot THEN ci.unit_sell_price_amount ELSE NULL END,
            'unit_sell_price_currency_id', CASE WHEN v_can_see_sell_price_snapshot THEN ci.unit_sell_price_currency_id ELSE NULL END,
            'unit_minimum_sell_price_amount', CASE WHEN v_can_see_sell_price_snapshot THEN ci.unit_minimum_sell_price_amount ELSE NULL END,
            'unit_minimum_sell_price_currency_id', CASE WHEN v_can_see_sell_price_snapshot THEN ci.unit_minimum_sell_price_currency_id ELSE NULL END,
            'customer_sell_price_amount', CASE WHEN v_can_see_sell_price_snapshot THEN ci.customer_sell_price_amount ELSE NULL END,
            'customer_sell_price_currency_id', CASE WHEN v_can_see_sell_price_snapshot THEN ci.customer_sell_price_currency_id ELSE NULL END,
            'name', ci.name,
            'image_url', ci.image_url
          )
        )
        FROM public.shop_cart_items ci
        LEFT JOIN public.products p ON p.id = ci.product_id
        WHERE ci.cart_id = c.id
      ),
      '[]'::jsonb
    ),
    'permissions', jsonb_build_object(
      'can_browse', coalesce(v_perm.can_browse, false),
      'can_see_buy_price', coalesce(v_perm.can_see_buy_price, false),
      'can_see_sell_price', coalesce(v_perm.can_see_sell_price, false),
      'can_see_resell_minimum_price', coalesce(v_perm.can_see_resell_minimum_price, false),
      'can_add_to_cart', coalesce(v_perm.can_add_to_cart, false),
      'can_place_order', coalesce(v_perm.can_place_order, false),
      'can_negotiate', coalesce(v_perm.can_negotiate, false),
      'can_view_quantity', coalesce(v_perm.can_view_quantity, false),
      'can_set_dropship_price', coalesce(v_perm.can_set_dropship_price, false)
    ),
    'currency', CASE
      WHEN gc.id IS NOT NULL THEN jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
      ELSE NULL
    END
  )
  INTO v_result
  FROM public.shop_carts c
  JOIN public.shops s ON s.id = c.shop_id
  LEFT JOIN public.global_currencies gc ON gc.id = s.sell_currency_id
  WHERE c.id = p_cart_id;

  RETURN v_result;
END;
$$;

ALTER FUNCTION public.staff_shop_cart_response_json(bigint) OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.staff_get_or_create_shop_cart(
  p_shop_id bigint,
  p_customer_group_id bigint
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tenant_id bigint;
  v_can_see_buy_price_snapshot boolean;
  v_can_see_sell_price_snapshot boolean;
  v_cart_id bigint;
  v_perm record;
BEGIN
  PERFORM public.assert_staff_can_place_dropship_order_on_behalf(p_shop_id, p_customer_group_id);

  SELECT tenant_id INTO v_tenant_id
  FROM public.shops
  WHERE id = p_shop_id
    AND is_active = true;

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop not found or inactive';
  END IF;

  SELECT *
  INTO v_perm
  FROM public.get_shop_permissions_for_customer_group(p_shop_id, p_customer_group_id)
  LIMIT 1;

  v_can_see_buy_price_snapshot := coalesce(v_perm.can_see_buy_price, true);
  v_can_see_sell_price_snapshot := coalesce(v_perm.can_see_sell_price, true);

  SELECT id INTO v_cart_id
  FROM public.shop_carts
  WHERE tenant_id = v_tenant_id
    AND shop_id = p_shop_id
    AND customer_group_id = p_customer_group_id
    AND status = 'active'
  ORDER BY id DESC
  LIMIT 1;

  IF v_cart_id IS NULL THEN
    INSERT INTO public.shop_carts (
      tenant_id, shop_id, customer_group_id,
      can_see_buy_price_snapshot, can_see_sell_price_snapshot, status,
      deduct_charges_from_margin, deduct_print_from_margin, deduct_packing_from_margin
    )
    VALUES (
      v_tenant_id, p_shop_id, p_customer_group_id,
      v_can_see_buy_price_snapshot, v_can_see_sell_price_snapshot, 'active',
      (SELECT deduct_charges_from_margin FROM public.shops WHERE id = p_shop_id),
      (SELECT deduct_print_from_margin FROM public.shops WHERE id = p_shop_id),
      (SELECT deduct_packing_from_margin FROM public.shops WHERE id = p_shop_id)
    )
    RETURNING id INTO v_cart_id;
  ELSE
    UPDATE public.shop_carts
    SET
      deduct_charges_from_margin = (SELECT deduct_charges_from_margin FROM public.shops WHERE id = p_shop_id),
      deduct_print_from_margin = (SELECT deduct_print_from_margin FROM public.shops WHERE id = p_shop_id),
      deduct_packing_from_margin = (SELECT deduct_packing_from_margin FROM public.shops WHERE id = p_shop_id),
      can_see_buy_price_snapshot = v_can_see_buy_price_snapshot,
      can_see_sell_price_snapshot = v_can_see_sell_price_snapshot
    WHERE id = v_cart_id;
  END IF;

  RETURN public.staff_shop_cart_response_json(v_cart_id);
END;
$$;

ALTER FUNCTION public.staff_get_or_create_shop_cart(bigint, bigint) OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.staff_assert_dropship_cart_item_access(p_cart_item_id bigint)
RETURNS TABLE(shop_id bigint, customer_group_id bigint, tenant_id bigint, cart_id bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_shop_id bigint;
  v_customer_group_id bigint;
  v_tenant_id bigint;
  v_cart_id bigint;
BEGIN
  SELECT c.shop_id, c.customer_group_id, c.tenant_id, c.id
  INTO v_shop_id, v_customer_group_id, v_tenant_id, v_cart_id
  FROM public.shop_cart_items ci
  JOIN public.shop_carts c ON c.id = ci.cart_id
  WHERE ci.id = p_cart_item_id;

  IF v_cart_id IS NULL THEN
    RAISE EXCEPTION 'cart item not found';
  END IF;

  PERFORM public.assert_staff_can_place_dropship_order_on_behalf(v_shop_id, v_customer_group_id);

  shop_id := v_shop_id;
  customer_group_id := v_customer_group_id;
  tenant_id := v_tenant_id;
  cart_id := v_cart_id;
  RETURN NEXT;
END;
$$;

ALTER FUNCTION public.staff_assert_dropship_cart_item_access(bigint) OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.staff_add_to_shop_cart(
  p_shop_id bigint,
  p_customer_group_id bigint,
  p_product_id bigint,
  p_global_stock_allocation_id bigint DEFAULT NULL,
  p_quantity integer DEFAULT 1,
  p_customer_sell_price_amount numeric DEFAULT NULL,
  p_customer_sell_price_currency_id bigint DEFAULT NULL,
  p_global_stock_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
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
$$;

ALTER FUNCTION public.staff_add_to_shop_cart(bigint, bigint, bigint, bigint, integer, numeric, bigint, bigint) OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.staff_remove_shop_cart_item(p_cart_item_id bigint) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_ctx record;
BEGIN
  SELECT * INTO v_ctx FROM public.staff_assert_dropship_cart_item_access(p_cart_item_id);

  DELETE FROM public.shop_cart_items WHERE id = p_cart_item_id;

  RETURN public.staff_shop_cart_response_json(v_ctx.cart_id);
END;
$$;

ALTER FUNCTION public.staff_remove_shop_cart_item(bigint) OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.staff_update_shop_cart_item_price(p_cart_item_id bigint, p_price numeric) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_ctx record;
  v_customer_sell_price_currency_id bigint;
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
BEGIN
  SELECT * INTO v_ctx FROM public.staff_assert_dropship_cart_item_access(p_cart_item_id);

  SELECT ci.customer_sell_price_currency_id, ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id
  INTO v_customer_sell_price_currency_id, v_min_sell_price_amount, v_min_sell_price_currency_id
  FROM public.shop_cart_items ci
  WHERE ci.id = p_cart_item_id;

  IF p_price < 0 THEN
    RAISE EXCEPTION 'price cannot be negative';
  END IF;

  IF v_customer_sell_price_currency_id = v_min_sell_price_currency_id
     AND p_price < v_min_sell_price_amount THEN
    RAISE EXCEPTION 'price cannot be lower than the minimum sell price %', v_min_sell_price_amount;
  END IF;

  UPDATE public.shop_cart_items
  SET customer_sell_price_amount = p_price, updated_at = now()
  WHERE id = p_cart_item_id;

  RETURN public.staff_shop_cart_response_json(v_ctx.cart_id);
END;
$$;

ALTER FUNCTION public.staff_update_shop_cart_item_price(bigint, numeric) OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.staff_update_shop_cart_item_qty(p_cart_item_id bigint, p_quantity integer) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_ctx record;
  v_product_id bigint;
  v_global_stock_id bigint;
  v_available_to_sell integer;
BEGIN
  IF p_quantity <= 0 THEN
    RETURN public.staff_remove_shop_cart_item(p_cart_item_id);
  END IF;

  SELECT * INTO v_ctx FROM public.staff_assert_dropship_cart_item_access(p_cart_item_id);

  SELECT ci.product_id, ci.global_stock_id
  INTO v_product_id, v_global_stock_id
  FROM public.shop_cart_items ci
  WHERE ci.id = p_cart_item_id;

  v_available_to_sell := greatest(0, floor(public.global_stock_atp_qty(v_global_stock_id))::integer);

  IF p_quantity > v_available_to_sell THEN
    RAISE EXCEPTION 'insufficient stock: requested %, available %', p_quantity, v_available_to_sell;
  END IF;

  UPDATE public.shop_cart_items
  SET quantity = p_quantity, updated_at = now()
  WHERE id = p_cart_item_id;

  RETURN public.staff_shop_cart_response_json(v_ctx.cart_id);
END;
$$;

ALTER FUNCTION public.staff_update_shop_cart_item_qty(bigint, integer) OWNER TO postgres;


CREATE OR REPLACE FUNCTION public.staff_submit_dropship_order_from_cart(
  p_shop_id bigint,
  p_customer_group_id bigint,
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
BEGIN
  PERFORM public.assert_staff_can_place_dropship_order_on_behalf(p_shop_id, p_customer_group_id);

  SELECT * INTO v_shop FROM public.shops WHERE id = p_shop_id AND is_active = true;
  IF v_shop.id IS NULL THEN RAISE EXCEPTION 'shop not found or inactive'; END IF;
  IF v_shop.shop_type <> 'dropship' THEN RAISE EXCEPTION 'shop is not dropship'; END IF;

  SELECT * INTO v_cart
  FROM public.shop_carts c
  WHERE c.tenant_id = v_shop.tenant_id
    AND c.shop_id = p_shop_id
    AND c.customer_group_id = p_customer_group_id
    AND c.status = 'active'
  ORDER BY c.id DESC
  LIMIT 1;

  IF v_cart.id IS NULL THEN RAISE EXCEPTION 'active cart not found'; END IF;

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

  SELECT public.generate_shop_order_number(v_cart.tenant_id, v_cart.shop_id) INTO v_order_no;

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
    v_cart.tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id, v_order_no,
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
    cost_price_amount, cost_price_currency_id, confirmed_quantity
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
    v_shop.buy_currency_id, 0
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

ALTER FUNCTION public.staff_submit_dropship_order_from_cart(
  bigint, bigint, text, text, text, text, text, text, text, bigint, boolean, text,
  numeric, numeric, numeric, numeric, numeric, boolean, boolean
) OWNER TO postgres;


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
      SELECT (e->>'global_stock_id')::bigint AS gs_id, sum((e->>'quantity')::int) AS qty
      FROM jsonb_array_elements(p_items) AS e
      GROUP BY 1
    ) agg
    WHERE agg.qty > greatest(0, floor(public.global_stock_atp_qty(agg.gs_id))::integer)
  ) THEN
    RAISE EXCEPTION 'insufficient stock for one or more items';
  END IF;

  SELECT can_set_dropship_price INTO v_can_set_dropship_price
  FROM public.get_shop_permissions_for_customer_group(p_shop_id, p_customer_group_id)
  LIMIT 1;
  v_can_set_dropship_price := coalesce(v_can_set_dropship_price, true);

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_elem->>'product_id')::bigint;
    v_global_stock_id := (v_elem->>'global_stock_id')::bigint;
    v_qty := greatest(1, coalesce((v_elem->>'quantity')::int, 1));
    IF v_product_id IS NULL OR v_global_stock_id IS NULL THEN
      RAISE EXCEPTION 'each item requires product_id and global_stock_id';
    END IF;

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

    IF v_listing_id_new IS NULL THEN
      RAISE EXCEPTION 'active product listing not found on this shop';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.shop_listing_group_hides h
      WHERE h.listing_id = v_listing_id_new AND h.customer_group_id = p_customer_group_id
    ) THEN
      RAISE EXCEPTION 'product not available for this customer';
    END IF;

    IF v_can_set_dropship_price AND nullif(v_elem->>'customer_sell_price_amount', '') IS NOT NULL THEN
      v_customer_sell_price_amount := (v_elem->>'customer_sell_price_amount')::numeric;
      v_customer_sell_price_currency_id := coalesce((v_elem->>'customer_sell_price_currency_id')::bigint, v_sell_price_currency_id);
    ELSIF v_sell_price_currency_id = v_min_sell_price_currency_id THEN
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
    v_global_stock_id := (v_elem->>'global_stock_id')::bigint;
    v_qty := greatest(1, coalesce((v_elem->>'quantity')::int, 1));

    SELECT name, image_url INTO v_prod_name, v_prod_image FROM public.products WHERE id = v_product_id;

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

    SELECT coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gs.shipment_item_id))
    INTO v_landed_cost
    FROM public.global_stocks gs
    JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    WHERE gs.id = v_global_stock_id;

    IF v_can_set_dropship_price AND nullif(v_elem->>'customer_sell_price_amount', '') IS NOT NULL THEN
      v_customer_sell_price_amount := (v_elem->>'customer_sell_price_amount')::numeric;
      v_customer_sell_price_currency_id := coalesce((v_elem->>'customer_sell_price_currency_id')::bigint, v_sell_price_currency_id);
    ELSIF v_sell_price_currency_id = v_min_sell_price_currency_id THEN
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
      coalesce(
        (SELECT l.grade_tag_id FROM public.shop_product_listings l WHERE l.id = v_listing_id_new),
        (SELECT gs.grade_tag_id FROM public.global_stocks gs WHERE gs.id = v_global_stock_id),
        public.default_stock_grade_tag_id()
      ),
      v_global_stock_id, NULL, v_prod_name, v_prod_image, v_qty,
      coalesce(v_landed_cost, 0), v_shop.buy_currency_id,
      v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      CASE WHEN v_order_status = 'confirmed' THEN v_customer_sell_price_amount ELSE NULL END,
      CASE WHEN v_order_status = 'confirmed' THEN v_customer_sell_price_currency_id ELSE NULL END,
      coalesce(v_landed_cost, public.shop_product_grade_avg_landed_cost(
        v_shop.tenant_id, v_product_id,
        coalesce(
          (SELECT l.grade_tag_id FROM public.shop_product_listings l WHERE l.id = v_listing_id_new),
          (SELECT gs.grade_tag_id FROM public.global_stocks gs WHERE gs.id = v_global_stock_id),
          public.default_stock_grade_tag_id()
        )
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
    END IF;

    UPDATE public.shop_order_items
    SET listing_id = coalesce(listing_id, v_listing_id), grade_tag_id = coalesce(grade_tag_id, v_grade_tag_id)
    WHERE id = v_ci.id;

    IF v_listing_id IS NOT NULL THEN
      v_available_after := public.shop_product_grade_available_units(v_shop.tenant_id, v_ci.product_id, v_grade_tag_id);
      IF coalesce((SELECT display_quantity_override FROM public.shop_product_listings WHERE id = v_listing_id), v_available_after, 0) <= 0 THEN
        UPDATE public.shop_product_listings SET is_active = false WHERE id = v_listing_id;
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


CREATE OR REPLACE FUNCTION public.browse_dropship_listings_for_staff_order(
  p_tenant_id bigint,
  p_shop_id bigint,
  p_customer_group_id bigint,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 24
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_limit integer;
  v_search text;
  v_data jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_shop_id IS NULL OR p_customer_group_id IS NULL THEN
    RAISE EXCEPTION 'tenant, shop, and customer group are required';
  END IF;

  PERFORM public.assert_staff_can_place_dropship_order_on_behalf(p_shop_id, p_customer_group_id);

  v_limit := greatest(1, least(coalesce(p_limit, 24), 100));
  v_search := nullif(trim(coalesce(p_search, '')), '');

  SELECT coalesce(
    jsonb_agg(row_data ORDER BY row_data->>'product_name'),
    '[]'::jsonb
  )
  INTO v_data
  FROM (
    SELECT jsonb_build_object(
      'listing_id', l.id,
      'product_id', l.product_id,
      'global_stock_id', l.global_stock_id,
      'product_name', gsi.name,
      'product_image_url', gsi.image_url,
      'product_barcode', gsi.barcode,
      'sell_price_amount', l.sell_price_amount,
      'sell_price_currency_id', l.sell_price_currency_id,
      'minimum_sell_price_amount', l.minimum_sell_price_amount,
      'minimum_sell_price_currency_id', l.minimum_sell_price_currency_id,
      'available_to_sell', greatest(0, floor(public.global_stock_atp_qty(l.global_stock_id))::integer)
    ) AS row_data
    FROM public.shop_product_listings l
    JOIN public.shops s ON s.id = l.shop_id
    LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
    LEFT JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    WHERE l.shop_id = p_shop_id
      AND (s.tenant_id = p_tenant_id OR s.parent_tenant_id = p_tenant_id)
      AND s.shop_type = 'dropship'
      AND l.is_active = true
      AND NOT EXISTS (
        SELECT 1 FROM public.shop_listing_group_hides h
        WHERE h.listing_id = l.id AND h.customer_group_id = p_customer_group_id
      )
      AND (
        v_search IS NULL
        OR gsi.name ILIKE '%' || v_search || '%'
        OR gsi.barcode ILIKE '%' || v_search || '%'
        OR gsi.product_code ILIKE '%' || v_search || '%'
      )
    ORDER BY gsi.name ASC
    LIMIT v_limit
  ) sub;

  RETURN jsonb_build_object('data', coalesce(v_data, '[]'::jsonb), 'limit', v_limit);
END;
$$;

ALTER FUNCTION public.browse_dropship_listings_for_staff_order(bigint, bigint, bigint, text, integer) OWNER TO postgres;

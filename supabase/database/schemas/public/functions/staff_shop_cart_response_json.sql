CREATE FUNCTION public.staff_shop_cart_response_json (
  p_cart_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.staff_shop_cart_response_json(bigint) TO anon;

GRANT ALL ON FUNCTION public.staff_shop_cart_response_json(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.staff_shop_cart_response_json(bigint) TO service_role;
CREATE FUNCTION public.update_shop_cart_item_qty (
  p_cart_item_id bigint,
  p_quantity     integer
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_cart_id bigint;
  v_shop_id bigint;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_product_id bigint;
  v_listing_id bigint;
  v_grade_tag_id bigint;
  v_display_qty_override integer;
  v_available_to_sell integer;
BEGIN
  IF p_quantity <= 0 THEN
    RETURN public.remove_shop_cart_item(p_cart_item_id);
  END IF;

  SELECT ci.cart_id, ci.product_id, ci.listing_id, ci.grade_tag_id,
         c.shop_id, c.tenant_id, s.shop_type
  INTO v_cart_id, v_product_id, v_listing_id, v_grade_tag_id,
       v_shop_id, v_tenant_id, v_shop_type
  FROM public.shop_cart_items ci
  JOIN public.shop_carts c ON c.id = ci.cart_id
  JOIN public.shops s ON s.id = c.shop_id
  WHERE ci.id = p_cart_item_id;

  IF v_cart_id IS NULL THEN
    RAISE EXCEPTION 'cart item not found';
  END IF;

  IF NOT public.is_cart_owner(
    (SELECT customer_group_id FROM public.shop_carts WHERE id = v_cart_id),
    v_tenant_id
  ) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF v_shop_type IN ('fixed_price', 'dropship') AND v_grade_tag_id IS NOT NULL THEN
    SELECT l.display_quantity_override
    INTO v_display_qty_override
    FROM public.shop_product_listings l
    WHERE l.id = coalesce(v_listing_id, -1);

    v_available_to_sell := public.shop_product_grade_available_units(
      v_tenant_id, v_product_id, v_grade_tag_id
    );
    IF v_display_qty_override IS NOT NULL THEN
      v_available_to_sell := v_display_qty_override;
    END IF;

    IF p_quantity > v_available_to_sell THEN
      RAISE EXCEPTION 'insufficient stock: requested %, available %',
        p_quantity, greatest(0, v_available_to_sell);
    END IF;
  END IF;

  UPDATE public.shop_cart_items
  SET quantity = p_quantity, updated_at = now()
  WHERE id = p_cart_item_id;

  RETURN public.get_or_create_shop_cart(v_shop_id);
END;
$function$;

GRANT ALL ON FUNCTION public.update_shop_cart_item_qty(bigint, integer) TO anon;

GRANT ALL ON FUNCTION public.update_shop_cart_item_qty(bigint, integer) TO authenticated;

GRANT ALL ON FUNCTION public.update_shop_cart_item_qty(bigint, integer) TO service_role;
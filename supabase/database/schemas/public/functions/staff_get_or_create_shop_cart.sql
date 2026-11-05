CREATE FUNCTION public.staff_get_or_create_shop_cart (
  p_shop_id           bigint,
  p_customer_group_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.staff_get_or_create_shop_cart(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.staff_get_or_create_shop_cart(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.staff_get_or_create_shop_cart(bigint, bigint) TO service_role;
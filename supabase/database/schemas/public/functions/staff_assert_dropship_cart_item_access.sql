CREATE FUNCTION public.staff_assert_dropship_cart_item_access (
  p_cart_item_id bigint
)
  RETURNS TABLE (
    shop_id           bigint,
    customer_group_id bigint,
    tenant_id         bigint,
    cart_id           bigint
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.staff_assert_dropship_cart_item_access(bigint) TO anon;

GRANT ALL ON FUNCTION public.staff_assert_dropship_cart_item_access(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.staff_assert_dropship_cart_item_access(bigint) TO service_role;
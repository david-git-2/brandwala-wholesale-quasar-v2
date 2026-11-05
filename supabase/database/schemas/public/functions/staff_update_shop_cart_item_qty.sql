CREATE FUNCTION public.staff_update_shop_cart_item_qty (
  p_cart_item_id bigint,
  p_quantity     integer
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.staff_update_shop_cart_item_qty(bigint, integer) TO anon;

GRANT ALL ON FUNCTION public.staff_update_shop_cart_item_qty(bigint, integer) TO authenticated;

GRANT ALL ON FUNCTION public.staff_update_shop_cart_item_qty(bigint, integer) TO service_role;
CREATE FUNCTION public.staff_update_shop_cart_item_price (
  p_cart_item_id bigint,
  p_price        numeric
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.staff_update_shop_cart_item_price(bigint, numeric) TO anon;

GRANT ALL ON FUNCTION public.staff_update_shop_cart_item_price(bigint, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.staff_update_shop_cart_item_price(bigint, numeric) TO service_role;
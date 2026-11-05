CREATE FUNCTION public.shop_order_item_delivery_sell_price (
  p_is_negotiable_snapshot boolean,
  p_staff_offer_amount     numeric,
  p_final_price_amount     numeric
)
  RETURNS numeric
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  SELECT CASE
    WHEN coalesce(p_is_negotiable_snapshot, false) THEN
      coalesce(p_final_price_amount, p_staff_offer_amount, 0)::numeric(12, 2)
    ELSE
      coalesce(p_staff_offer_amount, 0)::numeric(12, 2)
  END;
$function$;

GRANT ALL ON FUNCTION public.shop_order_item_delivery_sell_price(boolean, numeric, numeric) TO anon;

GRANT ALL ON FUNCTION public.shop_order_item_delivery_sell_price(boolean, numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.shop_order_item_delivery_sell_price(boolean, numeric, numeric) TO service_role;
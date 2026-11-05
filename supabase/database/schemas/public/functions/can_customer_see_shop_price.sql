CREATE FUNCTION public.can_customer_see_shop_price (
  p_shop_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select coalesce((select can_see_buy_price from public.get_shop_permissions_for_customer(p_shop_id)), false);
$function$;

GRANT ALL ON FUNCTION public.can_customer_see_shop_price(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_customer_see_shop_price(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_customer_see_shop_price(bigint) TO service_role;
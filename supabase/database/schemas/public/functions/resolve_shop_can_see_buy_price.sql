CREATE FUNCTION public.resolve_shop_can_see_buy_price (
  p_shop_type                          public.shop_type_enum,
  p_access_can_see_buy_price           boolean,
  p_access_can_see_sell_price          boolean,
  p_profile_default_can_see_buy_price  boolean,
  p_profile_default_can_see_sell_price boolean
)
  RETURNS boolean
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  select case
    when p_shop_type = 'dropship'::public.shop_type_enum then true
    when p_shop_type = 'vendor_catalog'::public.shop_type_enum then
      coalesce(p_access_can_see_buy_price, p_profile_default_can_see_buy_price, false)
    else
      coalesce(p_access_can_see_buy_price, p_profile_default_can_see_buy_price, false)
  end;
$function$;

GRANT ALL ON FUNCTION public.resolve_shop_can_see_buy_price(public.shop_type_enum, boolean, boolean, boolean, boolean) TO anon;

GRANT ALL ON FUNCTION public.resolve_shop_can_see_buy_price(public.shop_type_enum, boolean, boolean, boolean, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.resolve_shop_can_see_buy_price(public.shop_type_enum, boolean, boolean, boolean, boolean) TO service_role;
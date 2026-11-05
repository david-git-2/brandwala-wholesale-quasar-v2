CREATE FUNCTION public.can_customer_access_shop (
  p_shop_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select coalesce((select can_browse from public.get_shop_permissions_for_customer(p_shop_id)), false);
$function$;

GRANT ALL ON FUNCTION public.can_customer_access_shop(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_customer_access_shop(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_customer_access_shop(bigint) TO service_role;
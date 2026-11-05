CREATE FUNCTION public.normalize_shop_order_procurement_status (
  p_status public.shop_order_status
)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  SELECT CASE
    WHEN p_status = 'ordered'::public.shop_order_status THEN 'dispatch'
    WHEN p_status = 'packed'::public.shop_order_status THEN 'dispatch'
    ELSE p_status::text
  END;
$function$;

GRANT ALL ON FUNCTION public.normalize_shop_order_procurement_status(public.shop_order_status) TO anon;

GRANT ALL ON FUNCTION public.normalize_shop_order_procurement_status(public.shop_order_status) TO authenticated;

GRANT ALL ON FUNCTION public.normalize_shop_order_procurement_status(public.shop_order_status) TO service_role;
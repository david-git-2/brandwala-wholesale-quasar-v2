CREATE FUNCTION public.global_shipment_stock_is_posted (
  p_ship public.global_shipments
)
  RETURNS boolean
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  SELECT coalesce(p_ship.stock_ready, false) OR p_ship.status = 'received';
$function$;

GRANT ALL ON FUNCTION public.global_shipment_stock_is_posted(public.global_shipments) TO anon;

GRANT ALL ON FUNCTION public.global_shipment_stock_is_posted(public.global_shipments) TO authenticated;

GRANT ALL ON FUNCTION public.global_shipment_stock_is_posted(public.global_shipments) TO service_role;
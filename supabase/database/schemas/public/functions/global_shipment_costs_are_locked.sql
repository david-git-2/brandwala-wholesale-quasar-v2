CREATE FUNCTION public.global_shipment_costs_are_locked (
  p_ship public.global_shipments
)
  RETURNS boolean
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  SELECT coalesce(p_ship.costs_locked, false);
$function$;

GRANT ALL ON FUNCTION public.global_shipment_costs_are_locked(public.global_shipments) TO anon;

GRANT ALL ON FUNCTION public.global_shipment_costs_are_locked(public.global_shipments) TO authenticated;

GRANT ALL ON FUNCTION public.global_shipment_costs_are_locked(public.global_shipments) TO service_role;
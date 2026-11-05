CREATE FUNCTION public.default_pickable_stock_location_id (
  p_tenant_id bigint
)
  RETURNS bigint
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select public.default_putaway_stock_location_id(p_tenant_id);
$function$;

GRANT ALL ON FUNCTION public.default_pickable_stock_location_id(bigint) TO anon;

GRANT ALL ON FUNCTION public.default_pickable_stock_location_id(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.default_pickable_stock_location_id(bigint) TO service_role;
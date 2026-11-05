CREATE FUNCTION public.shop_catalog_meets_min_available_units (
  p_min_available_units     integer,
  p_product_available_units integer
)
  RETURNS boolean
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  select coalesce(p_min_available_units, 0) = 0
    or coalesce(p_product_available_units, 0) >= p_min_available_units;
$function$;

GRANT ALL ON FUNCTION public.shop_catalog_meets_min_available_units(integer, integer) TO anon;

GRANT ALL ON FUNCTION public.shop_catalog_meets_min_available_units(integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.shop_catalog_meets_min_available_units(integer, integer) TO service_role;
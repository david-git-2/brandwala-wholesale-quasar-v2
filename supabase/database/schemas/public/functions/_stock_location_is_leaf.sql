CREATE FUNCTION public._stock_location_is_leaf (
  p_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select not exists (
    select 1 from public.stock_locations c
    where c.parent_location_id = p_id
      and c.is_active = true
  );
$function$;

GRANT ALL ON FUNCTION public._stock_location_is_leaf(bigint) TO anon;

GRANT ALL ON FUNCTION public._stock_location_is_leaf(bigint) TO authenticated;

GRANT ALL ON FUNCTION public._stock_location_is_leaf(bigint) TO service_role;
CREATE FUNCTION public.list_units_of_measure()
  RETURNS TABLE (
    code       text,
    name       text,
    unit_type  text,
    symbol     text,
    sort_order integer
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select u.code, u.name, u.unit_type, u.symbol, u.sort_order
  from public.units_of_measure u
  where u.is_active = true
  order by u.sort_order asc, u.name asc;
$function$;

GRANT ALL ON FUNCTION public.list_units_of_measure() TO anon;

GRANT ALL ON FUNCTION public.list_units_of_measure() TO authenticated;

GRANT ALL ON FUNCTION public.list_units_of_measure() TO service_role;
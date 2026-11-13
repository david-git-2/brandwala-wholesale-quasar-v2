CREATE FUNCTION public.list_global_currencies()
  RETURNS TABLE (
    id          bigint,
    name        text,
    country     text,
    code        text,
    symbol      text,
    minor_units smallint
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select gc.id, gc.name, gc.country, gc.code, gc.symbol, gc.minor_units
  from public.global_currencies gc
  where gc.is_active = true
  order by gc.code asc;
$function$;

GRANT ALL ON FUNCTION public.list_global_currencies() TO anon;

GRANT ALL ON FUNCTION public.list_global_currencies() TO authenticated;

GRANT ALL ON FUNCTION public.list_global_currencies() TO service_role;
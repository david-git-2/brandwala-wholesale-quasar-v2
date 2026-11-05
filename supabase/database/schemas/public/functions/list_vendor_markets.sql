CREATE FUNCTION public.list_vendor_markets()
  RETURNS TABLE (
    code   text,
    name   text,
    region text
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select m.code, m.name, m.region
  from public.markets m
  where m.is_active = true
  order by m.name asc;
$function$;

GRANT ALL ON FUNCTION public.list_vendor_markets() TO anon;

GRANT ALL ON FUNCTION public.list_vendor_markets() TO authenticated;

GRANT ALL ON FUNCTION public.list_vendor_markets() TO service_role;
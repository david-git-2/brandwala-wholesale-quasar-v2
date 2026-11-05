CREATE FUNCTION public.list_payment_methods()
  RETURNS TABLE (
    code       text,
    name       text,
    category   text,
    scope      text,
    sort_order integer
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select pm.code, pm.name, pm.category, pm.scope, pm.sort_order
  from public.payment_methods pm
  where pm.is_active = true
  order by pm.sort_order asc, pm.name asc;
$function$;

GRANT ALL ON FUNCTION public.list_payment_methods() TO anon;

GRANT ALL ON FUNCTION public.list_payment_methods() TO authenticated;

GRANT ALL ON FUNCTION public.list_payment_methods() TO service_role;
CREATE FUNCTION public.check_store_access (
  p_store_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select public.can_customer_access_store(p_store_id)
$function$;

GRANT ALL ON FUNCTION public.check_store_access(bigint) TO anon;

GRANT ALL ON FUNCTION public.check_store_access(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.check_store_access(bigint) TO service_role;
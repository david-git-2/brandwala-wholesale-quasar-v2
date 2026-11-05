CREATE FUNCTION public.current_tenant_id()
  RETURNS bigint
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select nullif(current_setting('request.headers', true)::json->>'x-selected-tenant-id', '')::bigint
$function$;

GRANT ALL ON FUNCTION public.current_tenant_id() TO anon;

GRANT ALL ON FUNCTION public.current_tenant_id() TO authenticated;

GRANT ALL ON FUNCTION public.current_tenant_id() TO service_role;
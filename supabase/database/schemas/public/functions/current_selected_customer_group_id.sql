CREATE FUNCTION public.current_selected_customer_group_id()
  RETURNS bigint
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select nullif(current_setting('request.headers', true)::json->>'x-selected-customer-group-id', '')::bigint
$function$;

GRANT ALL ON FUNCTION public.current_selected_customer_group_id() TO anon;

GRANT ALL ON FUNCTION public.current_selected_customer_group_id() TO authenticated;

GRANT ALL ON FUNCTION public.current_selected_customer_group_id() TO service_role;
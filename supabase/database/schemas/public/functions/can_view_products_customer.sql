CREATE FUNCTION public.can_view_products_customer (
  p_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select public.current_customer_group_id(p_tenant_id) is not null;
$function$;

GRANT ALL ON FUNCTION public.can_view_products_customer(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_view_products_customer(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_view_products_customer(bigint) TO service_role;
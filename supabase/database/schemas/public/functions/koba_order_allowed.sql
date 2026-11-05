CREATE FUNCTION public.koba_order_allowed (
  p_order_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.koba_orders o
    where o.id = p_order_id
      and public.koba_context_access_allowed(o.tenant_id, o.customer_group_id)
  );
$function$;

GRANT ALL ON FUNCTION public.koba_order_allowed(bigint) TO anon;

GRANT ALL ON FUNCTION public.koba_order_allowed(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.koba_order_allowed(bigint) TO service_role;
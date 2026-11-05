CREATE FUNCTION public.koba_cart_allowed (
  p_cart_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.koba_carts c
    where c.id = p_cart_id
      and public.koba_context_access_allowed(c.tenant_id, c.customer_group_id)
  );
$function$;

GRANT ALL ON FUNCTION public.koba_cart_allowed(bigint) TO anon;

GRANT ALL ON FUNCTION public.koba_cart_allowed(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.koba_cart_allowed(bigint) TO service_role;
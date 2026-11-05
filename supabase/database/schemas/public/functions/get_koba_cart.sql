CREATE FUNCTION public.get_koba_cart (
  p_tenant_id         bigint,
  p_customer_group_id bigint DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select jsonb_build_object(
    'cart',
    to_jsonb(c),
    'items',
    coalesce(
      (
        select jsonb_agg(to_jsonb(ci) order by ci.id)
        from public.koba_cart_items ci
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    )
  )
  from public.koba_carts c
  where c.tenant_id = p_tenant_id
    and c.customer_group_id is not distinct from p_customer_group_id
  limit 1;
$function$;

GRANT ALL ON FUNCTION public.get_koba_cart(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_koba_cart(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_koba_cart(bigint, bigint) TO service_role;
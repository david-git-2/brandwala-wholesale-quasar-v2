CREATE FUNCTION public.can_act_on_stock_movement_context (
  p_parent_tenant_id bigint,
  p_reference_type   text   DEFAULT NULL::text,
  p_reference_id     text   DEFAULT NULL::text
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    public.can_act_on_parent_tenant_stock(p_parent_tenant_id)
    or (
      coalesce(p_reference_type, '') = 'shop_order'
      and p_reference_id ~ '^[0-9]+$'
      and exists (
        select 1
        from public.shop_orders o
        join public.shops s on s.id = o.shop_id
        where o.id = p_reference_id::bigint
          and public.resolve_parent_tenant_id(coalesce(s.tenant_id, o.tenant_id)) = p_parent_tenant_id
          and (
            public.is_cart_owner(o.customer_group_id, o.tenant_id)
            or public.has_active_tenant_membership(o.tenant_id)
            or public.has_active_tenant_membership(public.resolve_parent_tenant_id(o.tenant_id))
            or public.is_superadmin()
          )
      )
    );
$function$;

GRANT ALL ON FUNCTION public.can_act_on_stock_movement_context(bigint, text, text) TO anon;

GRANT ALL ON FUNCTION public.can_act_on_stock_movement_context(bigint, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.can_act_on_stock_movement_context(bigint, text, text) TO service_role;
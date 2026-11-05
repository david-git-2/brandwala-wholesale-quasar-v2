CREATE FUNCTION public.shop_shipment_alloc_visible_to_tenant (
  p_assigned_child_tenant_id bigint,
  p_shop_tenant_id           bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SET search_path TO 'public'
  AS $function$
  SELECT
    p_shop_tenant_id = public.resolve_parent_tenant_id(p_shop_tenant_id)
    OR p_assigned_child_tenant_id IS NULL
    OR p_assigned_child_tenant_id = p_shop_tenant_id;
$function$;

GRANT ALL ON FUNCTION public.shop_shipment_alloc_visible_to_tenant(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.shop_shipment_alloc_visible_to_tenant(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.shop_shipment_alloc_visible_to_tenant(bigint, bigint) TO service_role;
CREATE FUNCTION public.shop_product_grade_available_units (
  p_shop_tenant_id bigint,
  p_product_id     bigint,
  p_grade_tag_id   bigint DEFAULT NULL::bigint
)
  RETURNS integer
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  SELECT coalesce(
    sum(greatest(0, floor(public.global_stock_atp_qty(gs.id))))::integer,
    0
  )
  FROM public.global_stocks gs
  JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
  LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
  WHERE gsi.product_id = p_product_id
    AND coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id())
      = coalesce(p_grade_tag_id, public.default_stock_grade_tag_id())
    AND gs.parent_tenant_id = public.resolve_parent_tenant_id(p_shop_tenant_id)
    AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, p_shop_tenant_id)
    AND gship.status = 'received'
    AND gs.availability = 'sellable'::public.stock_availability
    AND (gs.location_id IS NULL OR sl.is_pickable = true);
$function$;

GRANT ALL ON FUNCTION public.shop_product_grade_available_units(bigint, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.shop_product_grade_available_units(bigint, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.shop_product_grade_available_units(bigint, bigint, bigint) TO service_role;
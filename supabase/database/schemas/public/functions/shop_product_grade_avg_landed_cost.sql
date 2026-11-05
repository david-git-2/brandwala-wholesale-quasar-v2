CREATE FUNCTION public.shop_product_grade_avg_landed_cost (
  p_shop_tenant_id bigint,
  p_product_id     bigint,
  p_grade_tag_id   bigint
)
  RETURNS numeric
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  SELECT coalesce(
    avg(coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))),
    0
  )::numeric
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
    AND (gs.location_id IS NULL OR sl.is_pickable = TRUE);
$function$;

GRANT ALL ON FUNCTION public.shop_product_grade_avg_landed_cost(bigint, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.shop_product_grade_avg_landed_cost(bigint, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.shop_product_grade_avg_landed_cost(bigint, bigint, bigint) TO service_role;
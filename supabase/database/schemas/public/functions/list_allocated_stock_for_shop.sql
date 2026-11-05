CREATE FUNCTION public.list_allocated_stock_for_shop (
  p_shop_id bigint,
  p_search  text    DEFAULT NULL::text,
  p_limit   integer DEFAULT 200,
  p_offset  integer DEFAULT 0
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_shop_tenant_id bigint;
  v_total_count bigint;
  v_data jsonb;
  v_limit integer;
  v_offset integer;
BEGIN
  SELECT s.tenant_id INTO v_shop_tenant_id
  FROM public.shops s
  WHERE s.id = p_shop_id
    AND s.deleted_at IS NULL;

  IF v_shop_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop not found';
  END IF;

  IF NOT public.has_active_tenant_membership(v_shop_tenant_id)
     AND NOT public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_shop_tenant_id))
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  v_limit := greatest(1, least(coalesce(p_limit, 200), 500));
  v_offset := greatest(0, coalesce(p_offset, 0));

  SELECT count(DISTINCT gs.id)
  INTO v_total_count
  FROM public.global_stocks gs
  JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
  LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
  LEFT JOIN public.tags tg ON tg.id = gs.grade_tag_id
  WHERE gs.parent_tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
    AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
    AND gship.status = 'received'
    AND gs.availability = 'sellable'::public.stock_availability
    AND (gs.location_id IS NULL OR sl.is_pickable = true)
    AND (
      p_search IS NULL
      OR p_search = ''
      OR (
        gsi.name ILIKE '%' || p_search || '%'
        OR gsi.product_code ILIKE '%' || p_search || '%'
        OR gsi.barcode ILIKE '%' || p_search || '%'
        OR gship.name ILIKE '%' || p_search || '%'
        OR tg.name ILIKE '%' || p_search || '%'
      )
    );

  SELECT coalesce(jsonb_agg(row_json ORDER BY sort_id DESC), '[]'::jsonb)
  INTO v_data
  FROM (
    SELECT
      gs.id AS sort_id,
      jsonb_build_object(
        'global_stock_id', gs.id,
        'shipment_item_id', gsi.id,
        'shipment_id', gship.id,
        'shipment_name', gship.name,
        'item_name', gsi.name,
        'product_id', gsi.product_id,
        'product_code', gsi.product_code,
        'barcode', gsi.barcode,
        'image_url', gsi.image_url,
        'product_brand', p.brand,
        'product_category', p.category,
        'available_atp', public.global_stock_atp_qty(gs.id),
        'total_stock_qty', gs.quantity,
        'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(gsi.id), 0.00),
        'stock_grade', CASE
          WHEN tg.slug IS NOT NULL THEN jsonb_build_object(
            'slug', tg.slug,
            'label', tg.name,
            'color', tg.color
          )
          ELSE NULL
        END,
        'is_listed_on_shop', EXISTS (
          SELECT 1
          FROM public.shop_product_listings spl
          WHERE spl.shop_id = p_shop_id
            AND spl.global_stock_id = gs.id
        ),
        'listing_id', (
          SELECT spl.id
          FROM public.shop_product_listings spl
          WHERE spl.shop_id = p_shop_id
            AND spl.global_stock_id = gs.id
          LIMIT 1
        )
      ) AS row_json
    FROM public.global_stocks gs
    JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
    JOIN public.products p ON p.id = gsi.product_id
    LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
    LEFT JOIN public.tags tg ON tg.id = gs.grade_tag_id
    WHERE gs.parent_tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
      AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
      AND gship.status = 'received'
      AND gs.availability = 'sellable'::public.stock_availability
      AND (gs.location_id IS NULL OR sl.is_pickable = true)
      AND (
        p_search IS NULL
        OR p_search = ''
        OR (
          gsi.name ILIKE '%' || p_search || '%'
          OR gsi.product_code ILIKE '%' || p_search || '%'
          OR gsi.barcode ILIKE '%' || p_search || '%'
          OR gship.name ILIKE '%' || p_search || '%'
          OR tg.name ILIKE '%' || p_search || '%'
        )
      )
    ORDER BY gs.id DESC
    LIMIT v_limit
    OFFSET v_offset
  ) q;

  RETURN jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', (v_offset / v_limit) + 1,
      'page_size', v_limit,
      'total_pages', greatest(1, ceil(v_total_count::numeric / v_limit::numeric))
    )
  );
END;
$function$;

GRANT ALL ON FUNCTION public.list_allocated_stock_for_shop(bigint, text, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.list_allocated_stock_for_shop(bigint, text, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.list_allocated_stock_for_shop(bigint, text, integer, integer) TO service_role;
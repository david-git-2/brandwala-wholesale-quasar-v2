-- Restore stock_grade on list_listable_stock_for_shop (dropped in parent-stock visibility migration).

CREATE OR REPLACE FUNCTION public.list_listable_stock_for_shop(
  p_shop_id bigint,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_shop_tenant_id bigint;
  v_total_count bigint;
  v_data jsonb;
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
    AND public.global_stock_atp_qty(gs.id) > 0
    AND NOT EXISTS (
      SELECT 1
      FROM public.shop_product_listings spl
      WHERE spl.shop_id = p_shop_id
        AND spl.global_stock_id = gs.id
        AND spl.is_active = true
    )
    AND (
      p_search IS NULL OR p_search = '' OR (
        gsi.name ILIKE '%' || p_search || '%'
        OR gsi.product_code ILIKE '%' || p_search || '%'
        OR gsi.barcode ILIKE '%' || p_search || '%'
        OR gship.name ILIKE '%' || p_search || '%'
        OR tg.name ILIKE '%' || p_search || '%'
        OR tg.slug ILIKE '%' || p_search || '%'
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
        'available_atp', public.global_stock_atp_qty(gs.id),
        'total_stock_qty', gs.quantity,
        'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(gsi.id), 0.00),
        'stock_grade', CASE
          WHEN tg.slug IS NOT NULL THEN jsonb_build_object(
            'slug', tg.slug,
            'label', tg.name,
            'color', tg.color
          )
          ELSE jsonb_build_object(
            'slug', 'standard',
            'label', 'Standard',
            'color', '#22c55e'
          )
        END
      ) AS row_json
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
      AND public.global_stock_atp_qty(gs.id) > 0
      AND NOT EXISTS (
        SELECT 1
        FROM public.shop_product_listings spl
        WHERE spl.shop_id = p_shop_id
          AND spl.global_stock_id = gs.id
          AND spl.is_active = true
      )
      AND (
        p_search IS NULL OR p_search = '' OR (
          gsi.name ILIKE '%' || p_search || '%'
          OR gsi.product_code ILIKE '%' || p_search || '%'
          OR gsi.barcode ILIKE '%' || p_search || '%'
          OR gship.name ILIKE '%' || p_search || '%'
          OR tg.name ILIKE '%' || p_search || '%'
          OR tg.slug ILIKE '%' || p_search || '%'
        )
      )
    ORDER BY gs.id DESC
    LIMIT p_limit
    OFFSET p_offset
  ) q;

  RETURN jsonb_build_object(
    'data', v_data,
    'total', v_total_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_listable_stock_for_shop(bigint, text, integer, integer) TO authenticated;

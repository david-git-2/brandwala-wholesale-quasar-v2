CREATE FUNCTION public.list_procurement_demand_group_items (
  p_tenant_id        bigint,
  p_document_type    text,
  p_document_id      bigint,
  p_search           text    DEFAULT NULL::text,
  p_limit            integer DEFAULT 50,
  p_cursor_source_id bigint  DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 100));
  v_items jsonb := '[]'::jsonb;
  v_n integer := 0;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
  v_last_source_id bigint;
BEGIN
  IF p_tenant_id IS NULL OR p_document_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id and document_id are required';
  END IF;

  SELECT (t.parent_id IS NULL) INTO v_is_parent FROM public.tenants t WHERE t.id = p_tenant_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant not found: %', p_tenant_id; END IF;

  IF v_is_parent THEN
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  ELSE
    v_allowed := public.is_tenant_staff(p_tenant_id);
  END IF;
  IF NOT coalesce(v_allowed, false) THEN RAISE EXCEPTION 'access denied'; END IF;

  IF v_doc_type NOT IN ('shop_order', 'pbc_costing_file') THEN
    RAISE EXCEPTION 'invalid document_type: %', p_document_type;
  END IF;

  WITH tenant_scope AS (
    SELECT t.id AS tenant_id FROM public.tenants t
    WHERE (
      (v_is_parent AND (t.parent_id = p_tenant_id OR t.id = p_tenant_id))
      OR (NOT v_is_parent AND t.id = p_tenant_id)
    )
  ),
  shop_lines AS (
    SELECT
      'shop_order'::text AS document_type,
      o.id AS document_id,
      'shop_order_item'::text AS source_type,
      oi.id AS source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') AS barcode,
      coalesce(p.product_code, '') AS product_code,
      nullif(trim(coalesce(p.vendor_code, '')), '') AS vendor_code,
      nullif(trim(coalesce(p.market_code, '')), '') AS market_code,
      nullif(trim(coalesce(p.brand, '')), '') AS brand,
      nullif(trim(coalesce(p.category, '')), '') AS category,
      p.available_units,
      nullif(trim(coalesce(p.languages, '')), '') AS languages,
      nullif(trim(coalesce(p.country_of_origin, '')), '') AS country_of_origin,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer AS quantity,
      pd.id AS preorder_demand_id,
      pd.vendor_id,
      coalesce(public.sum_preorder_vendor_placements(pd.vendor_placements), pd.placed_quantity, 0) AS placed_quantity,
      coalesce(pd.delivered_quantity, 0) AS delivered_quantity,
      coalesce(pd.vendor_placements, '[]'::jsonb) AS vendor_placements,
      coalesce(pd.stock_picks, '[]'::jsonb) AS stock_picks,
      o.is_negotiable_snapshot,
      public.shop_order_item_delivery_sell_price(
        o.is_negotiable_snapshot,
        oi.staff_offer_amount,
        oi.final_price_amount
      ) AS unit_sell_price_amount
    FROM public.shop_order_items oi
    INNER JOIN public.shop_orders o ON o.id = oi.order_id
    INNER JOIN tenant_scope ts ON ts.tenant_id = o.tenant_id
    LEFT JOIN public.products p ON p.id = oi.product_id
    LEFT JOIN public.preorder_demand pd
      ON pd.source_type = 'shop_order_item'
      AND pd.source_id = oi.id
      AND pd.tenant_id = o.tenant_id
    WHERE v_doc_type = 'shop_order'
      AND o.id = p_document_id
      AND o.shop_type_snapshot = 'vendor_catalog'
  ),
  pbc_lines AS (
    SELECT
      'pbc_costing_file'::text AS document_type,
      f.id AS document_id,
      'pbc_costing_item'::text AS source_type,
      pci.id AS source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') AS name,
      coalesce(pci.image_url, p.image_url) AS image_url,
      coalesce(pci.barcode, p.barcode, '') AS barcode,
      coalesce(pci.product_code, p.product_code, '') AS product_code,
      coalesce(
        nullif(trim(coalesce(pci.vendor_code, '')), ''),
        nullif(trim(coalesce(p.vendor_code, '')), '')
      ) AS vendor_code,
      coalesce(
        nullif(trim(coalesce(pci.market_code, '')), ''),
        nullif(trim(coalesce(p.market_code, '')), '')
      ) AS market_code,
      coalesce(
        nullif(trim(coalesce(pci.brand, '')), ''),
        nullif(trim(coalesce(p.brand, '')), '')
      ) AS brand,
      nullif(trim(coalesce(p.category, '')), '') AS category,
      p.available_units,
      nullif(trim(coalesce(p.languages, '')), '') AS languages,
      nullif(trim(coalesce(p.country_of_origin, '')), '') AS country_of_origin,
      greatest(
        CASE WHEN pci.assigned_shipment_id IS NOT NULL THEN 0
          ELSE coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        END,
        0
      )::integer AS quantity,
      pd.id AS preorder_demand_id,
      pd.vendor_id,
      coalesce(public.sum_preorder_vendor_placements(pd.vendor_placements), pd.placed_quantity, 0) AS placed_quantity,
      coalesce(pd.delivered_quantity, 0) AS delivered_quantity,
      coalesce(pd.vendor_placements, '[]'::jsonb) AS vendor_placements,
      coalesce(pd.stock_picks, '[]'::jsonb) AS stock_picks,
      NULL::boolean AS is_negotiable_snapshot,
      coalesce(pci.offer_price, 0)::numeric(12, 2) AS unit_sell_price_amount
    FROM public.product_based_costing_items pci
    INNER JOIN public.product_based_costing_files f ON f.id = pci.product_based_costing_file_id
    INNER JOIN tenant_scope ts ON ts.tenant_id = f.tenant_id
    LEFT JOIN public.products p ON p.id = pci.product_id
    LEFT JOIN public.preorder_demand pd
      ON pd.source_type = 'pbc_costing_item'
      AND pd.source_id = pci.id
      AND pd.tenant_id = f.tenant_id
    WHERE v_doc_type = 'pbc_costing_file'
      AND f.id = p_document_id
      AND f.profile_id IS NOT NULL
  ),
  demand_lines AS (
    SELECT * FROM shop_lines
    UNION ALL
    SELECT * FROM pbc_lines
  ),
  eligible_lines AS (
    SELECT dl.*
    FROM demand_lines dl
    WHERE (
      dl.quantity > 0
      OR dl.placed_quantity > 0
      OR dl.delivered_quantity > 0
    )
      AND (
        v_search IS NULL
        OR dl.name ILIKE '%' || v_search || '%'
        OR coalesce(dl.barcode, '') ILIKE '%' || v_search || '%'
        OR coalesce(dl.product_code, '') ILIKE '%' || v_search || '%'
      )
      AND (
        p_cursor_source_id IS NULL
        OR dl.source_id > p_cursor_source_id
      )
  ),
  paged AS (
    SELECT el.*
    FROM eligible_lines el
    ORDER BY el.source_id
    LIMIT v_limit + 1
  ),
  page_count AS (
    SELECT count(*)::integer AS n FROM paged
  ),
  page_rows AS (
    SELECT p.*
    FROM paged p
    ORDER BY p.source_id
    LIMIT v_limit
  ),
  item_json AS (
    SELECT coalesce(
      jsonb_agg(
        jsonb_build_object(
          'source_type', row.source_type,
          'source_id', row.source_id,
          'product_id', row.product_id,
          'name', row.name,
          'image_url', row.image_url,
          'barcode', nullif(row.barcode, ''),
          'product_code', nullif(row.product_code, ''),
          'vendor_code', row.vendor_code,
          'market_code', row.market_code,
          'brand', row.brand,
          'category', row.category,
          'available_units', row.available_units,
          'languages', row.languages,
          'country_of_origin', row.country_of_origin,
          'quantity', row.quantity,
          'need_quantity', row.quantity,
          'preorder_demand_id', row.preorder_demand_id,
          'vendor_id', row.vendor_id,
          'placed_quantity', row.placed_quantity,
          'vendor_placements', row.vendor_placements,
          'delivered_quantity', row.delivered_quantity,
          'remaining_quantity', row.quantity - row.placed_quantity,
          'remaining_to_deliver', greatest(row.quantity - row.delivered_quantity, 0),
          'stock_picks', row.stock_picks,
          'is_negotiable_snapshot', row.is_negotiable_snapshot,
          'unit_sell_price_amount', row.unit_sell_price_amount
        )
        ORDER BY row.source_id
      ),
      '[]'::jsonb
    ) AS items
    FROM page_rows row
  ),
  cursor_row AS (
    SELECT p.source_id
    FROM paged p
    ORDER BY p.source_id
    OFFSET v_limit
    LIMIT 1
  )
  SELECT
    ij.items,
    pc.n,
    cr.source_id
  INTO v_items, v_n, v_last_source_id
  FROM item_json ij
  CROSS JOIN page_count pc
  LEFT JOIN cursor_row cr ON true;

  v_has_more := v_n > v_limit;
  IF v_has_more AND v_last_source_id IS NOT NULL THEN
    v_next_cursor := jsonb_build_object('source_id', v_last_source_id);
  END IF;

  RETURN jsonb_build_object(
    'meta', jsonb_build_object(
      'document_type', v_doc_type,
      'document_id', p_document_id,
      'limit', v_limit,
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    ),
    'items', v_items
  );
END;
$function$;

GRANT ALL ON FUNCTION public.list_procurement_demand_group_items(bigint, text, bigint, text, integer, bigint) TO anon;

GRANT ALL ON FUNCTION public.list_procurement_demand_group_items(bigint, text, bigint, text, integer, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_procurement_demand_group_items(bigint, text, bigint, text, integer, bigint) TO service_role;
CREATE FUNCTION public.list_procurement_demand_buy_documents (
  p_tenant_id       bigint,
  p_search          text    DEFAULT NULL::text,
  p_child_tenant_id bigint  DEFAULT NULL::bigint,
  p_limit           integer DEFAULT 50,
  p_offset          integer DEFAULT 0
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_is_parent boolean;
  v_allowed boolean := false;
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(coalesce(p_limit, 50), 1);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_documents jsonb := '[]'::jsonb;
  v_doc_count integer := 0;
  v_line_count integer := 0;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  SELECT (t.parent_id IS NULL) INTO v_is_parent FROM public.tenants t WHERE t.id = p_tenant_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant not found: %', p_tenant_id; END IF;

  IF v_is_parent THEN
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  ELSE
    v_allowed := public.is_tenant_staff(p_tenant_id);
  END IF;
  IF NOT coalesce(v_allowed, false) THEN RAISE EXCEPTION 'access denied'; END IF;

  WITH tenant_scope AS (
    SELECT t.id AS tenant_id FROM public.tenants t
    WHERE (
      (v_is_parent AND (t.parent_id = p_tenant_id OR t.id = p_tenant_id))
      OR (NOT v_is_parent AND t.id = p_tenant_id)
    )
      AND (p_child_tenant_id IS NULL OR t.id = p_child_tenant_id)
  ),
  shop_lines AS (
    SELECT
      'shop_order'::text AS document_type,
      o.id AS document_id,
      'procuring'::text AS document_status,
      o.customer_group_id,
      cg.name AS customer_group_name,
      coalesce(pd.profile_id, o.profile_id) AS profile_id,
      pr.name AS profile_name,
      null::jsonb AS vendor,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer AS quantity,
      coalesce(
        public.sum_preorder_vendor_placements(pd.vendor_placements),
        pd.placed_quantity,
        0
      ) AS placed_quantity,
      o.global_invoice_id AS invoice_id,
      nullif(trim(o.order_no), '') AS shop_order_no,
      nullif(trim(o.order_no), '') AS document_name
    FROM public.shop_order_items oi
    INNER JOIN public.shop_orders o ON o.id = oi.order_id
    INNER JOIN tenant_scope ts ON ts.tenant_id = o.tenant_id
    LEFT JOIN public.customer_groups cg ON cg.id = o.customer_group_id
    LEFT JOIN public.products p ON p.id = oi.product_id
    LEFT JOIN public.preorder_demand pd
      ON pd.source_type = 'shop_order_item'
      AND pd.source_id = oi.id
      AND pd.tenant_id = o.tenant_id
    LEFT JOIN public.profiles pr ON pr.id = coalesce(pd.profile_id, o.profile_id)
    WHERE o.shop_type_snapshot = 'vendor_catalog'
      AND public.normalize_shop_order_procurement_status(o.status) = 'procuring'
      AND (
        v_search IS NULL
        OR oi.name ILIKE '%' || v_search || '%'
        OR o.name ILIKE '%' || v_search || '%'
        OR o.order_no ILIKE '%' || v_search || '%'
        OR coalesce(p.barcode, '') ILIKE '%' || v_search || '%'
        OR coalesce(p.product_code, '') ILIKE '%' || v_search || '%'
        OR coalesce(pr.name, '') ILIKE '%' || v_search || '%'
      )
  ),
  pbc_lines AS (
    SELECT
      'pbc_costing_file'::text AS document_type,
      f.id AS document_id,
      'procuring'::text AS document_status,
      f.customer_group_id,
      cg.name AS customer_group_name,
      coalesce(pd.profile_id, f.profile_id) AS profile_id,
      pr.name AS profile_name,
      CASE
        WHEN v.id IS NOT NULL THEN jsonb_build_object(
          'id', v.id,
          'code', coalesce(nullif(trim(f.vendor_code), ''), v.code),
          'name', v.name
        )
        WHEN nullif(trim(f.vendor_code), '') IS NOT NULL THEN jsonb_build_object(
          'id', f.vendor_id,
          'code', trim(f.vendor_code),
          'name', null
        )
        ELSE null::jsonb
      END AS vendor,
      greatest(
        CASE
          WHEN pci.assigned_shipment_id IS NOT NULL THEN 0
          ELSE coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        END,
        0
      )::integer AS quantity,
      coalesce(
        public.sum_preorder_vendor_placements(pd.vendor_placements),
        pd.placed_quantity,
        0
      ) AS placed_quantity,
      f.invoice_id,
      null::text AS shop_order_no,
      nullif(trim(coalesce(f.name, '')), '') AS document_name
    FROM public.product_based_costing_items pci
    INNER JOIN public.product_based_costing_files f ON f.id = pci.product_based_costing_file_id
    INNER JOIN tenant_scope ts ON ts.tenant_id = f.tenant_id
    LEFT JOIN public.customer_groups cg ON cg.id = f.customer_group_id
    LEFT JOIN public.products p ON p.id = pci.product_id
    LEFT JOIN public.vendors v ON v.id = f.vendor_id
    LEFT JOIN public.preorder_demand pd
      ON pd.source_type = 'pbc_costing_item'
      AND pd.source_id = pci.id
      AND pd.tenant_id = f.tenant_id
    LEFT JOIN public.profiles pr ON pr.id = coalesce(pd.profile_id, f.profile_id)
    WHERE f.profile_id IS NOT NULL
      AND public.normalize_pbc_procurement_status(f.status) = 'procuring'
      AND (
        v_search IS NULL
        OR coalesce(pci.name, p.name, '') ILIKE '%' || v_search || '%'
        OR coalesce(f.name, '') ILIKE '%' || v_search || '%'
        OR coalesce(pci.barcode, p.barcode, '') ILIKE '%' || v_search || '%'
        OR coalesce(pci.product_code, p.product_code, '') ILIKE '%' || v_search || '%'
        OR coalesce(pr.name, '') ILIKE '%' || v_search || '%'
      )
  ),
  demand_lines AS (
    SELECT * FROM shop_lines
    UNION ALL
    SELECT * FROM pbc_lines
  ),
  eligible_lines AS (
    SELECT dl.*
    FROM demand_lines dl
    WHERE dl.quantity > 0
  ),
  grouped AS (
    SELECT
      el.document_type,
      el.document_id,
      max(el.document_status) AS document_status,
      max(el.customer_group_id) AS customer_group_id,
      max(el.customer_group_name) AS customer_group_name,
      max(el.profile_id) AS profile_id,
      max(el.profile_name) AS profile_name,
      (array_agg(el.vendor) FILTER (WHERE el.vendor IS NOT NULL))[1] AS vendor,
      max(el.invoice_id) AS invoice_id,
      max(el.document_name) AS document_name,
      max(el.shop_order_no) AS shop_order_no,
      count(*) FILTER (WHERE el.quantity > 0)::integer AS line_count,
      count(*) FILTER (
        WHERE el.quantity > 0 AND el.placed_quantity < el.quantity
      )::integer AS under_ordered_line_count
    FROM eligible_lines el
    GROUP BY el.document_type, el.document_id
  ),
  paged AS (
    SELECT
      g.*,
      (g.under_ordered_line_count > 0) AS has_under_ordered_lines,
      count(*) OVER ()::integer AS total_documents
    FROM grouped g
    ORDER BY g.document_type, g.document_id
    LIMIT v_limit OFFSET v_offset
  )
  SELECT
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'document_type', p.document_type,
          'document_id', p.document_id,
          'document_name', p.document_name,
          'shop_order_no', p.shop_order_no,
          'document_status', p.document_status,
          'customer_group_id', p.customer_group_id,
          'customer_group_name', p.customer_group_name,
          'profile_id', p.profile_id,
          'profile_name', p.profile_name,
          'vendor', p.vendor,
          'invoice_id', p.invoice_id,
          'line_count', p.line_count,
          'under_ordered_line_count', p.under_ordered_line_count,
          'has_under_ordered_lines', p.has_under_ordered_lines
        )
        ORDER BY p.document_type, p.document_id
      ),
      '[]'::jsonb
    ),
    coalesce(max(p.total_documents), 0),
    coalesce(sum(p.line_count), 0)
  INTO v_documents, v_doc_count, v_line_count
  FROM paged p;

  RETURN jsonb_build_object(
    'meta', jsonb_build_object(
      'tenant_id', p_tenant_id,
      'document_count', coalesce(jsonb_array_length(v_documents), 0),
      'line_count', v_line_count,
      'total_document_count', v_doc_count,
      'limit', v_limit,
      'offset', v_offset,
      'has_more', v_doc_count > (v_offset + v_limit)
    ),
    'documents', v_documents
  );
END;
$function$;

GRANT ALL ON FUNCTION public.list_procurement_demand_buy_documents(bigint, text, bigint, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.list_procurement_demand_buy_documents(bigint, text, bigint, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.list_procurement_demand_buy_documents(bigint, text, bigint, integer, integer) TO service_role;
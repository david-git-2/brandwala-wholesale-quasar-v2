-- Demand buy page: list + get RPCs; upsert accepts full vendor_placements array.

CREATE OR REPLACE FUNCTION public.list_procurement_demand_buy_documents(
  p_tenant_id bigint,
  p_search text DEFAULT NULL,
  p_child_tenant_id bigint DEFAULT NULL,
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
$$;

CREATE OR REPLACE FUNCTION public.get_procurement_demand_buy_document(
  p_tenant_id bigint,
  p_document_type text,
  p_document_id bigint,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_cursor_source_id bigint DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_items_payload jsonb;
  v_document jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_document_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id and document_id are required';
  END IF;
  IF v_doc_type NOT IN ('shop_order', 'pbc_costing_file') THEN
    RAISE EXCEPTION 'invalid document_type: %', p_document_type;
  END IF;

  v_items_payload := public.list_procurement_demand_group_items(
    p_tenant_id,
    v_doc_type,
    p_document_id,
    p_search,
    p_limit,
    p_cursor_source_id
  );

  SELECT doc INTO v_document
  FROM (
    SELECT (d.value) AS doc
    FROM jsonb_array_elements(
      (public.list_procurement_demand_buy_documents(
        p_tenant_id,
        null,
        null,
        500,
        0
      )->'documents')
    ) AS d(value)
    WHERE lower(trim(coalesce(d.value->>'document_type', ''))) = v_doc_type
      AND (d.value->>'document_id')::bigint = p_document_id
    LIMIT 1
  ) sub;

  IF v_document IS NULL THEN
    RAISE EXCEPTION 'document not found or not in procuring';
  END IF;

  RETURN jsonb_build_object(
    'document', v_document,
    'items', coalesce(v_items_payload->'items', '[]'::jsonb),
    'meta', coalesce(v_items_payload->'meta', '{}'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_preorder_demand(
  p_tenant_id bigint,
  p_source_type public.preorder_demand_source_type,
  p_source_id bigint,
  p_vendor_id bigint DEFAULT NULL,
  p_placed_quantity integer DEFAULT NULL,
  p_stock_picks jsonb DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_vendor_placements jsonb DEFAULT NULL
)
RETURNS public.preorder_demand
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.preorder_demand;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_open_qty integer;
  v_delivered integer;
  v_placed integer;
  v_placements jsonb;
  v_vendor_code text;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;
  IF p_source_id IS NULL THEN
    RAISE EXCEPTION 'source_id is required';
  END IF;

  SELECT g.tenant_id, g.open_qty, g.document_status
  INTO v_line_tenant_id, v_open_qty, v_doc_status
  FROM public.get_procurement_demand_open_qty(p_source_type, p_source_id) g;

  IF v_line_tenant_id IS NULL THEN
    RAISE EXCEPTION 'demand line not found';
  END IF;

  IF NOT public.can_access_preorder_demand_tenant(p_tenant_id)
    AND NOT public.can_access_preorder_demand_tenant(v_line_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF v_line_tenant_id <> p_tenant_id THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.tenants t
      WHERE t.id = v_line_tenant_id
        AND t.parent_id = p_tenant_id
        AND public.user_can_manage_parent_tenant(p_tenant_id)
    ) THEN
      RAISE EXCEPTION 'tenant mismatch for demand line';
    END IF;
  END IF;

  IF v_doc_status NOT IN ('procuring', 'packed') THEN
    RAISE EXCEPTION 'document is not open for preorder demand updates';
  END IF;

  IF (p_placed_quantity IS NOT NULL OR p_vendor_placements IS NOT NULL)
    AND v_doc_status <> 'procuring' THEN
    RAISE EXCEPTION 'vendor placements can only be updated while procuring';
  END IF;

  IF p_stock_picks IS NOT NULL AND v_doc_status NOT IN ('procuring', 'packed') THEN
    RAISE EXCEPTION 'stock_picks can only be updated while procuring or packed';
  END IF;

  IF p_vendor_placements IS NOT NULL THEN
    IF NOT public.validate_preorder_vendor_placements(p_vendor_placements) THEN
      RAISE EXCEPTION 'invalid vendor_placements payload';
    END IF;
    v_placements := p_vendor_placements;
    v_placed := public.sum_preorder_vendor_placements(v_placements);
    IF v_placed > coalesce(v_open_qty, 0) THEN
      RAISE EXCEPTION 'placed quantity cannot exceed need quantity';
    END IF;
  ELSIF p_placed_quantity IS NOT NULL THEN
    IF coalesce(p_placed_quantity, 0) < 0 THEN
      RAISE EXCEPTION 'placed_quantity cannot be negative';
    END IF;
    SELECT pd.* INTO v_row
    FROM public.preorder_demand pd
    WHERE pd.source_type = p_source_type AND pd.source_id = p_source_id;
    SELECT nullif(trim(v.code), '') INTO v_vendor_code
    FROM public.vendors v
    WHERE v.id = coalesce(p_vendor_id, v_row.vendor_id);
    v_vendor_code := coalesce(v_vendor_code, 'unknown');
    v_placements := jsonb_build_array(
      jsonb_build_object('vendor_code', v_vendor_code, 'quantity', p_placed_quantity)
    );
    v_placed := p_placed_quantity;
    IF v_placed > coalesce(v_open_qty, 0) THEN
      RAISE EXCEPTION 'placed quantity cannot exceed need quantity';
    END IF;
  ELSE
    v_placements := NULL;
  END IF;

  IF p_stock_picks IS NOT NULL AND NOT public.validate_preorder_stock_picks(p_stock_picks) THEN
    RAISE EXCEPTION 'invalid stock_picks payload';
  END IF;

  v_delivered := CASE
    WHEN p_stock_picks IS NOT NULL THEN public.sum_preorder_stock_picks(p_stock_picks)
    ELSE NULL
  END;

  SELECT pd.* INTO v_row
  FROM public.preorder_demand pd
  WHERE pd.source_type = p_source_type
    AND pd.source_id = p_source_id;

  IF v_placements IS NULL THEN
    IF found THEN
      v_placed := coalesce(
        public.sum_preorder_vendor_placements(v_row.vendor_placements),
        v_row.placed_quantity,
        0
      );
    ELSE
      v_placed := 0;
    END IF;
  END IF;

  IF v_delivered IS NOT NULL AND v_delivered > coalesce(v_open_qty, 0) THEN
    RAISE EXCEPTION 'delivered_quantity cannot exceed need quantity';
  END IF;

  INSERT INTO public.preorder_demand (
    tenant_id,
    parent_tenant_id,
    source_type,
    source_id,
    vendor_id,
    placed_quantity,
    delivered_quantity,
    vendor_placements,
    stock_picks,
    notes,
    updated_by_user_id
  ) VALUES (
    v_line_tenant_id,
    public.resolve_parent_tenant_id(v_line_tenant_id),
    p_source_type,
    p_source_id,
    coalesce(p_vendor_id, CASE WHEN found THEN v_row.vendor_id ELSE NULL END),
    v_placed,
    coalesce(v_delivered, CASE WHEN found THEN v_row.delivered_quantity ELSE 0 END, 0),
    coalesce(v_placements, CASE WHEN found THEN v_row.vendor_placements ELSE '[]'::jsonb END, '[]'::jsonb),
    coalesce(p_stock_picks, CASE WHEN found THEN v_row.stock_picks ELSE '[]'::jsonb END, '[]'::jsonb),
    coalesce(nullif(trim(p_notes), ''), CASE WHEN found THEN v_row.notes ELSE NULL END),
    auth.uid()
  )
  ON CONFLICT (source_type, source_id) DO UPDATE SET
    parent_tenant_id = coalesce(public.preorder_demand.parent_tenant_id, excluded.parent_tenant_id),
    vendor_id = CASE WHEN p_vendor_id IS NOT NULL THEN p_vendor_id ELSE preorder_demand.vendor_id END,
    placed_quantity = v_placed,
    vendor_placements = CASE
      WHEN v_placements IS NOT NULL THEN v_placements
      ELSE preorder_demand.vendor_placements
    END,
    delivered_quantity = CASE
      WHEN v_delivered IS NOT NULL THEN v_delivered
      ELSE preorder_demand.delivered_quantity
    END,
    open_quantity = greatest(
      coalesce(preorder_demand.confirmed_quantity, 0)
        - CASE WHEN v_delivered IS NOT NULL THEN v_delivered ELSE preorder_demand.delivered_quantity END,
      0
    ),
    stock_picks = CASE WHEN p_stock_picks IS NOT NULL THEN p_stock_picks ELSE preorder_demand.stock_picks END,
    notes = CASE WHEN p_notes IS NOT NULL THEN nullif(trim(p_notes), '') ELSE preorder_demand.notes END,
    updated_by_user_id = auth.uid(),
    updated_at = now()
  RETURNING * INTO v_row;

  IF p_stock_picks IS NOT NULL OR jsonb_array_length(coalesce(v_row.stock_picks, '[]'::jsonb)) > 0 THEN
    PERFORM public.sync_delivery_paper_lines_for_demand(v_row.id);
  END IF;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_procurement_demand_buy_documents(
  bigint, text, bigint, integer, integer
) TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.get_procurement_demand_buy_document(
  bigint, text, bigint, text, integer, bigint
) TO authenticated, service_role;

-- Delivery paper: create/list/detail/save for catalog + PBC (paper-scoped lines, splits).

DROP INDEX IF EXISTS public.delivery_paper_line_paper_demand_stock_uidx;

CREATE OR REPLACE FUNCTION public.delivery_paper_assert_tenant_access(p_tenant_id bigint)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_parent boolean;
  v_allowed boolean := false;
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
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.delivery_paper_map_line_status_to_close_action(
  p_status public.delivery_paper_line_status
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p_status
    WHEN 'conditioned'::public.delivery_paper_line_status THEN 'condition'
    WHEN 'rejected'::public.delivery_paper_line_status THEN 'return'
    WHEN 'accepted'::public.delivery_paper_line_status THEN 'take'
    ELSE null
  END;
$$;

CREATE OR REPLACE FUNCTION public.delivery_paper_document_allows_papers(
  p_document_type text,
  p_document_id bigint,
  p_tenant_id bigint
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_shop_status text;
  v_pbc_status text;
  v_open_lines integer := 0;
BEGIN
  IF v_doc_type = 'shop_order' THEN
    SELECT public.normalize_shop_order_procurement_status(o.status)
    INTO v_shop_status
    FROM public.shop_orders o
    WHERE o.id = p_document_id
      AND o.shop_type_snapshot = 'vendor_catalog';
    IF NOT FOUND THEN RETURN false; END IF;
    IF v_shop_status = 'procuring' THEN RETURN true; END IF;
    SELECT count(*)::integer INTO v_open_lines
    FROM public.shop_order_items oi
    INNER JOIN public.preorder_demand pd
      ON pd.source_type = 'shop_order_item'
      AND pd.source_id = oi.id
    WHERE oi.order_id = p_document_id
      AND coalesce(pd.open_quantity, 0) > 0;
    RETURN v_open_lines > 0;
  ELSIF v_doc_type = 'pbc_costing_file' THEN
    SELECT public.normalize_pbc_procurement_status(f.status)
    INTO v_pbc_status
    FROM public.product_based_costing_files f
    WHERE f.id = p_document_id
      AND f.profile_id IS NOT NULL;
    IF NOT FOUND THEN RETURN false; END IF;
    IF v_pbc_status = 'procuring' THEN RETURN true; END IF;
    SELECT count(*)::integer INTO v_open_lines
    FROM public.product_based_costing_items pci
    INNER JOIN public.preorder_demand pd
      ON pd.source_type = 'pbc_costing_item'
      AND pd.source_id = pci.id
    WHERE pci.product_based_costing_file_id = p_document_id
      AND coalesce(pd.open_quantity, 0) > 0;
    RETURN v_open_lines > 0;
  END IF;
  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_delivery_paper_for_document(
  p_tenant_id bigint,
  p_document_type text,
  p_document_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_source_type public.delivery_paper_source_type;
  v_parent_tenant_id bigint;
  v_profile_id bigint;
  v_paper_id bigint;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  IF p_document_id IS NULL THEN
    RAISE EXCEPTION 'document_id is required';
  END IF;
  IF v_doc_type NOT IN ('shop_order', 'pbc_costing_file') THEN
    RAISE EXCEPTION 'invalid document_type: %', p_document_type;
  END IF;
  IF NOT public.delivery_paper_document_allows_papers(v_doc_type, p_document_id, p_tenant_id) THEN
    RAISE EXCEPTION 'document does not allow new delivery papers';
  END IF;

  v_source_type := v_doc_type::public.delivery_paper_source_type;

  IF v_doc_type = 'shop_order' THEN
    SELECT
      public.resolve_parent_tenant_id(o.tenant_id),
      o.profile_id
    INTO v_parent_tenant_id, v_profile_id
    FROM public.shop_orders o
    WHERE o.id = p_document_id
      AND o.shop_type_snapshot = 'vendor_catalog';
    IF NOT FOUND THEN RAISE EXCEPTION 'shop order not found'; END IF;
  ELSE
    SELECT
      public.resolve_parent_tenant_id(f.tenant_id),
      f.profile_id
    INTO v_parent_tenant_id, v_profile_id
    FROM public.product_based_costing_files f
    WHERE f.id = p_document_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'costing file not found'; END IF;
  END IF;

  INSERT INTO public.delivery_paper (
    parent_tenant_id,
    source_type,
    source_id,
    profile_id,
    status
  ) VALUES (
    v_parent_tenant_id,
    v_source_type,
    p_document_id,
    v_profile_id,
    'draft'::public.delivery_paper_status
  )
  RETURNING id INTO v_paper_id;

  RETURN jsonb_build_object(
    'id', v_paper_id,
    'status', 'draft',
    'created_at', now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.list_delivery_papers_for_document(
  p_tenant_id bigint,
  p_document_type text,
  p_document_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_source_type public.delivery_paper_source_type;
  v_papers jsonb := '[]'::jsonb;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  IF p_document_id IS NULL THEN
    RAISE EXCEPTION 'document_id is required';
  END IF;
  IF v_doc_type NOT IN ('shop_order', 'pbc_costing_file') THEN
    RAISE EXCEPTION 'invalid document_type: %', p_document_type;
  END IF;

  v_source_type := v_doc_type::public.delivery_paper_source_type;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', dp.id,
        'status', dp.status,
        'created_at', dp.created_at,
        'updated_at', dp.updated_at,
        'delivery_date', dp.delivery_date,
        'note', dp.note,
        'line_count', (
          SELECT count(*)::integer
          FROM public.delivery_paper_line dpl
          WHERE dpl.delivery_paper_id = dp.id
        )
      )
      ORDER BY dp.created_at DESC, dp.id DESC
    ),
    '[]'::jsonb
  )
  INTO v_papers
  FROM public.delivery_paper dp
  WHERE dp.source_type = v_source_type
    AND dp.source_id = p_document_id;

  RETURN jsonb_build_object('papers', v_papers);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_delivery_paper_detail(
  p_tenant_id bigint,
  p_delivery_paper_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_doc_type text;
  v_document_name text;
  v_shop_order_no text;
  v_profile_name text;
  v_items_payload jsonb;
  v_items jsonb := '[]'::jsonb;
  v_item jsonb;
  v_paper_picks jsonb;
  v_merged jsonb := '[]'::jsonb;
  i integer;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  SELECT * INTO v_paper FROM public.delivery_paper dp WHERE dp.id = p_delivery_paper_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'delivery paper not found'; END IF;

  v_doc_type := v_paper.source_type::text;

  IF v_paper.source_type = 'shop_order'::public.delivery_paper_source_type THEN
    SELECT
      nullif(trim(coalesce(o.name, o.order_no, '')), ''),
      nullif(trim(o.order_no), '')
    INTO v_document_name, v_shop_order_no
    FROM public.shop_orders o
    WHERE o.id = v_paper.source_id;
  ELSE
    SELECT nullif(trim(coalesce(f.name, '')), '')
    INTO v_document_name
    FROM public.product_based_costing_files f
    WHERE f.id = v_paper.source_id;
  END IF;

  SELECT pr.name INTO v_profile_name
  FROM public.profiles pr
  WHERE pr.id = v_paper.profile_id;

  v_items_payload := public.list_procurement_demand_group_items(
    p_tenant_id,
    v_doc_type,
    v_paper.source_id,
    null,
    500,
    null
  );

  v_items := coalesce(v_items_payload->'items', '[]'::jsonb);

  FOR i IN 0 .. coalesce(jsonb_array_length(v_items), 0) - 1 LOOP
    v_item := v_items->i;
    IF (v_item->>'preorder_demand_id') IS NULL THEN
      v_merged := v_merged || jsonb_build_array(v_item);
      CONTINUE;
    END IF;

    SELECT coalesce(
      jsonb_agg(
        jsonb_build_object(
          'line_id', pr.id,
          'client_key', ('dpl-' || pr.id::text),
          'global_stock_id', pr.global_stock_id,
          'quantity', pr.quantity,
          'close_action', public.delivery_paper_map_line_status_to_close_action(pr.status),
          'line_status', pr.status,
          'is_close_split', (pr.rn > 1),
          'shipment_name', pr.shipment_name,
          'location_name', pr.location_name
        )
        ORDER BY pr.id
      ),
      '[]'::jsonb
    )
    INTO v_paper_picks
    FROM (
      SELECT
        dpl.id,
        dpl.preorder_demand_id,
        dpl.global_stock_id,
        dpl.quantity,
        dpl.status,
        row_number() OVER (
          PARTITION BY dpl.preorder_demand_id, dpl.global_stock_id
          ORDER BY dpl.id
        ) AS rn,
        coalesce(nullif(trim(sh.name), ''), gsi.shipment_id::text) AS shipment_name,
        sl.name AS location_name
      FROM public.delivery_paper_line dpl
      LEFT JOIN public.global_stocks gs ON gs.id = dpl.global_stock_id
      LEFT JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
      LEFT JOIN public.global_shipments sh ON sh.id = gsi.shipment_id
      LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
      WHERE dpl.delivery_paper_id = p_delivery_paper_id
        AND dpl.preorder_demand_id = (v_item->>'preorder_demand_id')::bigint
    ) pr;

    v_merged := v_merged || jsonb_build_array(
      v_item || jsonb_build_object('paper_picks', coalesce(v_paper_picks, '[]'::jsonb))
    );
  END LOOP;

  RETURN jsonb_build_object(
    'paper', jsonb_build_object(
      'id', v_paper.id,
      'status', v_paper.status,
      'source_type', v_paper.source_type,
      'source_id', v_paper.source_id,
      'profile_id', v_paper.profile_id,
      'profile_name', v_profile_name,
      'document_name', v_document_name,
      'shop_order_no', v_shop_order_no,
      'created_at', v_paper.created_at,
      'updated_at', v_paper.updated_at,
      'delivery_date', v_paper.delivery_date,
      'note', v_paper.note
    ),
    'items', v_merged,
    'meta', coalesce(v_items_payload->'meta', '{}'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.save_delivery_paper_detail(
  p_tenant_id bigint,
  p_delivery_paper_id bigint,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_elem jsonb;
  v_pick jsonb;
  v_demand_id bigint;
  v_stock_id bigint;
  v_qty integer;
  v_close text;
  v_line_status public.delivery_paper_line_status;
  v_paper_status public.delivery_paper_status;
  v_line_count integer := 0;
  v_valid_demand boolean;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  SELECT * INTO v_paper FROM public.delivery_paper dp WHERE dp.id = p_delivery_paper_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'delivery paper not found'; END IF;
  IF v_paper.status <> 'draft'::public.delivery_paper_status THEN
    RAISE EXCEPTION 'only draft delivery papers can be edited';
  END IF;

  DELETE FROM public.delivery_paper_line dpl WHERE dpl.delivery_paper_id = p_delivery_paper_id;

  IF p_items IS NOT NULL AND jsonb_typeof(p_items) = 'array' THEN
    FOR v_elem IN SELECT value FROM jsonb_array_elements(p_items) LOOP
      v_demand_id := nullif(v_elem->>'preorder_demand_id', '')::bigint;
      IF v_demand_id IS NULL THEN CONTINUE; END IF;

      SELECT EXISTS (
        SELECT 1
        FROM public.preorder_demand pd
        WHERE pd.id = v_demand_id
          AND (
            (
              v_paper.source_type = 'shop_order'::public.delivery_paper_source_type
              AND pd.source_type = 'shop_order_item'::public.preorder_demand_source_type
              AND EXISTS (
                SELECT 1 FROM public.shop_order_items oi
                WHERE oi.id = pd.source_id AND oi.order_id = v_paper.source_id
              )
            )
            OR (
              v_paper.source_type = 'pbc_costing_file'::public.delivery_paper_source_type
              AND pd.source_type = 'pbc_costing_item'::public.preorder_demand_source_type
              AND EXISTS (
                SELECT 1 FROM public.product_based_costing_items pci
                WHERE pci.id = pd.source_id
                  AND pci.product_based_costing_file_id = v_paper.source_id
              )
            )
          )
      ) INTO v_valid_demand;

      IF NOT coalesce(v_valid_demand, false) THEN
        RAISE EXCEPTION 'invalid preorder_demand_id % for this paper', v_demand_id;
      END IF;

      FOR v_pick IN SELECT value FROM jsonb_array_elements(coalesce(v_elem->'picks', '[]'::jsonb)) LOOP
        v_stock_id := nullif(v_pick->>'global_stock_id', '')::bigint;
        v_qty := coalesce(nullif(v_pick->>'quantity', '')::integer, 0);
        IF v_stock_id IS NULL OR v_qty <= 0 THEN CONTINUE; END IF;

        v_close := lower(trim(coalesce(v_pick->>'close_action', '')));
        IF v_close IN ('take', 'condition', 'return') THEN
          v_line_status := public.map_stock_pick_close_to_delivery_line_status(v_close);
        ELSE
          v_line_status := 'packed'::public.delivery_paper_line_status;
        END IF;

        INSERT INTO public.delivery_paper_line (
          delivery_paper_id,
          preorder_demand_id,
          global_stock_id,
          quantity,
          status,
          note
        ) VALUES (
          p_delivery_paper_id,
          v_demand_id,
          v_stock_id,
          v_qty,
          v_line_status,
          nullif(trim(coalesce(v_pick->>'note', '')), '')
        );
        v_line_count := v_line_count + 1;
      END LOOP;
    END LOOP;
  END IF;

  -- Detail editor keeps header draft until dispatch workflow (lines may be packed).
  v_paper_status := 'draft'::public.delivery_paper_status;

  UPDATE public.delivery_paper dp
  SET status = v_paper_status, updated_at = now()
  WHERE dp.id = p_delivery_paper_id;

  RETURN jsonb_build_object('success', true, 'line_count', v_line_count, 'status', v_paper_status);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_delivery_paper_for_document(bigint, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_delivery_papers_for_document(bigint, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_delivery_paper_detail(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_delivery_paper_detail(bigint, bigint, jsonb) TO authenticated;

GRANT EXECUTE ON FUNCTION public.delivery_paper_assert_tenant_access(bigint) TO service_role;
GRANT EXECUTE ON FUNCTION public.delivery_paper_map_line_status_to_close_action(public.delivery_paper_line_status) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delivery_paper_document_allows_papers(text, bigint, bigint) TO service_role;

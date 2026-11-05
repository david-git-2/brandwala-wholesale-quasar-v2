-- Unit sell price on demand lines: first offer (non-negotiable) or final offer (negotiable).

CREATE OR REPLACE FUNCTION public.shop_order_item_delivery_sell_price(
  p_is_negotiable_snapshot boolean,
  p_staff_offer_amount numeric,
  p_final_price_amount numeric
)
RETURNS numeric(12, 2)
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN coalesce(p_is_negotiable_snapshot, false) THEN
      coalesce(p_final_price_amount, p_staff_offer_amount, 0)::numeric(12, 2)
    ELSE
      coalesce(p_staff_offer_amount, 0)::numeric(12, 2)
  END;
$$;

CREATE OR REPLACE FUNCTION public.apply_delivery_paper_outcome(
  p_tenant_id bigint,
  p_delivery_paper_id bigint,
  p_close_action text,
  p_allocations jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_close_action text := lower(trim(coalesce(p_close_action, '')));
  v_operating_tenant_id bigint;
  v_parent_tenant_id bigint;
  v_profile_id bigint;
  v_doc_type text;
  v_items jsonb := '[]'::jsonb;
  v_payload jsonb;
  v_result jsonb;
  v_invoice_id bigint;
  v_invoice_no text;
  v_elem jsonb;
  v_demand_id bigint;
  v_stock_id bigint;
  v_qty integer;
  v_grade_tag_id bigint;
  v_pick_count integer := 0;
  v_unit_count integer := 0;
  v_line public.delivery_paper_line%rowtype;
  v_sell_price numeric(12, 2);
  v_stock public.global_stocks%rowtype;
  v_outcome_status text;
  v_new_splits jsonb;
  v_global_invoice_id bigint;
  v_pbc_invoice_id bigint;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  IF p_delivery_paper_id IS NULL THEN
    RAISE EXCEPTION 'delivery_paper_id is required';
  END IF;

  IF v_close_action NOT IN ('take', 'condition', 'return') THEN
    RAISE EXCEPTION 'close_action must be take, condition, or return';
  END IF;

  IF p_allocations IS NULL OR jsonb_typeof(p_allocations) <> 'array' OR jsonb_array_length(p_allocations) = 0 THEN
    RAISE EXCEPTION 'allocations are required';
  END IF;

  SELECT * INTO v_paper
  FROM public.delivery_paper dp
  WHERE dp.id = p_delivery_paper_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper not found';
  END IF;

  IF v_paper.status NOT IN (
    'packed'::public.delivery_paper_status,
    'dispatched'::public.delivery_paper_status
  ) THEN
    RAISE EXCEPTION 'delivery paper must be packed or dispatched to apply outcome';
  END IF;

  v_profile_id := v_paper.profile_id;
  v_doc_type := v_paper.source_type::text;

  IF v_close_action IN ('take', 'condition') AND v_profile_id IS NULL THEN
    RAISE EXCEPTION 'profile_id is required on delivery paper';
  END IF;

  IF v_doc_type = 'shop_order' THEN
    SELECT o.tenant_id, o.global_invoice_id
    INTO v_operating_tenant_id, v_global_invoice_id
    FROM public.shop_orders o
    WHERE o.id = v_paper.source_id
      AND o.shop_type_snapshot = 'vendor_catalog';
    IF v_operating_tenant_id IS NULL THEN
      RAISE EXCEPTION 'shop order not found';
    END IF;
  ELSIF v_doc_type = 'pbc_costing_file' THEN
    SELECT f.tenant_id, f.invoice_id
    INTO v_operating_tenant_id, v_pbc_invoice_id
    FROM public.product_based_costing_files f
    WHERE f.id = v_paper.source_id;
    IF v_operating_tenant_id IS NULL THEN
      RAISE EXCEPTION 'costing file not found';
    END IF;
  ELSE
    RAISE EXCEPTION 'unsupported delivery paper source';
  END IF;

  SELECT coalesce(t.parent_id, t.id)
  INTO v_parent_tenant_id
  FROM public.tenants t
  WHERE t.id = v_operating_tenant_id;

  v_outcome_status := public.delivery_paper_close_action_to_split_status(v_close_action);

  FOR v_elem IN SELECT value FROM jsonb_array_elements(p_allocations) LOOP
    v_demand_id := nullif(v_elem->>'preorder_demand_id', '')::bigint;
    v_stock_id := nullif(v_elem->>'global_stock_id', '')::bigint;
    v_qty := coalesce(nullif(v_elem->>'quantity', '')::integer, 0);
    v_grade_tag_id := nullif(v_elem->>'grade_tag_id', '')::bigint;

    IF v_demand_id IS NULL OR v_stock_id IS NULL OR v_qty <= 0 THEN
      RAISE EXCEPTION 'each allocation requires preorder_demand_id, global_stock_id, and quantity';
    END IF;

    IF v_close_action = 'return' AND v_grade_tag_id IS NULL THEN
      RAISE EXCEPTION 'grade_tag_id is required for return allocations';
    END IF;

    SELECT dpl.* INTO v_line
    FROM public.delivery_paper_line dpl
    WHERE dpl.delivery_paper_id = p_delivery_paper_id
      AND dpl.preorder_demand_id = v_demand_id
      AND dpl.global_stock_id = v_stock_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'delivery paper line not found for demand % stock %', v_demand_id, v_stock_id;
    END IF;

    IF public.delivery_paper_line_packed_qty(v_line.splits) < v_qty THEN
      RAISE EXCEPTION 'insufficient packed qty on line %', v_line.id;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.preorder_demand pd
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
    ) THEN
      RAISE EXCEPTION 'invalid preorder_demand_id % for this paper', v_demand_id;
    END IF;

    IF v_doc_type = 'shop_order' THEN
      SELECT public.shop_order_item_delivery_sell_price(
        o.is_negotiable_snapshot,
        oi.staff_offer_amount,
        oi.final_price_amount
      )
      INTO v_sell_price
      FROM public.preorder_demand pd
      INNER JOIN public.shop_order_items oi ON oi.id = pd.source_id
      INNER JOIN public.shop_orders o ON o.id = oi.order_id
      WHERE pd.id = v_demand_id;
    ELSE
      SELECT coalesce(pci.offer_price, 0)::numeric(12, 2)
      INTO v_sell_price
      FROM public.preorder_demand pd
      INNER JOIN public.product_based_costing_items pci ON pci.id = pd.source_id
      WHERE pd.id = v_demand_id;
    END IF;

    IF v_close_action IN ('take', 'condition') THEN
      v_items := v_items || jsonb_build_array(jsonb_build_object(
        'global_stock_id', v_stock_id,
        'quantity', v_qty,
        'sell_price_amount', v_sell_price
      ));
    END IF;

    v_pick_count := v_pick_count + 1;
    v_unit_count := v_unit_count + v_qty;
  END LOOP;

  IF v_close_action IN ('take', 'condition') THEN
    v_payload := jsonb_build_object(
      'invoice', jsonb_build_object(
        'invoice_type', 'wholesale',
        'profile_id', v_profile_id,
        'channel_meta', jsonb_build_object('delivery_kind', v_close_action)
      ),
      'items', v_items,
      'issue', false
    );

    v_result := public.create_sales_invoice_from_payload(v_operating_tenant_id, v_payload);

    IF coalesce(v_result->>'success', 'false') <> 'true' THEN
      RAISE EXCEPTION '%', coalesce(v_result->>'error', 'failed to create close invoice');
    END IF;

    v_invoice_id := (v_result->>'invoice_id')::bigint;
    v_invoice_no := v_result->>'invoice_no';

    BEGIN
      UPDATE public.bills
      SET
        source_type = 'delivery_close',
        source_id = p_delivery_paper_id::text,
        source_key = v_close_action,
        settlement_kind = v_close_action::public.bill_settlement_kind,
        channel_meta = coalesce(channel_meta, '{}'::jsonb)
          || jsonb_build_object(
            'delivery_kind', v_close_action,
            'document_type', v_doc_type,
            'document_id', v_paper.source_id,
            'delivery_paper_id', p_delivery_paper_id
          ),
        updated_at = now()
      WHERE id = v_invoice_id;
    EXCEPTION
      WHEN unique_violation THEN
        UPDATE public.bills
        SET
          source_type = 'delivery_close',
          source_id = p_delivery_paper_id::text,
          source_key = v_close_action || ':' || v_invoice_id::text,
          settlement_kind = v_close_action::public.bill_settlement_kind,
          channel_meta = coalesce(channel_meta, '{}'::jsonb)
            || jsonb_build_object(
              'delivery_kind', v_close_action,
              'document_type', v_doc_type,
              'document_id', v_paper.source_id,
              'delivery_paper_id', p_delivery_paper_id
            ),
          updated_at = now()
        WHERE id = v_invoice_id;
    END;

    PERFORM public.stamp_bill_kernel_fields(v_invoice_id);

    IF v_doc_type = 'shop_order' AND v_close_action = 'take' AND v_global_invoice_id IS NULL THEN
      UPDATE public.shop_orders
      SET global_invoice_id = v_invoice_id, updated_at = now()
      WHERE id = v_paper.source_id AND global_invoice_id IS NULL;
    ELSIF v_doc_type = 'pbc_costing_file' AND v_close_action = 'take' AND v_pbc_invoice_id IS NULL THEN
      UPDATE public.product_based_costing_files
      SET invoice_id = v_invoice_id, updated_at = now()
      WHERE id = v_paper.source_id AND invoice_id IS NULL;
    END IF;
  END IF;

  FOR v_elem IN SELECT value FROM jsonb_array_elements(p_allocations) LOOP
    v_demand_id := nullif(v_elem->>'preorder_demand_id', '')::bigint;
    v_stock_id := nullif(v_elem->>'global_stock_id', '')::bigint;
    v_qty := coalesce(nullif(v_elem->>'quantity', '')::integer, 0);
    v_grade_tag_id := nullif(v_elem->>'grade_tag_id', '')::bigint;

    SELECT dpl.* INTO v_line
    FROM public.delivery_paper_line dpl
    WHERE dpl.delivery_paper_id = p_delivery_paper_id
      AND dpl.preorder_demand_id = v_demand_id
      AND dpl.global_stock_id = v_stock_id
    FOR UPDATE;

    IF v_close_action = 'return' THEN
      SELECT * INTO v_stock
      FROM public.global_stocks
      WHERE id = v_stock_id
        AND parent_tenant_id = v_parent_tenant_id
      FOR UPDATE;

      IF v_stock.id IS NULL THEN
        RAISE EXCEPTION 'stock % not found', v_stock_id;
      END IF;

      IF v_stock.availability = 'held'::public.stock_availability THEN
        PERFORM public.create_and_post_stock_movement(
          p_tenant_id => v_parent_tenant_id,
          p_stock_id => v_stock_id,
          p_quantity => v_qty,
          p_to_location_id => v_stock.location_id,
          p_to_availability => 'sellable'::public.stock_availability,
          p_to_grade_tag_id => v_grade_tag_id,
          p_movement_type => CASE
            WHEN v_grade_tag_id IS DISTINCT FROM coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id())
              THEN 'grade_change'::public.stock_movement_type
            ELSE 'availability_transfer'::public.stock_movement_type
          END,
          p_notes => 'Delivery paper reject return',
          p_reference_type => 'delivery_paper',
          p_reference_id => p_delivery_paper_id::text
        );
      ELSIF v_stock.availability = 'sellable'::public.stock_availability THEN
        IF v_grade_tag_id IS DISTINCT FROM coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id()) THEN
          PERFORM public.create_and_post_stock_movement(
            p_tenant_id => v_parent_tenant_id,
            p_stock_id => v_stock_id,
            p_quantity => v_qty,
            p_to_location_id => v_stock.location_id,
            p_to_availability => 'sellable'::public.stock_availability,
            p_to_grade_tag_id => v_grade_tag_id,
            p_movement_type => 'grade_change'::public.stock_movement_type,
            p_notes => 'Delivery paper reject return grade',
            p_reference_type => 'delivery_paper',
            p_reference_id => p_delivery_paper_id::text
          );
        END IF;
      ELSE
        RAISE EXCEPTION 'return requires held or sellable stock % (current: %)',
          v_stock_id, v_stock.availability;
      END IF;

      v_new_splits := public.delivery_paper_line_apply_outcome_from_packed(
        v_line.splits,
        v_qty,
        v_outcome_status,
        NULL,
        to_char(now() AT TIME ZONE 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
      );
    ELSE
      v_new_splits := public.delivery_paper_line_apply_outcome_from_packed(
        v_line.splits,
        v_qty,
        v_outcome_status,
        v_invoice_id,
        NULL
      );
    END IF;

    UPDATE public.delivery_paper_line dpl
    SET splits = v_new_splits, updated_at = now()
    WHERE dpl.id = v_line.id;
  END LOOP;

  UPDATE public.delivery_paper dp
  SET updated_at = now()
  WHERE dp.id = p_delivery_paper_id;

  RETURN jsonb_build_object(
    'success', true,
    'created', true,
    'close_action', v_close_action,
    'invoice_id', v_invoice_id,
    'invoice_no', v_invoice_no,
    'pick_count', v_pick_count,
    'unit_count', v_unit_count
  );
END;
$$;

-- Extend demand list items with unit_sell_price_amount for delivery paper UI.
CREATE OR REPLACE FUNCTION public.list_procurement_demand_group_items(
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
$$;

GRANT EXECUTE ON FUNCTION public.shop_order_item_delivery_sell_price(boolean, numeric, numeric) TO authenticated, service_role;

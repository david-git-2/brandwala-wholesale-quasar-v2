-- Paper-scoped accept / condition / reject from delivery_paper_line packed splits.

CREATE OR REPLACE FUNCTION public.delivery_paper_line_packed_qty(p_splits jsonb)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT coalesce(sum(greatest(0, (elem->>'quantity')::integer)), 0)::integer
  FROM jsonb_array_elements(coalesce(p_splits, '[]'::jsonb)) AS elem
  WHERE lower(trim(coalesce(elem->>'status', ''))) = 'packed';
$$;

CREATE OR REPLACE FUNCTION public.delivery_paper_line_apply_outcome_from_packed(
  p_splits jsonb,
  p_move_qty integer,
  p_outcome_status text,
  p_invoice_id bigint DEFAULT NULL,
  p_returned_at text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_elem jsonb;
  v_status text;
  v_qty integer;
  v_need integer;
  v_out jsonb := '[]'::jsonb;
  v_outcome_qty integer := 0;
  v_target text := lower(trim(p_outcome_status));
BEGIN
  IF p_move_qty <= 0 THEN
    RETURN coalesce(p_splits, '[]'::jsonb);
  END IF;

  IF p_move_qty > public.delivery_paper_line_packed_qty(p_splits) THEN
    RAISE EXCEPTION 'insufficient packed qty (have %, need %)',
      public.delivery_paper_line_packed_qty(p_splits), p_move_qty;
  END IF;

  v_need := p_move_qty;

  FOR v_elem IN
    SELECT value FROM jsonb_array_elements(coalesce(p_splits, '[]'::jsonb))
  LOOP
    v_status := lower(trim(coalesce(v_elem->>'status', '')));
    v_qty := greatest(0, coalesce((v_elem->>'quantity')::integer, 0));
    IF v_qty <= 0 THEN
      CONTINUE;
    END IF;

    IF v_status = v_target THEN
      v_outcome_qty := v_outcome_qty + v_qty;
      CONTINUE;
    END IF;

    IF v_status = 'packed' AND v_need > 0 THEN
      IF v_qty <= v_need THEN
        v_need := v_need - v_qty;
        CONTINUE;
      END IF;
      v_out := v_out || jsonb_build_array(
        v_elem || jsonb_build_object('quantity', v_qty - v_need)
      );
      v_need := 0;
    ELSE
      v_out := v_out || jsonb_build_array(v_elem);
    END IF;
  END LOOP;

  v_out := v_out || jsonb_build_array(
    jsonb_strip_nulls(jsonb_build_object(
      'quantity', p_move_qty + v_outcome_qty,
      'status', v_target,
      'invoice_id', p_invoice_id,
      'returned_at', p_returned_at
    ))
  );

  IF NOT public.validate_delivery_paper_line_splits(v_out) THEN
    RAISE EXCEPTION 'invalid splits after outcome apply';
  END IF;

  RETURN v_out;
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
      SELECT coalesce(oi.final_price_amount, oi.staff_offer_amount, 0)::numeric(12, 2)
      INTO v_sell_price
      FROM public.preorder_demand pd
      INNER JOIN public.shop_order_items oi ON oi.id = pd.source_id
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

GRANT EXECUTE ON FUNCTION public.apply_delivery_paper_outcome(bigint, bigint, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delivery_paper_line_packed_qty(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delivery_paper_line_apply_outcome_from_packed(jsonb, integer, text, bigint, text) TO authenticated, service_role;

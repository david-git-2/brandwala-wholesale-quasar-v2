-- Delivery paper Accept/Condition → money_kernel bills; desk bridge + wholesale issue
CREATE OR REPLACE FUNCTION public.apply_delivery_paper_outcome (
  p_tenant_id         bigint,
  p_delivery_paper_id bigint,
  p_close_action      text,
  p_allocations       jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'money_kernel'
  AS $function$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_close_action text := lower(trim(coalesce(p_close_action, '')));
  v_operating_tenant_id bigint;
  v_parent_tenant_id bigint;
  v_books_tenant_id bigint;
  v_tenant_self_profile bigint;
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
  v_bill_source_type text;
  v_bill_source_id text;
  v_bill_source_key text;
  v_bill_stock_id bigint;
  v_product_id bigint;
  v_name_snapshot text;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_shop_order_id bigint;
  v_order_no text;
  v_order_recipient_name text;
  v_order_recipient_phone text;
  v_order_shipping_address text;
  v_order_item_id bigint;
  v_shipment_item_id bigint;
  v_shipment_id bigint;
  v_shipment_ref jsonb;
  v_kernel_lines jsonb := '[]'::jsonb;
  v_line_item jsonb;
  v_line_desc text;
  v_bill_entity text;
  v_bill_note text;
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
    'dispatched'::public.delivery_paper_status,
    'delivered'::public.delivery_paper_status
  ) THEN
    RAISE EXCEPTION 'delivery paper must be packed, dispatched, or delivered to apply outcome';
  END IF;

  v_profile_id := v_paper.profile_id;
  v_doc_type := v_paper.source_type::text;

  IF v_close_action IN ('take', 'condition') AND v_profile_id IS NULL THEN
    RAISE EXCEPTION 'profile_id is required on delivery paper';
  END IF;

  IF v_doc_type = 'shop_order' THEN
    v_shop_order_id := v_paper.source_id;
    SELECT
      o.tenant_id,
      o.global_invoice_id,
      o.order_no,
      o.recipient_name,
      o.recipient_phone,
      o.shipping_address
    INTO
      v_operating_tenant_id,
      v_global_invoice_id,
      v_order_no,
      v_order_recipient_name,
      v_order_recipient_phone,
      v_order_shipping_address
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
    v_qty := coalesce(nullif(v_elem->>'quantity', '')::integer, 0);
    v_grade_tag_id := nullif(v_elem->>'grade_tag_id', '')::bigint;
    v_order_item_id := NULL;
    v_shipment_item_id := NULL;
    v_shipment_id := NULL;
    v_shipment_ref := '{}'::jsonb;

    IF v_qty <= 0 THEN
      RAISE EXCEPTION 'each allocation requires a positive quantity';
    END IF;

    IF v_close_action = 'return'
       AND nullif(v_elem->>'delivery_paper_line_id', '') IS NOT NULL THEN
      RAISE EXCEPTION 'return allocations require global_stock_id, not delivery_paper_line_id';
    END IF;

    IF v_close_action = 'return' AND v_grade_tag_id IS NULL THEN
      RAISE EXCEPTION 'grade_tag_id is required for return allocations';
    END IF;

    v_line := public.delivery_paper_line_lock_for_outcome(p_delivery_paper_id, v_elem);
    v_demand_id := v_line.preorder_demand_id;
    v_stock_id := coalesce(v_line.global_stock_id, v_line.dispatched_global_stock_id);

    IF v_close_action = 'return' AND v_stock_id IS NULL THEN
      RAISE EXCEPTION 'return requires a resolvable stock lot on delivery paper line %', v_line.id;
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
      v_bill_stock_id := public.delivery_paper_line_resolvable_bill_stock_id(v_line);
      IF v_bill_stock_id IS NOT NULL THEN
        SELECT gs.shipment_item_id, gsi.shipment_id
        INTO v_shipment_item_id, v_shipment_id
        FROM public.global_stocks gs
        LEFT JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
        WHERE gs.id = v_bill_stock_id;

        v_items := v_items || jsonb_build_array(jsonb_build_object(
          'global_stock_id', v_bill_stock_id,
          'quantity', v_qty,
          'sell_price_amount', v_sell_price,
          'shipment_item_id', v_shipment_item_id,
          'line_meta', CASE
            WHEN v_shipment_item_id IS NOT NULL THEN jsonb_build_object(
              'shipment_ref', jsonb_build_object(
                'shipment_item_id', v_shipment_item_id,
                'shipment_id', v_shipment_id
              )
            )
            ELSE '{}'::jsonb
          END
        ));
      ELSE
        v_product_id := NULL;
        v_name_snapshot := NULL;
        v_barcode_snapshot := NULL;
        v_product_code_snapshot := NULL;
        IF v_doc_type = 'shop_order' THEN
          SELECT
            oi.id,
            oi.product_id,
            coalesce(nullif(trim(oi.name), ''), nullif(trim(p.name), ''), 'Item'),
            nullif(trim(p.barcode), ''),
            nullif(trim(p.product_code), '')
          INTO
            v_order_item_id,
            v_product_id,
            v_name_snapshot,
            v_barcode_snapshot,
            v_product_code_snapshot
          FROM public.preorder_demand pd
          INNER JOIN public.shop_order_items oi ON oi.id = pd.source_id
          LEFT JOIN public.products p ON p.id = oi.product_id
          WHERE pd.id = v_demand_id;

          v_shipment_ref := public.resolve_shipment_item_for_shop_order_product(
            v_parent_tenant_id,
            v_order_item_id,
            v_product_id
          );
          v_shipment_item_id := nullif(v_shipment_ref ->> 'shipment_item_id', '')::bigint;
          v_shipment_id := nullif(v_shipment_ref ->> 'shipment_id', '')::bigint;
        ELSIF v_doc_type = 'pbc_costing_file' THEN
          SELECT
            pci.product_id,
            coalesce(nullif(trim(p.name), ''), 'Item'),
            nullif(trim(p.barcode), ''),
            nullif(trim(p.product_code), '')
          INTO
            v_product_id,
            v_name_snapshot,
            v_barcode_snapshot,
            v_product_code_snapshot
          FROM public.preorder_demand pd
          INNER JOIN public.product_based_costing_items pci ON pci.id = pd.source_id
          LEFT JOIN public.products p ON p.id = pci.product_id
          WHERE pd.id = v_demand_id;
        END IF;
        v_items := v_items || jsonb_build_array(jsonb_build_object(
          'quantity', v_qty,
          'sell_price_amount', v_sell_price,
          'product_id', v_product_id,
          'name_snapshot', coalesce(v_name_snapshot, 'Item'),
          'barcode_snapshot', v_barcode_snapshot,
          'product_code_snapshot', v_product_code_snapshot,
          'line_kind', 'stock',
          'shipment_item_id', v_shipment_item_id,
          'line_meta', CASE
            WHEN v_shipment_item_id IS NOT NULL THEN jsonb_build_object(
              'shipment_ref', jsonb_build_object(
                'shipment_item_id', v_shipment_item_id,
                'shipment_id', v_shipment_id
              )
            )
            ELSE '{}'::jsonb
          END
        ));
      END IF;
    END IF;

    v_pick_count := v_pick_count + 1;
    v_unit_count := v_unit_count + v_qty;
  END LOOP;

  IF v_close_action IN ('take', 'condition') THEN
  IF jsonb_array_length(v_items) = 0 THEN
    RAISE EXCEPTION 'no bill lines for take or condition';
  END IF;

    v_books_tenant_id := public.resolve_books_tenant_id(v_operating_tenant_id);
    v_tenant_self_profile := public._kernel_tenant_mirror_profile_id(v_books_tenant_id);
    IF v_tenant_self_profile IS NULL THEN
      RAISE EXCEPTION 'tenant profile required for wholesale bill';
    END IF;

    FOR v_line_item IN SELECT value FROM jsonb_array_elements(v_items) LOOP
      v_line_desc := nullif(trim(v_line_item->>'name_snapshot'), '');
      IF v_line_desc IS NULL
         AND nullif(v_line_item->>'global_stock_id', '') IS NOT NULL THEN
        SELECT coalesce(nullif(trim(gsi.name), ''), 'Item')
        INTO v_line_desc
        FROM public.global_stocks gs
        LEFT JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
        WHERE gs.id = nullif(v_line_item->>'global_stock_id', '')::bigint;
      END IF;
      v_line_desc := coalesce(v_line_desc, 'Item');

      v_kernel_lines := v_kernel_lines || jsonb_build_array(
        jsonb_build_object(
          'item_kind', 'stock',
          'description', v_line_desc,
          'quantity', coalesce((v_line_item->>'quantity')::numeric, 0),
          'unit_price', coalesce((v_line_item->>'sell_price_amount')::numeric, 0),
          'product_id', nullif(v_line_item->>'product_id', '')::bigint,
          'global_stock_id', nullif(v_line_item->>'global_stock_id', '')::bigint,
          'shipment_item_id', nullif(v_line_item->>'shipment_item_id', '')::bigint,
          'meta', coalesce(v_line_item->'line_meta', '{}'::jsonb)
            || CASE
              WHEN nullif(v_line_item->>'global_stock_id', '') IS NOT NULL THEN
                jsonb_build_object(
                  'stock_ref', jsonb_build_object(
                    'global_stock_id', nullif(v_line_item->>'global_stock_id', '')::bigint
                  )
                )
              ELSE '{}'::jsonb
            END
        )
      );
    END LOOP;

    IF v_doc_type = 'shop_order' THEN
      v_bill_source_type := 'shop_order';
      v_bill_source_id := v_paper.source_id::text;
      v_bill_source_key := format('delivery_paper:%s:%s', p_delivery_paper_id, v_close_action);
      v_bill_entity := 'public.shop_orders';
    ELSE
      v_bill_source_type := 'delivery_close';
      v_bill_source_id := p_delivery_paper_id::text;
      v_bill_source_key := v_close_action;
      v_bill_entity := 'public.delivery_paper';
    END IF;

    v_bill_note := CASE
      WHEN v_order_no IS NOT NULL THEN 'Delivery paper #' || p_delivery_paper_id::text || ' · ' || v_order_no
      ELSE 'Delivery paper #' || p_delivery_paper_id::text
    END;

    v_payload := jsonb_build_object(
      'tenant_id', v_books_tenant_id,
      'kind', 'sales_invoice_wholesale',
      'source_entity', v_bill_entity,
      'source_type', v_bill_source_type,
      'source_id', v_bill_source_id,
      'source_key', v_bill_source_key,
      'idempotency_key', format('delivery-paper-%s-%s', p_delivery_paper_id, v_close_action),
      'currency_code', 'BDT',
      'from_profile_id', v_profile_id,
      'to_profile_id', v_tenant_self_profile,
      'counterparty_profile_id', v_profile_id,
      'note', v_bill_note,
      'meta', jsonb_build_object(
        'delivery_kind', v_close_action,
        'document_type', v_doc_type,
        'document_id', v_paper.source_id,
        'delivery_paper_id', p_delivery_paper_id,
        'shop_order_id', v_shop_order_id
      ),
      'lines', v_kernel_lines
    );

    v_result := public.rpc_create_bill(v_payload);
    v_invoice_id := nullif(v_result->>'bill_id', '')::bigint;
    v_invoice_no := v_result->>'invoice_no';

    IF v_invoice_id IS NULL THEN
      RAISE EXCEPTION 'rpc_create_bill returned no bill_id';
    END IF;

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
    v_qty := coalesce(nullif(v_elem->>'quantity', '')::integer, 0);
    v_grade_tag_id := nullif(v_elem->>'grade_tag_id', '')::bigint;

    v_line := public.delivery_paper_line_lock_for_outcome(p_delivery_paper_id, v_elem);
    v_demand_id := v_line.preorder_demand_id;
    v_stock_id := coalesce(v_line.global_stock_id, v_line.dispatched_global_stock_id);

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


  FOR v_demand_id IN
    SELECT DISTINCT nullif(elem->>'preorder_demand_id', '')::bigint AS demand_id
    FROM jsonb_array_elements(p_allocations) AS elem
    WHERE nullif(elem->>'preorder_demand_id', '') IS NOT NULL
  LOOP
    SELECT coalesce(sum(greatest(0, coalesce(nullif(elem->>'quantity', '')::integer, 0))), 0)::integer
    INTO v_qty
    FROM jsonb_array_elements(p_allocations) AS elem
    WHERE nullif(elem->>'preorder_demand_id', '')::bigint = v_demand_id;

    IF v_qty > 0 THEN
      PERFORM public.delivery_paper_line_reduce_null_plan_splits(
        p_delivery_paper_id,
        v_demand_id,
        v_outcome_status,
        v_qty
      );
    END IF;
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
$function$;

GRANT ALL ON FUNCTION public.apply_delivery_paper_outcome(bigint, bigint, text, jsonb) TO anon;

GRANT ALL ON FUNCTION public.apply_delivery_paper_outcome(bigint, bigint, text, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.apply_delivery_paper_outcome(bigint, bigint, text, jsonb) TO service_role;
CREATE OR REPLACE FUNCTION public.get_delivery_paper_detail (
  p_tenant_id         bigint,
  p_delivery_paper_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public', 'money_kernel'
  AS $function$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_doc_type text;
  v_document_name text;
  v_shop_order_no text;
  v_profile_name text;
  v_books_tenant_id bigint;
  v_close_bills jsonb := '[]'::jsonb;
  v_items_payload jsonb;
  v_items jsonb := '[]'::jsonb;
  v_item jsonb;
  v_paper_picks jsonb;
  v_merged jsonb := '[]'::jsonb;
  v_packed_other integer;
  v_remaining_to_pack integer;
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

  v_books_tenant_id := public.resolve_books_tenant_id(p_tenant_id);

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', row_data.bill_id,
        'invoice_no', row_data.invoice_no,
        'invoice_status', row_data.invoice_status,
        'settlement_kind', row_data.settlement_kind
      )
      ORDER BY row_data.bill_id
    ),
    '[]'::jsonb
  )
  INTO v_close_bills
  FROM (
    SELECT
      b.id AS bill_id,
      b.invoice_no,
      b.invoice_status::text AS invoice_status,
      b.settlement_kind::text AS settlement_kind
    FROM public.bills b
    WHERE (
      (b.source_type = 'delivery_close' AND b.source_id = p_delivery_paper_id::text)
      OR (
        b.source_type = 'shop_order'
        AND coalesce(b.source_key, '') LIKE ('delivery_paper:' || p_delivery_paper_id::text || ':%')
      )
    )
    UNION ALL
    SELECT
      kb.id AS bill_id,
      kb.invoice_no,
      CASE kb.status
        WHEN 'draft' THEN 'draft'
        WHEN 'voided' THEN 'voided'
        ELSE 'issued'
      END AS invoice_status,
      coalesce(
        nullif(kb.meta->>'delivery_kind', ''),
        split_part(coalesce(kb.source_key, ''), ':', 3)
      ) AS settlement_kind
    FROM money_kernel.bills kb
    WHERE kb.tenant_id = v_books_tenant_id
      AND kb.status <> 'voided'
      AND (
        (kb.source_type = 'delivery_close' AND kb.source_id = p_delivery_paper_id::text)
        OR (
          kb.source_type = 'shop_order'
          AND coalesce(kb.source_key, '') LIKE ('delivery_paper:' || p_delivery_paper_id::text || ':%')
        )
      )
  ) AS row_data;

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
          'line_id', pr.line_id,
          'client_key', pr.client_key,
          'global_stock_id', pr.global_stock_id,
          'quantity', pr.quantity,
          'close_action', public.delivery_paper_map_line_status_to_close_action(
            pr.line_status::public.delivery_paper_line_status
          ),
          'line_status', pr.line_status,
          'is_close_split', pr.is_close_split,
          'shipment_name', pr.shipment_name,
          'location_name', pr.location_name,
          'invoice_id', pr.invoice_id,
          'returned_at', pr.returned_at,
          'is_applied', pr.is_applied
        )
        ORDER BY pr.line_id, pr.split_ord
      ),
      '[]'::jsonb
    )
    INTO v_paper_picks
    FROM (
      SELECT
        dpl.id AS line_id,
        ('dpl-' || dpl.id::text || '-' || split.ord::text) AS client_key,
        public.delivery_paper_line_resolvable_bill_stock_id(dpl) AS global_stock_id,
        (split.elem->>'quantity')::integer AS quantity,
        split.elem->>'status' AS line_status,
        (split.ord > 1) AS is_close_split,
        coalesce(nullif(trim(sh.name), ''), gsi.shipment_id::text) AS shipment_name,
        sl.name AS location_name,
        nullif(split.elem->>'invoice_id', '')::bigint AS invoice_id,
        nullif(split.elem->>'returned_at', '') AS returned_at,
        (
          nullif(split.elem->>'invoice_id', '') IS NOT NULL
          OR nullif(split.elem->>'returned_at', '') IS NOT NULL
        ) AS is_applied,
        split.ord AS split_ord
      FROM public.delivery_paper_line dpl
      LEFT JOIN public.global_stocks gs
        ON gs.id = public.delivery_paper_line_resolvable_bill_stock_id(dpl)
      LEFT JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
      LEFT JOIN public.global_shipments sh ON sh.id = gsi.shipment_id
      LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
      CROSS JOIN LATERAL jsonb_array_elements(dpl.splits) WITH ORDINALITY AS split(elem, ord)
      WHERE dpl.delivery_paper_id = p_delivery_paper_id
        AND dpl.preorder_demand_id = (v_item->>'preorder_demand_id')::bigint
    ) pr;

    v_packed_other := public.preorder_demand_packed_on_delivery_papers(
      (v_item->>'preorder_demand_id')::bigint,
      v_paper.source_type,
      v_paper.source_id,
      p_delivery_paper_id
    );

    v_remaining_to_pack := greatest(
      coalesce((v_item->>'remaining_to_deliver')::integer, 0) - v_packed_other,
      0
    );

    v_merged := v_merged || jsonb_build_array(
      v_item || jsonb_build_object(
        'paper_picks', coalesce(v_paper_picks, '[]'::jsonb),
        'packed_on_other_delivery_papers', v_packed_other,
        'remaining_to_pack', v_remaining_to_pack
      )
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
      'note', v_paper.note,
      'close_bills', v_close_bills
    ),
    'items', v_merged,
    'meta', coalesce(v_items_payload->'meta', '{}'::jsonb)
  );
END;
$function$;

GRANT ALL ON FUNCTION public.get_delivery_paper_detail(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_delivery_paper_detail(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_delivery_paper_detail(bigint, bigint) TO service_role;

CREATE OR REPLACE FUNCTION public._desk_kernel_kind_invoice_type(p_kind text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_kind IN ('shipment_cost_ap', 'dropship_courier_ap') THEN 'ap'
    WHEN p_kind = 'sales_invoice_wholesale' THEN 'wholesale'
    WHEN p_kind = 'sales_invoice_retail' THEN 'retail'
    WHEN p_kind = 'sales_invoice_dropship' THEN 'dropship'
    WHEN p_kind LIKE 'sales_invoice_%' THEN 'wholesale'
    WHEN p_kind IN ('credit_note', 'debit_note') THEN 'ar'
    ELSE 'ap'
  END;
$$;

CREATE OR REPLACE FUNCTION public._get_bill_detail_bundle_from_kernel(
  p_tenant_id bigint,
  p_bill_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent_id bigint;
  v_b money_kernel.bills;
  v_invoice_type text;
  v_invoice_status text;
  v_payment_status text;
  v_bill_json jsonb;
  v_bill_lines jsonb := '[]'::jsonb;
  v_adjustments jsonb := '[]'::jsonb;
  v_ap_kind text;
BEGIN
  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  IF NOT (
    public.user_can_manage_books_tenant(v_parent_id)
    OR public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  SELECT * INTO v_b
  FROM money_kernel.bills
  WHERE id = p_bill_id AND tenant_id = v_parent_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;

  v_invoice_type := public._desk_kernel_kind_invoice_type(v_b.kind);
  v_invoice_status := CASE v_b.status
    WHEN 'draft' THEN 'draft'
    WHEN 'voided' THEN 'voided'
    WHEN 'proforma_generated' THEN 'draft'
    ELSE 'issued'
  END;
  v_payment_status := public._desk_kernel_status_payment(v_b.status, v_b.due_amount);
  v_ap_kind := COALESCE(v_b.meta->>'ap_kind', NULL);

  v_bill_json := jsonb_build_object(
    'id', v_b.id,
    'tenant_id', v_b.tenant_id,
    'invoice_no', v_b.invoice_no,
    'invoice_date', v_b.invoice_date,
    'due_date', v_b.due_date,
    'invoice_type', v_invoice_type,
    'invoice_status', v_invoice_status,
    'payment_status', v_payment_status,
    'document_kind', CASE v_b.kind WHEN 'credit_note' THEN 'credit_note' WHEN 'debit_note' THEN 'debit_note' ELSE 'standard' END,
    'total_amount', v_b.total_amount,
    'due_amount', v_b.due_amount,
    'paid_amount', v_b.paid_amount,
    'currency_code', v_b.currency_code,
    'from_profile_id', v_b.from_profile_id,
    'to_profile_id', v_b.to_profile_id,
    'profile_id', v_b.counterparty_profile_id,
    'source_type', v_b.source_type,
    'source_id', v_b.source_id,
    'source_key', v_b.source_key,
    'parent_bill_id', v_b.parent_bill_id,
    'ap_kind', v_ap_kind,
    'channel_meta', coalesce(v_b.meta, '{}'::jsonb) || jsonb_build_object('money_kernel_v2', true),
    'settlement_kind', nullif(v_b.meta->>'delivery_kind', ''),
    'note', v_b.note,
    'spine', 'kernel',
    'kernel_kind', v_b.kind
  )
  || jsonb_build_object(
    'profiles', public._desk_profile_json_public(v_b.counterparty_profile_id),
    'from_profile', public._desk_profile_json_public(v_b.from_profile_id),
    'to_profile', public._desk_profile_json_public(v_b.to_profile_id)
  );

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', bl.id,
      'name_snapshot', COALESCE(bl.description, 'Line'),
      'currency_code', upper(v_b.currency_code),
      'line_total_amount', bl.line_total,
      'books_amount', bl.line_total,
      'quantity', bl.quantity,
      'sell_price_amount', bl.unit_price,
      'global_stock_id', bl.global_stock_id,
      'product_id', bl.product_id,
      'shipment_item_id', bl.shipment_item_id
    )
    ORDER BY bl.line_no
  ), '[]'::jsonb)
  INTO v_bill_lines
  FROM money_kernel.bill_lines bl
  WHERE bl.bill_id = p_bill_id AND bl.tenant_id = v_parent_id;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'invoice_no', c.invoice_no,
      'document_kind', c.kind,
      'invoice_status', c.status,
      'total_amount', c.total_amount
    )
    ORDER BY c.id
  ), '[]'::jsonb)
  INTO v_adjustments
  FROM money_kernel.bills c
  WHERE c.parent_bill_id = p_bill_id
    AND c.tenant_id = v_parent_id
    AND c.kind IN ('credit_note', 'debit_note')
    AND c.status <> 'voided';

  RETURN jsonb_build_object(
    'bill', v_bill_json,
    'payment_history', public._desk_kernel_payment_history_json(v_parent_id, p_bill_id),
    'net_balances', public._desk_kernel_net_balances_json(p_bill_id),
    'adjustments', v_adjustments,
    'stock_items', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', bl.id,
          'global_stock_id', bl.global_stock_id,
          'quantity', bl.quantity,
          'sell_price_amount', bl.unit_price
        )
        ORDER BY bl.line_no
      )
      FROM money_kernel.bill_lines bl
      WHERE bl.bill_id = p_bill_id
        AND bl.tenant_id = v_parent_id
        AND bl.global_stock_id IS NOT NULL
        AND bl.quantity > 0
    ), '[]'::jsonb),
    'bill_lines', v_bill_lines,
    'pay_cashbook_legs', public._desk_bill_pay_cashbook_legs_json(
      p_tenant_id,
      v_invoice_type,
      v_b.from_profile_id,
      v_b.to_profile_id,
      v_b.currency_code
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.issue_wholesale_bill(
  p_bill_id bigint,
  p_items jsonb DEFAULT NULL
)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, money_kernel, pg_temp
AS $$
DECLARE
  v_invoice public.bills;
  v_kernel money_kernel.bills;
BEGIN
  SELECT * INTO v_invoice FROM public.bills WHERE id = p_bill_id FOR UPDATE;
  IF FOUND THEN
    PERFORM public.commit_wholesale_bill_stock(p_bill_id);
    RETURN public._kernel_issue_wholesale_stock(p_bill_id, p_items);
  END IF;

  SELECT * INTO v_kernel
  FROM money_kernel.bills
  WHERE id = p_bill_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;

  IF v_kernel.kind NOT IN ('sales_invoice_wholesale', 'sales_invoice_dropship') THEN
    RAISE EXCEPTION 'Only wholesale sales bills can be issued via issue_wholesale_bill';
  END IF;

  IF v_kernel.status IS DISTINCT FROM 'draft' THEN
    RAISE EXCEPTION 'Only draft bills can be issued';
  END IF;

  IF NOT public.user_can_manage_books_tenant(v_kernel.tenant_id) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  PERFORM public.commit_wholesale_bill_stock(p_bill_id);
  PERFORM public.rpc_issue_bill(v_kernel.tenant_id, p_bill_id);

  SELECT * INTO v_kernel FROM money_kernel.bills WHERE id = p_bill_id;

  v_invoice.id := v_kernel.id;
  v_invoice.tenant_id := v_kernel.tenant_id;
  v_invoice.parent_tenant_id := v_kernel.tenant_id;
  v_invoice.issued_by_tenant_id := v_kernel.tenant_id;
  v_invoice.invoice_type := CASE v_kernel.kind
    WHEN 'sales_invoice_dropship' THEN 'dropship'::public.global_invoice_type
    ELSE 'wholesale'::public.global_invoice_type
  END;
  v_invoice.invoice_status := 'issued'::public.global_invoice_status;
  v_invoice.payment_status := public._desk_kernel_status_payment(v_kernel.status, v_kernel.due_amount)::public.global_payment_status;
  v_invoice.document_kind := 'standard'::public.bill_document_kind;
  v_invoice.invoice_no := v_kernel.invoice_no;
  v_invoice.invoice_date := v_kernel.invoice_date;
  v_invoice.due_date := v_kernel.due_date;
  v_invoice.total_amount := v_kernel.total_amount;
  v_invoice.due_amount := v_kernel.due_amount;
  v_invoice.paid_amount := coalesce(v_kernel.paid_amount, 0);
  v_invoice.from_profile_id := v_kernel.from_profile_id;
  v_invoice.to_profile_id := v_kernel.to_profile_id;
  v_invoice.profile_id := v_kernel.counterparty_profile_id;
  v_invoice.source_type := v_kernel.source_type;
  v_invoice.source_id := v_kernel.source_id;
  v_invoice.source_key := v_kernel.source_key;
  v_invoice.currency_code := v_kernel.currency_code;
  v_invoice.note := v_kernel.note;

  RETURN v_invoice;
END;
$$;

CREATE OR REPLACE FUNCTION public.commit_sales_bill_stock(p_bill_id bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, money_kernel
AS $$
declare
  v_invoice public.bills;
  v_kernel money_kernel.bills;
  v_db_item public.bill_lines%rowtype;
  v_kline money_kernel.bill_lines%rowtype;
  v_stock_id bigint;
  v_qty integer;
  v_stock record;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_has_stock boolean := false;
  v_delivery_paper_id bigint;
  v_skip_deduct boolean;
  v_line_label text;
  v_is_dropship boolean := false;
begin
  select * into v_invoice from public.bills where id = p_bill_id for update;

  if v_invoice.id is not null then
    if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
      raise exception 'Only draft or proforma invoices can commit stock';
    end if;

    v_parent_id := coalesce(v_invoice.tenant_id, v_invoice.issued_by_tenant_id);
    v_delivery_paper_id := nullif(trim(coalesce(v_invoice.channel_meta->>'delivery_paper_id', '')), '')::bigint;
    v_is_dropship := v_invoice.invoice_type = 'dropship'::public.global_invoice_type;
  else
    select * into v_kernel from money_kernel.bills where id = p_bill_id for update;
    if not found then
      raise exception 'Invoice not found';
    end if;
    if v_kernel.status not in ('draft') then
      raise exception 'Only draft bills can commit stock';
    end if;

    v_parent_id := v_kernel.tenant_id;
    v_delivery_paper_id := nullif(trim(coalesce(v_kernel.meta->>'delivery_paper_id', '')), '')::bigint;
    v_is_dropship := v_kernel.kind = 'sales_invoice_dropship';
  end if;

  select sm.id
  into v_mov_id
  from public.stock_movements sm
  where sm.reference_type = 'sales_invoice'
    and sm.reference_id = p_bill_id::text
    and sm.is_posted = true
  order by sm.id desc
  limit 1;

  if v_mov_id is not null then
    return v_mov_id;
  end if;

  if v_invoice.id is not null then
    select exists (
      select 1
      from public.bill_lines bl
      where bl.invoice_id = p_bill_id
        and public._bill_line_global_stock_id(bl) is not null
    ) into v_has_stock;
  else
    select exists (
      select 1
      from money_kernel.bill_lines bl
      where bl.bill_id = p_bill_id
        and bl.global_stock_id is not null
    ) into v_has_stock;
  end if;

  if not v_has_stock then
    return null;
  end if;

  v_mov_no := public.next_stock_movement_number(v_parent_id, 'stock_movement');

  insert into public.stock_movements (
    tenant_id,
    movement_no,
    movement_type,
    reference_type,
    reference_id,
    notes,
    created_by_email,
    is_posted,
    posted_at
  ) values (
    v_parent_id,
    v_mov_no,
    'adjustment'::public.stock_movement_type,
    'sales_invoice',
    p_bill_id::text,
    'Issued sales invoice #' || coalesce(
      case when v_invoice.id is not null then v_invoice.invoice_no else v_kernel.invoice_no end,
      p_bill_id::text
    ),
    public.current_user_email(),
    true,
    now()
  ) returning id into v_mov_id;

  if v_invoice.id is not null then
    for v_db_item in select * from public.bill_lines where invoice_id = p_bill_id loop
      v_stock_id := public._bill_line_global_stock_id(v_db_item);
      if v_stock_id is null then
        continue;
      end if;

      v_qty := ceil(v_db_item.quantity)::integer;
      v_line_label := v_db_item.name_snapshot;

      select * into v_stock from public.global_stocks where id = v_stock_id for update;
      if v_stock.id is null then
        raise exception 'Stock % not found for line %', v_stock_id, v_line_label;
      end if;

      if v_is_dropship and v_stock.availability <> 'held'::public.stock_availability then
        raise exception 'dropship invoice stock % must be held before issue', v_stock_id;
      end if;

      v_skip_deduct := (
        v_delivery_paper_id is not null
        and public.stock_dispatch_deduct_covers(v_delivery_paper_id, v_stock_id, v_qty)
      );

      if v_skip_deduct then
        insert into public.stock_movement_lines (
          movement_id, stock_id, quantity,
          from_location_id, to_location_id, from_availability, to_availability
        ) values (
          v_mov_id, v_stock_id, v_qty,
          v_stock.location_id, v_stock.location_id,
          v_stock.availability, v_stock.availability
        );
        continue;
      end if;

      if v_stock.quantity < v_qty then
        raise exception 'Insufficient stock for % (requested %, available %)', v_line_label, v_qty, v_stock.quantity;
      end if;

      update public.global_stocks
      set quantity = quantity - v_qty
      where id = v_stock_id;

      insert into public.stock_movement_lines (
        movement_id, stock_id, quantity,
        from_location_id, to_location_id, from_availability, to_availability
      ) values (
        v_mov_id, v_stock_id, v_qty,
        v_stock.location_id, v_stock.location_id,
        v_stock.availability, v_stock.availability
      );
    end loop;
  else
    for v_kline in
      select * from money_kernel.bill_lines
      where bill_id = p_bill_id and global_stock_id is not null
    loop
      v_stock_id := v_kline.global_stock_id;
      v_qty := ceil(v_kline.quantity)::integer;
      v_line_label := coalesce(v_kline.description, 'Line');

      select * into v_stock from public.global_stocks where id = v_stock_id for update;
      if v_stock.id is null then
        raise exception 'Stock % not found for line %', v_stock_id, v_line_label;
      end if;

      if v_is_dropship and v_stock.availability <> 'held'::public.stock_availability then
        raise exception 'dropship invoice stock % must be held before issue', v_stock_id;
      end if;

      v_skip_deduct := (
        v_delivery_paper_id is not null
        and public.stock_dispatch_deduct_covers(v_delivery_paper_id, v_stock_id, v_qty)
      );

      if v_skip_deduct then
        insert into public.stock_movement_lines (
          movement_id, stock_id, quantity,
          from_location_id, to_location_id, from_availability, to_availability
        ) values (
          v_mov_id, v_stock_id, v_qty,
          v_stock.location_id, v_stock.location_id,
          v_stock.availability, v_stock.availability
        );
        continue;
      end if;

      if v_stock.quantity < v_qty then
        raise exception 'Insufficient stock for % (requested %, available %)', v_line_label, v_qty, v_stock.quantity;
      end if;

      update public.global_stocks
      set quantity = quantity - v_qty
      where id = v_stock_id;

      insert into public.stock_movement_lines (
        movement_id, stock_id, quantity,
        from_location_id, to_location_id, from_availability, to_availability
      ) values (
        v_mov_id, v_stock_id, v_qty,
        v_stock.location_id, v_stock.location_id,
        v_stock.availability, v_stock.availability
      );
    end loop;
  end if;

  return v_mov_id;
end;
$$;

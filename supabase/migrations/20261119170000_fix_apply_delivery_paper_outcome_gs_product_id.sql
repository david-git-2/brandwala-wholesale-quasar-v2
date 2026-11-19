-- Fix product_id source: global_stocks has no product_id; use global_shipment_items via join.
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
  v_kernel_item_kind text;
  v_kernel_stock_id bigint;
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
      o.order_no,
      o.recipient_name,
      o.recipient_phone,
      o.shipping_address
    INTO
      v_operating_tenant_id,
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
    SELECT f.tenant_id
    INTO v_operating_tenant_id
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
        oi.final_price_amount,
        oi.unit_sell_price_amount,
        oi.customer_sell_price_amount,
        oi.unit_list_price_amount
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
        SELECT gs.shipment_item_id, gsi.shipment_id, gsi.product_id
        INTO v_shipment_item_id, v_shipment_id, v_product_id
        FROM public.global_stocks gs
        LEFT JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
        WHERE gs.id = v_bill_stock_id;

        IF v_shipment_item_id IS NULL AND v_doc_type = 'shop_order' THEN
          SELECT oi.product_id
          INTO v_product_id
          FROM public.preorder_demand pd
          INNER JOIN public.shop_order_items oi ON oi.id = pd.source_id
          WHERE pd.id = v_demand_id;

          IF v_product_id IS NOT NULL AND v_line.unit_cost_landed_snapshot IS NOT NULL THEN
            SELECT gsi.id, gsi.shipment_id
            INTO v_shipment_item_id, v_shipment_id
            FROM public.global_shipment_items gsi
            WHERE gsi.tenant_id = v_parent_tenant_id
              AND gsi.product_id = v_product_id
              AND gsi.landed_cost_bdt = v_line.unit_cost_landed_snapshot
            ORDER BY gsi.shipment_id DESC, gsi.id DESC
            LIMIT 1;
          END IF;

          IF v_shipment_item_id IS NULL AND v_product_id IS NOT NULL THEN
            v_shipment_ref := public.resolve_shipment_item_for_shop_order_product(
              v_books_tenant_id,
              NULL,
              v_product_id
            );
            v_shipment_item_id := nullif(v_shipment_ref ->> 'shipment_item_id', '')::bigint;
            v_shipment_id := nullif(v_shipment_ref ->> 'shipment_id', '')::bigint;
          END IF;
        END IF;

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

      v_kernel_stock_id := nullif(v_line_item->>'global_stock_id', '')::bigint;
      v_shipment_item_id := nullif(v_line_item->>'shipment_item_id', '')::bigint;
      v_shipment_id := nullif(v_line_item->'line_meta'->'shipment_ref'->>'shipment_id', '')::bigint;
      IF v_shipment_item_id IS NULL THEN
        v_shipment_item_id := nullif(
          v_line_item->'line_meta'->'shipment_ref'->>'shipment_item_id',
          ''
        )::bigint;
      END IF;
      v_product_id := nullif(v_line_item->>'product_id', '')::bigint;

      IF v_kernel_stock_id IS NOT NULL
         AND (v_shipment_item_id IS NULL OR v_shipment_id IS NULL) THEN
        SELECT
          coalesce(v_shipment_item_id, gs.shipment_item_id),
          coalesce(v_shipment_id, gsi.shipment_id),
          coalesce(v_product_id, gsi.product_id)
        INTO v_shipment_item_id, v_shipment_id, v_product_id
        FROM public.global_stocks gs
        LEFT JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
        WHERE gs.id = v_kernel_stock_id;
      END IF;

      IF v_shipment_item_id IS NULL AND v_product_id IS NOT NULL THEN
        v_shipment_ref := public.resolve_shipment_item_for_shop_order_product(
          v_books_tenant_id,
          NULL,
          v_product_id
        );
        v_shipment_item_id := nullif(v_shipment_ref ->> 'shipment_item_id', '')::bigint;
        v_shipment_id := coalesce(
          v_shipment_id,
          nullif(v_shipment_ref ->> 'shipment_id', '')::bigint
        );
      END IF;

      v_kernel_item_kind := CASE
        WHEN v_kernel_stock_id IS NOT NULL AND v_shipment_item_id IS NOT NULL THEN 'stock'
        ELSE 'charge'
      END;

      v_kernel_lines := v_kernel_lines || jsonb_build_array(
        jsonb_build_object(
          'item_kind', v_kernel_item_kind,
          'description', v_line_desc,
          'quantity', coalesce((v_line_item->>'quantity')::numeric, 0),
          'unit_price', coalesce((v_line_item->>'sell_price_amount')::numeric, 0),
          'product_id', v_product_id,
          'global_stock_id', v_kernel_stock_id,
          'shipment_item_id', v_shipment_item_id,
          'shipment_id', v_shipment_id,
          'meta', coalesce(v_line_item->'line_meta', '{}'::jsonb)
            || CASE
              WHEN v_kernel_stock_id IS NOT NULL THEN
                jsonb_build_object(
                  'stock_ref', jsonb_build_object(
                    'global_stock_id', v_kernel_stock_id
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
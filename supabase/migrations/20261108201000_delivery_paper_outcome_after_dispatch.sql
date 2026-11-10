-- Lot lines keep identity after dispatch; outcome save must not wipe packed splits.
ALTER TABLE public.delivery_paper_line
  ADD COLUMN IF NOT EXISTS dispatched_global_stock_id bigint;

DROP INDEX IF EXISTS public.delivery_paper_line_paper_demand_no_stock_uidx;

CREATE UNIQUE INDEX delivery_paper_line_paper_demand_no_stock_uidx
  ON public.delivery_paper_line (delivery_paper_id, preorder_demand_id)
  WHERE global_stock_id IS NULL AND dispatched_global_stock_id IS NULL;

CREATE OR REPLACE FUNCTION public.delivery_paper_line_lock_for_outcome (
  p_delivery_paper_id  bigint,
  p_allocation         jsonb
)
  RETURNS public.delivery_paper_line
  LANGUAGE plpgsql
  AS $function$
DECLARE
  v_line public.delivery_paper_line%rowtype;
  v_line_id bigint;
  v_demand_id bigint;
  v_stock_id bigint;
BEGIN
  v_line_id := nullif(p_allocation->>'delivery_paper_line_id', '')::bigint;
  v_demand_id := nullif(p_allocation->>'preorder_demand_id', '')::bigint;
  v_stock_id := nullif(p_allocation->>'global_stock_id', '')::bigint;

  IF v_line_id IS NOT NULL THEN
    SELECT * INTO v_line
    FROM public.delivery_paper_line dpl
    WHERE dpl.id = v_line_id
      AND dpl.delivery_paper_id = p_delivery_paper_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'delivery paper line % not found', v_line_id;
    END IF;

    IF v_demand_id IS NOT NULL AND v_line.preorder_demand_id IS DISTINCT FROM v_demand_id THEN
      RAISE EXCEPTION 'delivery_paper_line_id % does not match preorder_demand_id', v_line_id;
    END IF;

    RETURN v_line;
  END IF;

  IF v_demand_id IS NULL OR v_stock_id IS NULL THEN
    RAISE EXCEPTION 'each allocation requires delivery_paper_line_id or preorder_demand_id with global_stock_id';
  END IF;

  SELECT * INTO v_line
  FROM public.delivery_paper_line dpl
  WHERE dpl.delivery_paper_id = p_delivery_paper_id
    AND dpl.preorder_demand_id = v_demand_id
    AND (
      dpl.global_stock_id = v_stock_id
      OR dpl.dispatched_global_stock_id = v_stock_id
    )
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper line not found for demand % stock %', v_demand_id, v_stock_id;
  END IF;

  RETURN v_line;
END;
$function$;

GRANT ALL ON FUNCTION public.delivery_paper_line_lock_for_outcome(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.delivery_paper_line_lock_for_outcome(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.delivery_paper_line_lock_for_outcome(bigint, jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.dispatch_delivery_paper (
  p_tenant_id         bigint,
  p_delivery_paper_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_line public.delivery_paper_line%rowtype;
  v_mov_id bigint;
  v_mov_payload jsonb;
  v_qty integer;
  v_landed numeric;
  v_existing bigint;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  SELECT * INTO v_paper
  FROM public.delivery_paper dp
  WHERE dp.id = p_delivery_paper_id
    AND dp.parent_tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper not found';
  END IF;

  v_existing := public.delivery_paper_dispatch_movement_id(p_delivery_paper_id);
  IF v_existing IS NOT NULL THEN
    IF v_paper.status <> 'dispatched'::public.delivery_paper_status THEN
      UPDATE public.delivery_paper dp
      SET
        status = 'dispatched'::public.delivery_paper_status,
        dispatched_at = coalesce(dp.dispatched_at, now()),
        updated_at = now()
      WHERE dp.id = p_delivery_paper_id;
    END IF;
    RETURN jsonb_build_object(
      'success', true,
      'status', 'dispatched',
      'movement_id', v_existing,
      'idempotent', true
    );
  END IF;

  IF v_paper.status <> 'packed'::public.delivery_paper_status THEN
    RAISE EXCEPTION 'delivery paper must be packed before dispatch (current: %)', v_paper.status;
  END IF;

  v_mov_payload := public.create_stock_movement(
    p_tenant_id,
    'issue_outbound'::public.stock_movement_type,
    'Dispatch delivery paper #' || p_delivery_paper_id::text,
    'delivery_paper',
    p_delivery_paper_id::text
  );
  v_mov_id := (v_mov_payload->'movement'->>'id')::bigint;

  FOR v_line IN
    SELECT dpl.*
    FROM public.delivery_paper_line dpl
    WHERE dpl.delivery_paper_id = p_delivery_paper_id
      AND dpl.global_stock_id IS NOT NULL
  LOOP
    v_qty := public.delivery_paper_line_packed_qty(v_line.splits);
    IF v_qty <= 0 THEN
      CONTINUE;
    END IF;

    SELECT gsi.landed_cost_bdt INTO v_landed
    FROM public.global_stocks gs
    INNER JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    WHERE gs.id = v_line.global_stock_id;

    UPDATE public.delivery_paper_line dpl
    SET unit_cost_landed_snapshot = v_landed, updated_at = now()
    WHERE dpl.id = v_line.id;

    PERFORM public.add_stock_movement_line(
      v_mov_id,
      v_line.global_stock_id,
      v_qty,
      NULL,
      NULL,
      NULL,
      NULL,
      NULL,
      NULL
    );
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM public.stock_movement_lines sml WHERE sml.movement_id = v_mov_id
  ) THEN
    DELETE FROM public.stock_movements WHERE id = v_mov_id;
    RAISE EXCEPTION 'no stock lines to dispatch on paper %', p_delivery_paper_id;
  END IF;

  UPDATE public.delivery_paper_line dpl
  SET
    dispatched_global_stock_id = dpl.global_stock_id,
    updated_at = now()
  WHERE dpl.delivery_paper_id = p_delivery_paper_id
    AND dpl.global_stock_id IS NOT NULL;

  PERFORM public.post_stock_movement(v_mov_id);

  UPDATE public.delivery_paper dp
  SET
    status = 'dispatched'::public.delivery_paper_status,
    dispatched_at = now(),
    updated_at = now()
  WHERE dp.id = p_delivery_paper_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'dispatched',
    'movement_id', v_mov_id
  );
END;
$function$;

GRANT ALL ON FUNCTION public.dispatch_delivery_paper(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.dispatch_delivery_paper(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.dispatch_delivery_paper(bigint, bigint) TO service_role;
CREATE OR REPLACE FUNCTION public.save_delivery_paper_detail (
  p_tenant_id         bigint,
  p_delivery_paper_id bigint,
  p_items             jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_elem jsonb;
  v_pick jsonb;
  v_split_elem jsonb;
  v_demand_id bigint;
  v_stock_id bigint;
  v_qty integer;
  v_close text;
  v_split_status text;
  v_item_splits jsonb;
  v_paper_status public.delivery_paper_status;
  v_line_count integer := 0;
  v_valid_demand boolean;
  v_pick_count integer;
  v_outcome_total integer;
  v_packed_total integer;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  SELECT * INTO v_paper FROM public.delivery_paper dp WHERE dp.id = p_delivery_paper_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'delivery paper not found'; END IF;

  IF v_paper.status IN (
    'delivered'::public.delivery_paper_status,
    'cancelled'::public.delivery_paper_status
  ) THEN
    RAISE EXCEPTION 'delivery paper cannot be edited in status %', v_paper.status;
  END IF;

  IF v_paper.status IN (
    'packed'::public.delivery_paper_status,
    'dispatched'::public.delivery_paper_status
  ) THEN
    IF p_items IS NOT NULL AND jsonb_typeof(p_items) = 'array' THEN
      FOR v_elem IN SELECT value FROM jsonb_array_elements(p_items) LOOP
        v_pick_count := coalesce(jsonb_array_length(v_elem->'picks'), 0);
        IF v_pick_count > 0 THEN
          RAISE EXCEPTION 'packed stock cannot be changed when status is %', v_paper.status;
        END IF;

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

        v_item_splits := '[]'::jsonb;
        FOR v_split_elem IN
          SELECT value FROM jsonb_array_elements(coalesce(v_elem->'splits', '[]'::jsonb))
        LOOP
          v_qty := coalesce((v_split_elem->>'quantity')::integer, 0);
          v_split_status := lower(trim(coalesce(v_split_elem->>'status', '')));
          IF v_qty <= 0 THEN CONTINUE; END IF;
          IF v_split_status NOT IN ('accepted', 'conditioned', 'rejected') THEN
            RAISE EXCEPTION 'only accepted, conditioned, and rejected quantities can be edited in status %', v_paper.status;
          END IF;
          v_item_splits := v_item_splits || jsonb_build_array(
            jsonb_build_object('quantity', v_qty, 'status', v_split_status)
          );
        END LOOP;

        SELECT coalesce(sum((elem->>'quantity')::integer), 0)::integer
        INTO v_outcome_total
        FROM jsonb_array_elements(v_item_splits) AS elem;

        SELECT coalesce(sum(public.delivery_paper_line_packed_qty(dpl.splits)), 0)::integer
        INTO v_packed_total
        FROM public.delivery_paper_line dpl
        WHERE dpl.delivery_paper_id = p_delivery_paper_id
          AND dpl.preorder_demand_id = v_demand_id;

        IF v_outcome_total > v_packed_total THEN
          RAISE EXCEPTION
            'accepted, conditioned, and rejected total (%) cannot exceed packed (%) for line %',
            v_outcome_total,
            v_packed_total,
            v_demand_id;
        END IF;

        DELETE FROM public.delivery_paper_line dpl
        WHERE dpl.delivery_paper_id = p_delivery_paper_id
          AND dpl.preorder_demand_id = v_demand_id
          AND dpl.global_stock_id IS NULL
          AND dpl.dispatched_global_stock_id IS NULL
          AND public.delivery_paper_line_packed_qty(dpl.splits) = 0;

        IF jsonb_array_length(v_item_splits) > 0 THEN
          INSERT INTO public.delivery_paper_line (
            delivery_paper_id,
            preorder_demand_id,
            global_stock_id,
            splits,
            note
          ) VALUES (
            p_delivery_paper_id,
            v_demand_id,
            NULL,
            v_item_splits,
            nullif(trim(coalesce(v_elem->>'note', '')), '')
          );
        END IF;
      END LOOP;
    END IF;

    SELECT coalesce(sum(jsonb_array_length(dpl.splits)), 0)::integer
    INTO v_line_count
    FROM public.delivery_paper_line dpl
    WHERE dpl.delivery_paper_id = p_delivery_paper_id;

    v_paper_status := v_paper.status;

    UPDATE public.delivery_paper dp
    SET updated_at = now()
    WHERE dp.id = p_delivery_paper_id;

    RETURN jsonb_build_object('success', true, 'line_count', v_line_count, 'status', v_paper_status);
  END IF;

  IF v_paper.status <> 'draft'::public.delivery_paper_status THEN
    RAISE EXCEPTION 'only draft delivery papers support full line edit';
  END IF;

  DELETE FROM public.delivery_paper_line dpl WHERE dpl.delivery_paper_id = p_delivery_paper_id;

  CREATE TEMP TABLE IF NOT EXISTS _dpl_save_splits (
    preorder_demand_id bigint NOT NULL,
    global_stock_id bigint NOT NULL,
    splits jsonb NOT NULL DEFAULT '[]'::jsonb,
    note text,
    PRIMARY KEY (preorder_demand_id, global_stock_id)
  ) ON COMMIT DROP;

  TRUNCATE _dpl_save_splits;

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

      v_item_splits := '[]'::jsonb;
      FOR v_split_elem IN
        SELECT value FROM jsonb_array_elements(coalesce(v_elem->'splits', '[]'::jsonb))
      LOOP
        v_qty := coalesce((v_split_elem->>'quantity')::integer, 0);
        v_split_status := lower(trim(coalesce(v_split_elem->>'status', '')));
        IF v_qty <= 0 THEN CONTINUE; END IF;
        IF v_split_status NOT IN ('packed', 'accepted', 'conditioned', 'rejected') THEN
          RAISE EXCEPTION 'invalid split status: %', v_split_status;
        END IF;
        v_item_splits := v_item_splits || jsonb_build_array(
          jsonb_build_object('quantity', v_qty, 'status', v_split_status)
        );
      END LOOP;

      IF jsonb_array_length(v_item_splits) > 0
        AND coalesce(jsonb_array_length(v_elem->'picks'), 0) = 0 THEN
        INSERT INTO public.delivery_paper_line (
          delivery_paper_id,
          preorder_demand_id,
          global_stock_id,
          splits,
          note
        ) VALUES (
          p_delivery_paper_id,
          v_demand_id,
          NULL,
          v_item_splits,
          nullif(trim(coalesce(v_elem->>'note', '')), '')
        );
        v_line_count := v_line_count + jsonb_array_length(v_item_splits);
      END IF;

      FOR v_pick IN SELECT value FROM jsonb_array_elements(coalesce(v_elem->'picks', '[]'::jsonb)) LOOP
        v_stock_id := nullif(v_pick->>'global_stock_id', '')::bigint;
        v_qty := coalesce(nullif(v_pick->>'quantity', '')::integer, 0);
        IF v_stock_id IS NULL OR v_qty <= 0 THEN CONTINUE; END IF;

        v_close := lower(trim(coalesce(v_pick->>'close_action', '')));
        v_split_status := public.delivery_paper_close_action_to_split_status(v_close);

        INSERT INTO _dpl_save_splits (preorder_demand_id, global_stock_id, splits, note)
        VALUES (
          v_demand_id,
          v_stock_id,
          jsonb_build_array(jsonb_build_object('quantity', v_qty, 'status', v_split_status)),
          nullif(trim(coalesce(v_pick->>'note', '')), '')
        )
        ON CONFLICT (preorder_demand_id, global_stock_id) DO UPDATE SET
          splits = _dpl_save_splits.splits || EXCLUDED.splits,
          note = coalesce(_dpl_save_splits.note, EXCLUDED.note);
      END LOOP;
    END LOOP;
  END IF;

  INSERT INTO public.delivery_paper_line (
    delivery_paper_id,
    preorder_demand_id,
    global_stock_id,
    splits,
    note
  )
  SELECT
    p_delivery_paper_id,
    s.preorder_demand_id,
    s.global_stock_id,
    s.splits,
    s.note
  FROM _dpl_save_splits s;

  SELECT coalesce(sum(jsonb_array_length(dpl.splits)), 0)::integer
  INTO v_line_count
  FROM public.delivery_paper_line dpl
  WHERE dpl.delivery_paper_id = p_delivery_paper_id;

  v_paper_status := 'draft'::public.delivery_paper_status;

  UPDATE public.delivery_paper dp
  SET status = v_paper_status, updated_at = now()
  WHERE dp.id = p_delivery_paper_id;

  RETURN jsonb_build_object('success', true, 'line_count', v_line_count, 'status', v_paper_status);
END;
$function$;

GRANT ALL ON FUNCTION public.save_delivery_paper_detail(bigint, bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.save_delivery_paper_detail(bigint, bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.save_delivery_paper_detail(bigint, bigint, jsonb) TO service_role;
CREATE OR REPLACE FUNCTION public.get_delivery_paper_detail (
  p_tenant_id         bigint,
  p_delivery_paper_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_doc_type text;
  v_document_name text;
  v_shop_order_no text;
  v_profile_name text;
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

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'invoice_no', b.invoice_no,
        'invoice_status', b.invoice_status,
        'settlement_kind', b.settlement_kind
      )
      ORDER BY b.id
    ),
    '[]'::jsonb
  )
  INTO v_close_bills
  FROM public.bills b
  WHERE (
    (b.source_type = 'delivery_close' AND b.source_id = p_delivery_paper_id::text)
    OR (
      b.source_type = 'shop_order'
      AND coalesce(b.source_key, '') LIKE ('delivery_paper:' || p_delivery_paper_id::text || ':%')
    )
  );

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
        coalesce(dpl.global_stock_id, dpl.dispatched_global_stock_id) AS global_stock_id,
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
      LEFT JOIN public.global_stocks gs ON gs.id = dpl.global_stock_id
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
CREATE OR REPLACE FUNCTION public.apply_delivery_paper_outcome (
  p_tenant_id         bigint,
  p_delivery_paper_id bigint,
  p_close_action      text,
  p_allocations       jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
  v_bill_source_type text;
  v_bill_source_id text;
  v_bill_source_key text;
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
    v_qty := coalesce(nullif(v_elem->>'quantity', '')::integer, 0);
    v_grade_tag_id := nullif(v_elem->>'grade_tag_id', '')::bigint;

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

    IF v_close_action IN ('take', 'condition') AND v_stock_id IS NOT NULL THEN
      v_items := v_items || jsonb_build_array(jsonb_build_object(
        'global_stock_id', v_stock_id,
        'quantity', v_qty,
        'sell_price_amount', v_sell_price
      ));
    ELSIF v_close_action IN ('take', 'condition') THEN
      v_items := v_items || jsonb_build_array(jsonb_build_object(
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


    IF v_doc_type = 'shop_order' THEN
      v_bill_source_type := 'shop_order';
      v_bill_source_id := v_paper.source_id::text;
      v_bill_source_key := format('delivery_paper:%s:%s', p_delivery_paper_id, v_close_action);
    ELSE
      v_bill_source_type := 'delivery_close';
      v_bill_source_id := p_delivery_paper_id::text;
      v_bill_source_key := v_close_action;
    END IF;

    BEGIN
      UPDATE public.bills
      SET
        source_type = v_bill_source_type,
        source_id = v_bill_source_id,
        source_key = v_bill_source_key,
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
          source_type = v_bill_source_type,
          source_id = v_bill_source_id,
          source_key = v_bill_source_key || ':' || v_invoice_id::text,
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
-- Repair DP-3 (SO-261108-0001): restore packed lot splits + separate outcome plan rows.
-- Tenant-specific row repair; skip when paper 3 is absent (e.g. prod / fresh reset).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.delivery_paper dp WHERE dp.id = 3) THEN
    RETURN;
  END IF;

  UPDATE public.delivery_paper_line dpl
  SET
    splits = jsonb_build_array(jsonb_build_object('status', 'packed', 'quantity', v.qty)),
    dispatched_global_stock_id = -dpl.id,
    updated_at = now()
  FROM (VALUES (45::bigint, 298), (46::bigint, 1199)) AS v(id, qty)
  WHERE dpl.id = v.id
    AND dpl.delivery_paper_id = 3;

  INSERT INTO public.delivery_paper_line (
    delivery_paper_id, preorder_demand_id, global_stock_id, dispatched_global_stock_id, splits
  )
  SELECT 3, v.demand_id, NULL, NULL, v.splits::jsonb
  FROM (VALUES
    (268::bigint, '[{"status":"accepted","quantity":298}]'),
    (269::bigint, '[{"status":"accepted","quantity":1199}]')
  ) AS v(demand_id, splits)
  WHERE NOT EXISTS (
    SELECT 1 FROM public.delivery_paper_line dpl
    WHERE dpl.delivery_paper_id = 3
      AND dpl.preorder_demand_id = v.demand_id
      AND dpl.global_stock_id IS NULL
      AND dpl.dispatched_global_stock_id IS NULL
      AND public.delivery_paper_line_packed_qty(dpl.splits) = 0
  );
END $$;

-- Delivery paper packing: resolve line demand from document source when preorder_demand was never seeded.

CREATE OR REPLACE FUNCTION public.delivery_paper_ensure_procuring_demands(
  p_paper_source_type public.delivery_paper_source_type,
  p_source_id bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF p_source_id IS NULL THEN
    RETURN;
  END IF;

  IF p_paper_source_type = 'shop_order'::public.delivery_paper_source_type THEN
    PERFORM public.ensure_preorder_demand_for_procuring_document('shop_order', p_source_id);
  ELSIF p_paper_source_type = 'pbc_costing_file'::public.delivery_paper_source_type THEN
    PERFORM public.ensure_preorder_demand_for_procuring_document('pbc_costing_file', p_source_id);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.delivery_paper_resolve_line_demand_id(
  p_paper public.delivery_paper,
  p_preorder_demand_id bigint,
  p_line_source_type text,
  p_line_source_id bigint
)
RETURNS bigint
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_demand_id bigint;
  v_line_source text := lower(trim(coalesce(p_line_source_type, '')));
BEGIN
  IF p_preorder_demand_id IS NOT NULL THEN
    SELECT pd.id INTO v_demand_id
    FROM public.preorder_demand pd
    WHERE pd.id = p_preorder_demand_id
      AND (
        (
          p_paper.source_type = 'shop_order'::public.delivery_paper_source_type
          AND pd.source_type = 'shop_order_item'::public.preorder_demand_source_type
          AND EXISTS (
            SELECT 1
            FROM public.shop_order_items oi
            WHERE oi.id = pd.source_id
              AND oi.order_id = p_paper.source_id
          )
        )
        OR (
          p_paper.source_type = 'pbc_costing_file'::public.delivery_paper_source_type
          AND pd.source_type = 'pbc_costing_item'::public.preorder_demand_source_type
          AND EXISTS (
            SELECT 1
            FROM public.product_based_costing_items pci
            WHERE pci.id = pd.source_id
              AND pci.product_based_costing_file_id = p_paper.source_id
          )
        )
      );
    IF v_demand_id IS NOT NULL THEN
      RETURN v_demand_id;
    END IF;
  END IF;

  IF p_line_source_id IS NULL THEN
    RETURN NULL;
  END IF;

  PERFORM public.delivery_paper_ensure_procuring_demands(p_paper.source_type, p_paper.source_id);

  IF p_paper.source_type = 'shop_order'::public.delivery_paper_source_type
    AND (v_line_source = '' OR v_line_source = 'shop_order_item') THEN
    SELECT pd.id INTO v_demand_id
    FROM public.preorder_demand pd
    WHERE pd.source_type = 'shop_order_item'::public.preorder_demand_source_type
      AND pd.source_id = p_line_source_id
      AND EXISTS (
        SELECT 1
        FROM public.shop_order_items oi
        WHERE oi.id = pd.source_id
          AND oi.order_id = p_paper.source_id
      )
    LIMIT 1;
  ELSIF p_paper.source_type = 'pbc_costing_file'::public.delivery_paper_source_type
    AND (v_line_source = '' OR v_line_source = 'pbc_costing_item') THEN
    SELECT pd.id INTO v_demand_id
    FROM public.preorder_demand pd
    WHERE pd.source_type = 'pbc_costing_item'::public.preorder_demand_source_type
      AND pd.source_id = p_line_source_id
      AND EXISTS (
        SELECT 1
        FROM public.product_based_costing_items pci
        WHERE pci.id = pd.source_id
          AND pci.product_based_costing_file_id = p_paper.source_id
      )
    LIMIT 1;
  END IF;

  RETURN v_demand_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delivery_paper_ensure_procuring_demands(
  public.delivery_paper_source_type, bigint
) TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.delivery_paper_resolve_line_demand_id(
  public.delivery_paper, bigint, text, bigint
) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public._newest_pickable_stock_for_network_search(
  p_context_tenant_id bigint,
  p_product_id bigint DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_search_field text DEFAULT 'name'
)
RETURNS TABLE(
  global_stock_id bigint,
  available_atp numeric,
  shipment_name text,
  location_name text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_parent_id bigint;
  v_is_parent_context boolean;
BEGIN
  IF p_context_tenant_id IS NULL THEN
    RETURN;
  END IF;

  v_parent_id := public.resolve_parent_tenant_id(p_context_tenant_id);
  v_is_parent_context := (p_context_tenant_id = v_parent_id);

  RETURN QUERY
  SELECT
    gs.id,
    public.global_stock_atp_qty(gs.id),
    coalesce(nullif(trim(sh.name), ''), sh.id::text),
    coalesce(sl.name, coalesce(ht.name, pt.name))
  FROM public.global_stocks gs
  INNER JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  INNER JOIN public.global_shipments sh ON sh.id = gsi.shipment_id
  INNER JOIN public.tenants pt ON pt.id = v_parent_id
  LEFT JOIN public.tenants ht ON ht.id = coalesce(sh.assigned_child_tenant_id, v_parent_id)
  LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
  WHERE gs.tenant_id = v_parent_id
    AND gs.is_archived = false
    AND gs.availability = 'sellable'::public.stock_availability
    AND (gs.location_id IS NULL OR coalesce(sl.is_pickable, false) = true)
    AND (
      v_is_parent_context
      OR sh.assigned_child_tenant_id IS NULL
      OR sh.assigned_child_tenant_id = p_context_tenant_id
    )
    AND sh.status = 'received'
    AND gs.quantity > 0
    AND public.global_stock_atp_qty(gs.id) > 0
    AND (p_product_id IS NULL OR gsi.product_id = p_product_id)
    AND (
      p_search IS NULL
      OR trim(p_search) = ''
      OR CASE coalesce(nullif(lower(trim(p_search_field)), ''), 'name')
        WHEN 'name' THEN (
          SELECT coalesce(bool_and(gsi.name ILIKE '%' || trim(word) || '%'), true)
          FROM unnest(string_to_array(trim(p_search), ' ')) AS word
          WHERE trim(word) <> ''
        )
        ELSE false
      END
    )
  ORDER BY gs.id DESC
  LIMIT 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.suggest_delivery_paper_last_lot_picks(
  p_tenant_id bigint,
  p_delivery_paper_id bigint,
  p_stock_context_tenant_id bigint,
  p_lines jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_doc_type text;
  v_items jsonb;
  v_item jsonb;
  v_picks jsonb := '[]'::jsonb;
  v_demand_id bigint;
  v_packed_other integer;
  v_remaining_to_pack integer;
  v_packed_this integer;
  v_need integer;
  v_product_id bigint;
  v_name text;
  v_stock_id bigint;
  v_stock_atp numeric;
  v_stock_shipment_name text;
  v_stock_location_name text;
  v_qty integer;
  v_line jsonb;
  v_line_demand_id bigint;
  v_filter_ids bigint[] := NULL;
  v_source_type text;
  v_source_id bigint;
  v_line_source_type text;
  v_line_source_id bigint;
  v_match_line boolean;
  v_packed_map jsonb := '{}'::jsonb;
  j integer;
  i integer;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  IF p_stock_context_tenant_id IS NULL THEN
    RAISE EXCEPTION 'stock_context_tenant_id is required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.tenant_id = p_stock_context_tenant_id
      AND lower(trim(m.email)) = public.current_user_email()
      AND m.is_active = true
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  SELECT * INTO v_paper FROM public.delivery_paper dp WHERE dp.id = p_delivery_paper_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper not found';
  END IF;

  IF v_paper.status <> 'draft'::public.delivery_paper_status THEN
    RAISE EXCEPTION 'only draft delivery papers can be edited';
  END IF;

  v_doc_type := v_paper.source_type::text;

  PERFORM public.delivery_paper_ensure_procuring_demands(v_paper.source_type, v_paper.source_id);

  IF p_lines IS NOT NULL AND jsonb_typeof(p_lines) = 'array' AND jsonb_array_length(p_lines) > 0 THEN
  FOR i IN 0 .. jsonb_array_length(p_lines) - 1 LOOP
      v_line := p_lines->i;
      v_line_demand_id := nullif(v_line->>'preorder_demand_id', '')::bigint;
      v_line_source_id := nullif(v_line->>'source_id', '')::bigint;
      IF v_line_demand_id IS NULL AND v_line_source_id IS NULL THEN
        CONTINUE;
      END IF;
      IF v_line_demand_id IS NOT NULL THEN
        v_filter_ids := array_append(coalesce(v_filter_ids, '{}'::bigint[]), v_line_demand_id);
        v_packed_map := v_packed_map || jsonb_build_object(
          v_line_demand_id::text,
          greatest(coalesce(nullif(v_line->>'packed_on_this_paper', '')::integer, 0), 0)
        );
      ELSE
        v_packed_map := v_packed_map || jsonb_build_object(
          ('src:' || v_line_source_id::text),
          greatest(coalesce(nullif(v_line->>'packed_on_this_paper', '')::integer, 0), 0)
        );
      END IF;
    END LOOP;
  END IF;

  v_items := coalesce(
    public.list_procurement_demand_group_items(
      p_tenant_id,
      v_doc_type,
      v_paper.source_id,
      null,
      500,
      null
    )->'items',
    '[]'::jsonb
  );

  FOR i IN 0 .. coalesce(jsonb_array_length(v_items), 0) - 1 LOOP
    v_item := v_items->i;
    v_demand_id := nullif(v_item->>'preorder_demand_id', '')::bigint;
    v_source_type := nullif(trim(coalesce(v_item->>'source_type', '')), '');
    v_source_id := nullif(v_item->>'source_id', '')::bigint;

    IF p_lines IS NOT NULL AND jsonb_typeof(p_lines) = 'array' AND jsonb_array_length(p_lines) > 0 THEN
      v_match_line := false;
      FOR j IN 0 .. jsonb_array_length(p_lines) - 1 LOOP
        v_line := p_lines->j;
        IF nullif(v_line->>'preorder_demand_id', '')::bigint IS NOT NULL
          AND nullif(v_line->>'preorder_demand_id', '')::bigint = v_demand_id THEN
          v_match_line := true;
          EXIT;
        END IF;
        IF nullif(v_line->>'source_id', '')::bigint IS NOT NULL
          AND nullif(v_line->>'source_id', '')::bigint = v_source_id THEN
          v_match_line := true;
          EXIT;
        END IF;
      END LOOP;
      IF NOT v_match_line THEN
        CONTINUE;
      END IF;
    ELSIF v_filter_ids IS NOT NULL AND v_demand_id IS NOT NULL AND NOT (v_demand_id = ANY(v_filter_ids)) THEN
      CONTINUE;
    END IF;

    v_demand_id := public.delivery_paper_resolve_line_demand_id(
      v_paper,
      v_demand_id,
      v_source_type,
      v_source_id
    );
    IF v_demand_id IS NULL THEN
      CONTINUE;
    END IF;

    v_packed_other := public.preorder_demand_packed_on_delivery_papers(
      v_demand_id,
      v_paper.source_type,
      v_paper.source_id,
      p_delivery_paper_id
    );

    v_remaining_to_pack := greatest(
      coalesce((v_item->>'remaining_to_deliver')::integer, 0) - v_packed_other,
      0
    );

    v_packed_this := coalesce(
      (v_packed_map->>v_demand_id::text)::integer,
      (v_packed_map->>('src:' || v_source_id::text))::integer,
      0
    );
    v_need := greatest(v_remaining_to_pack - v_packed_this, 0);
    IF v_need <= 0 THEN
      CONTINUE;
    END IF;

    v_product_id := nullif(v_item->>'product_id', '')::bigint;
    v_name := nullif(trim(coalesce(v_item->>'name', '')), '');

    v_stock_id := NULL;
    v_stock_atp := NULL;
    v_stock_shipment_name := NULL;
    v_stock_location_name := NULL;

    IF v_product_id IS NOT NULL THEN
      SELECT s.global_stock_id, s.available_atp, s.shipment_name, s.location_name
      INTO v_stock_id, v_stock_atp, v_stock_shipment_name, v_stock_location_name
      FROM public._newest_pickable_stock_for_network_search(
        p_stock_context_tenant_id,
        v_product_id,
        NULL,
        NULL
      ) AS s;
    END IF;

    IF v_stock_id IS NULL AND v_name IS NOT NULL THEN
      SELECT s.global_stock_id, s.available_atp, s.shipment_name, s.location_name
      INTO v_stock_id, v_stock_atp, v_stock_shipment_name, v_stock_location_name
      FROM public._newest_pickable_stock_for_network_search(
        p_stock_context_tenant_id,
        NULL,
        v_name,
        'name'
      ) AS s;
    END IF;

    IF v_stock_id IS NULL THEN
      CONTINUE;
    END IF;

    v_qty := least(
      v_need,
      greatest(0, trunc(v_stock_atp))
    );
    IF v_qty <= 0 THEN
      CONTINUE;
    END IF;

    v_picks := v_picks || jsonb_build_array(
      jsonb_build_object(
        'preorder_demand_id', v_demand_id,
        'source_type', v_source_type,
        'source_id', v_source_id,
        'global_stock_id', v_stock_id,
        'quantity', v_qty,
        'shipment_name', v_stock_shipment_name,
        'location_name', v_stock_location_name,
        'available_atp', v_stock_atp
      )
    );
  END LOOP;

  RETURN jsonb_build_object('picks', v_picks);
END;
$$;

GRANT EXECUTE ON FUNCTION public.suggest_delivery_paper_last_lot_picks(
  bigint, bigint, bigint, jsonb
) TO authenticated, service_role;

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
        v_demand_id := public.delivery_paper_resolve_line_demand_id(
          v_paper,
          v_demand_id,
          v_elem->>'source_type',
          nullif(v_elem->>'source_id', '')::bigint
        );
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

  PERFORM public.delivery_paper_ensure_procuring_demands(v_paper.source_type, v_paper.source_id);

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
      v_demand_id := public.delivery_paper_resolve_line_demand_id(
        v_paper,
        v_demand_id,
        v_elem->>'source_type',
        nullif(v_elem->>'source_id', '')::bigint
      );
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

CREATE OR REPLACE FUNCTION public.get_delivery_paper_detail (
  p_tenant_id         bigint,
  p_delivery_paper_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  VOLATILE
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

  PERFORM public.delivery_paper_ensure_procuring_demands(v_paper.source_type, v_paper.source_id);

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

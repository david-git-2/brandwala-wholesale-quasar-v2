-- Bulk newest pickable lot suggestions for delivery paper lines (mirrors search_stock_network ordering).

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
STABLE
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
  v_packed_map jsonb := '{}'::jsonb;
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

  IF p_lines IS NOT NULL AND jsonb_typeof(p_lines) = 'array' AND jsonb_array_length(p_lines) > 0 THEN
  FOR i IN 0 .. jsonb_array_length(p_lines) - 1 LOOP
      v_line := p_lines->i;
      v_line_demand_id := nullif(v_line->>'preorder_demand_id', '')::bigint;
      IF v_line_demand_id IS NULL THEN
        CONTINUE;
      END IF;
      v_filter_ids := array_append(coalesce(v_filter_ids, '{}'::bigint[]), v_line_demand_id);
      v_packed_map := v_packed_map || jsonb_build_object(
        v_line_demand_id::text,
        greatest(coalesce(nullif(v_line->>'packed_on_this_paper', '')::integer, 0), 0)
      );
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
    IF v_demand_id IS NULL THEN
      CONTINUE;
    END IF;

    IF v_filter_ids IS NOT NULL AND NOT (v_demand_id = ANY(v_filter_ids)) THEN
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

    v_packed_this := coalesce((v_packed_map->>v_demand_id::text)::integer, 0);
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
-- Delivery paper detail: remaining column must subtract packed qty on other papers (and FE subtracts this paper).

CREATE OR REPLACE FUNCTION public.preorder_demand_packed_on_delivery_papers(
  p_preorder_demand_id bigint,
  p_document_source_type public.delivery_paper_source_type,
  p_document_source_id bigint,
  p_exclude_delivery_paper_id bigint DEFAULT NULL
)
RETURNS integer
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(sum(public.delivery_paper_line_packed_qty(dpl.splits)), 0)::integer
  FROM public.delivery_paper_line dpl
  INNER JOIN public.delivery_paper dp ON dp.id = dpl.delivery_paper_id
  WHERE dpl.preorder_demand_id = p_preorder_demand_id
    AND dp.source_type = p_document_source_type
    AND dp.source_id = p_document_source_id
    AND dp.status <> 'cancelled'::public.delivery_paper_status
    AND (p_exclude_delivery_paper_id IS NULL OR dp.id <> p_exclude_delivery_paper_id);
$$;

GRANT EXECUTE ON FUNCTION public.preorder_demand_packed_on_delivery_papers(
  bigint,
  public.delivery_paper_source_type,
  bigint,
  bigint
) TO authenticated, service_role;

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
        dpl.global_stock_id,
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
$$;

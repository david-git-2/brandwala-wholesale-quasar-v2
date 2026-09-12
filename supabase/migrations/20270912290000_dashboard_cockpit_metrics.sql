-- Extend staff dashboard glance RPCs with pipeline and location fields.

CREATE OR REPLACE FUNCTION public.get_procurement_dashboard_metrics(p_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_books_id bigint;
  v_sellable bigint := 0;
  v_held bigint := 0;
  v_unsellable bigint := 0;
  v_total bigint := 0;
  v_value numeric := 0;
  v_in_transit bigint := 0;
  v_draft bigint := 0;
  v_received bigint := 0;
  v_grades jsonb := '[]'::jsonb;
  v_pipeline jsonb := '[]'::jsonb;
  v_locations jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'global_stock', 'view') THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  SELECT
    coalesce(sum(gs.quantity) FILTER (WHERE gs.availability = 'sellable'::public.stock_availability), 0),
    coalesce(sum(gs.quantity) FILTER (WHERE gs.availability = 'held'::public.stock_availability), 0),
    coalesce(sum(gs.quantity) FILTER (WHERE gs.availability = 'unsellable'::public.stock_availability), 0),
    coalesce(sum(gs.quantity), 0),
    coalesce(
      sum(gs.quantity * coalesce(gsi.landed_cost_bdt, 0))
        FILTER (WHERE gs.availability = 'sellable'::public.stock_availability),
      0
    )
  INTO v_sellable, v_held, v_unsellable, v_total, v_value
  FROM public.global_stocks gs
  JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  WHERE gs.parent_tenant_id = v_books_id;

  SELECT
    coalesce(count(*) FILTER (WHERE s.status = 'in_transit'), 0),
    coalesce(count(*) FILTER (WHERE s.status = 'draft'), 0),
    coalesce(count(*) FILTER (WHERE s.status = 'received'), 0)
  INTO v_in_transit, v_draft, v_received
  FROM public.global_shipments s
  WHERE s.parent_tenant_id = v_books_id
    AND s.is_archived = false;

  SELECT coalesce(jsonb_agg(row_to_json(g) ORDER BY g.qty DESC), '[]'::jsonb)
  INTO v_grades
  FROM (
    SELECT coalesce(t.name, 'Ungraded') AS name, sum(gs.quantity)::bigint AS qty
    FROM public.global_stocks gs
    LEFT JOIN public.tags t ON t.id = gs.grade_tag_id
    WHERE gs.parent_tenant_id = v_books_id
      AND gs.quantity > 0
    GROUP BY coalesce(t.name, 'Ungraded')
  ) g;

  SELECT coalesce(jsonb_agg(row_to_json(p) ORDER BY p.sort_key), '[]'::jsonb)
  INTO v_pipeline
  FROM (
    SELECT
      s.status,
      count(*)::bigint AS count,
      CASE s.status
        WHEN 'draft' THEN 1
        WHEN 'in_transit' THEN 2
        WHEN 'received' THEN 3
        ELSE 4
      END AS sort_key
    FROM public.global_shipments s
    WHERE s.parent_tenant_id = v_books_id
      AND s.is_archived = false
      AND s.status <> 'cancelled'
    GROUP BY s.status
  ) p;

  SELECT coalesce(jsonb_agg(row_to_json(l) ORDER BY l.qty DESC), '[]'::jsonb)
  INTO v_locations
  FROM (
    SELECT
      coalesce(sl.name, 'Unlocated') AS name,
      sum(gs.quantity)::bigint AS qty
    FROM public.global_stocks gs
    LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
    WHERE gs.parent_tenant_id = v_books_id
      AND gs.quantity > 0
    GROUP BY coalesce(sl.name, 'Unlocated')
  ) l;

  RETURN jsonb_build_object(
    'tenant_id', v_books_id,
    'sellable_qty', v_sellable,
    'held_qty', v_held,
    'unsellable_qty', v_unsellable,
    'total_qty', v_total,
    'sellable_pct', CASE WHEN v_total > 0 THEN round((v_sellable::numeric / v_total) * 100, 1) ELSE 0 END,
    'sellable_value_bdt', round(v_value, 2),
    'in_transit_count', v_in_transit,
    'draft_count', v_draft,
    'received_count', v_received,
    'grades', v_grades,
    'pipeline', v_pipeline,
    'locations', v_locations
  );
END;
$$;


CREATE OR REPLACE FUNCTION public.get_shop_order_dashboard_metrics(p_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date;
  v_sales numeric := 0;
  v_invoice_count bigint := 0;
  v_shipped bigint := 0;
  v_ready bigint := 0;
  v_needs_quote bigint := 0;
  v_processing bigint := 0;
  v_dropship_submitted bigint := 0;
  v_dropship_processing bigint := 0;
  v_dropship_ready bigint := 0;
  v_hourly jsonb := '[]'::jsonb;
  v_couriers jsonb := '[]'::jsonb;
  v_pipeline jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'shop_order', 'view') THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_today := (timezone('Asia/Dhaka', now()))::date;

  SELECT
    coalesce(sum(si.total_amount), 0),
    count(*)
  INTO v_sales, v_invoice_count
  FROM public.sales_invoices si
  WHERE si.issued_by_tenant_id = p_tenant_id
    AND si.invoice_status = 'issued'::public.global_invoice_status
    AND si.invoice_date = v_today;

  SELECT
    coalesce(count(*) FILTER (WHERE o.status = 'shipped'::public.shop_order_status), 0),
    coalesce(count(*) FILTER (WHERE o.status = 'ready_for_pickup'::public.shop_order_status), 0)
  INTO v_shipped, v_ready
  FROM public.shop_orders o
  WHERE o.tenant_id = p_tenant_id
    AND o.status IN (
      'shipped'::public.shop_order_status,
      'ready_for_pickup'::public.shop_order_status
    );

  SELECT
    coalesce(count(*) FILTER (
      WHERE o.status IN (
        'submitted'::public.shop_order_status,
        'costing_pending'::public.shop_order_status
      )
    ), 0),
    coalesce(count(*) FILTER (WHERE o.status = 'processing'::public.shop_order_status), 0)
  INTO v_needs_quote, v_processing
  FROM public.shop_orders o
  WHERE o.tenant_id = p_tenant_id;

  SELECT
    coalesce(count(*) FILTER (
      WHERE o.shop_type_snapshot = 'dropship'::public.shop_type_enum
        AND o.status = 'submitted'::public.shop_order_status
    ), 0),
    coalesce(count(*) FILTER (
      WHERE o.shop_type_snapshot = 'dropship'::public.shop_type_enum
        AND o.status = 'processing'::public.shop_order_status
    ), 0),
    coalesce(count(*) FILTER (
      WHERE o.shop_type_snapshot = 'dropship'::public.shop_type_enum
        AND o.status = 'ready_for_pickup'::public.shop_order_status
    ), 0)
  INTO v_dropship_submitted, v_dropship_processing, v_dropship_ready
  FROM public.shop_orders o
  WHERE o.tenant_id = p_tenant_id;

  SELECT coalesce(jsonb_agg(row_to_json(p) ORDER BY p.sort_key), '[]'::jsonb)
  INTO v_pipeline
  FROM (
    SELECT
      bucket.status,
      count(*)::bigint AS count,
      bucket.sort_key
    FROM (
      SELECT
        CASE
          WHEN o.status IN (
            'submitted'::public.shop_order_status,
            'costing_pending'::public.shop_order_status
          ) THEN 'needs_quote'
          WHEN o.status = 'processing'::public.shop_order_status THEN 'processing'
          WHEN o.status = 'ready_for_pickup'::public.shop_order_status THEN 'ready_for_pickup'
          WHEN o.status = 'shipped'::public.shop_order_status THEN 'shipped'
        END AS status,
        CASE
          WHEN o.status IN (
            'submitted'::public.shop_order_status,
            'costing_pending'::public.shop_order_status
          ) THEN 1
          WHEN o.status = 'processing'::public.shop_order_status THEN 2
          WHEN o.status = 'ready_for_pickup'::public.shop_order_status THEN 3
          WHEN o.status = 'shipped'::public.shop_order_status THEN 4
        END AS sort_key
      FROM public.shop_orders o
      WHERE o.tenant_id = p_tenant_id
    ) bucket
    WHERE bucket.status IS NOT NULL
    GROUP BY bucket.status, bucket.sort_key
  ) p;

  SELECT coalesce(jsonb_agg(row_to_json(h) ORDER BY h.hour_at), '[]'::jsonb)
  INTO v_hourly
  FROM (
    SELECT
      date_trunc('hour', timezone('Asia/Dhaka', si.created_at)) AS hour_at,
      to_char(timezone('Asia/Dhaka', si.created_at), 'HH12 AM') AS label,
      round(sum(si.total_amount), 2) AS amount
    FROM public.sales_invoices si
    WHERE si.issued_by_tenant_id = p_tenant_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.invoice_date = v_today
    GROUP BY 1, 2
  ) h;

  SELECT coalesce(jsonb_agg(row_to_json(c) ORDER BY c.count DESC), '[]'::jsonb)
  INTO v_couriers
  FROM (
    SELECT
      coalesce(nullif(trim(o.courier_name), ''), 'Store pickup') AS name,
      count(*)::bigint AS count,
      count(*) FILTER (WHERE o.status = 'shipped'::public.shop_order_status)::bigint AS shipped_count,
      count(*) FILTER (WHERE o.status = 'ready_for_pickup'::public.shop_order_status)::bigint AS ready_count
    FROM public.shop_orders o
    WHERE o.tenant_id = p_tenant_id
      AND o.status IN (
        'shipped'::public.shop_order_status,
        'ready_for_pickup'::public.shop_order_status
      )
    GROUP BY 1
  ) c;

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'today_sales_amount', round(v_sales, 2),
    'today_invoice_count', v_invoice_count,
    'shipped_count', v_shipped,
    'ready_for_pickup_count', v_ready,
    'needs_quote_count', v_needs_quote,
    'processing_count', v_processing,
    'dropship_submitted', v_dropship_submitted,
    'dropship_processing', v_dropship_processing,
    'dropship_ready', v_dropship_ready,
    'hourly', v_hourly,
    'couriers', v_couriers,
    'pipeline', v_pipeline
  );
END;
$$;

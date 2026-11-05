CREATE FUNCTION public.get_procurement_dashboard_metrics (
  p_tenant_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
  WHERE gs.parent_tenant_id = v_books_id
    AND gs.is_archived = false;

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
      AND gs.is_archived = false
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
      AND gs.is_archived = false
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
$function$;

GRANT ALL ON FUNCTION public.get_procurement_dashboard_metrics(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_procurement_dashboard_metrics(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_procurement_dashboard_metrics(bigint) TO service_role;
-- Inbound receive: internal _stock_spine_* layer (no changes to post_stock_movement / create_and_post_stock_movement).

CREATE OR REPLACE FUNCTION public._stock_spine_upsert_receive_lot(
  p_tenant_id bigint,
  p_shipment_item_id bigint,
  p_outcome_id bigint,
  p_stock_type_id bigint,
  p_delta integer,
  p_location_id bigint,
  p_availability public.stock_availability,
  p_grade_tag_id bigint
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stock_id bigint;
BEGIN
  IF p_delta IS NULL OR p_delta <= 0 THEN
    RAISE EXCEPTION 'receive lot delta must be > 0';
  END IF;

  INSERT INTO public.global_stocks (
    parent_tenant_id,
    shipment_item_id,
    outcome_id,
    stock_type_id,
    quantity,
    is_usable,
    availability,
    location_id,
    grade_tag_id
  ) VALUES (
    p_tenant_id,
    p_shipment_item_id,
    p_outcome_id,
    p_stock_type_id,
    p_delta,
    true,
    p_availability,
    p_location_id,
    p_grade_tag_id
  )
  ON CONFLICT (outcome_id, availability, location_id, grade_tag_id)
  DO UPDATE SET
    quantity = public.global_stocks.quantity + excluded.quantity,
    updated_at = now()
  RETURNING id INTO v_stock_id;

  RETURN v_stock_id;
END;
$$;

CREATE OR REPLACE FUNCTION public._stock_spine_finalize_inbound_movement(p_movement_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mov public.stock_movements%rowtype;
  v_line_count integer;
BEGIN
  SELECT * INTO v_mov
  FROM public.stock_movements
  WHERE id = p_movement_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'stock movement not found';
  END IF;

  IF v_mov.is_posted THEN
    RETURN;
  END IF;

  IF v_mov.movement_type <> 'receive_putaway'::public.stock_movement_type THEN
    RAISE EXCEPTION 'inbound finalize requires receive_putaway movement';
  END IF;

  IF coalesce(v_mov.reference_type, '') <> 'global_shipment' THEN
    RAISE EXCEPTION 'inbound finalize requires global_shipment reference';
  END IF;

  SELECT count(*)::integer INTO v_line_count
  FROM public.stock_movement_lines sml
  WHERE sml.movement_id = p_movement_id;

  IF v_line_count <= 0 THEN
    RAISE EXCEPTION 'inbound movement has no lines';
  END IF;

  UPDATE public.stock_movements
  SET is_posted = true, posted_at = now(), updated_at = now()
  WHERE id = p_movement_id;
END;
$$;

CREATE OR REPLACE FUNCTION public._stock_spine_receive_shipment_outcomes(
  p_shipment_id bigint,
  p_stock_rows jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ship public.global_shipments%rowtype;
  v_stamped integer;
  v_stock_count integer := 0;
  v_parent bigint;
  v_loc bigint;
  v_grade_tag bigint;
  v_avail public.stock_availability;
  v_stock_id bigint;
  v_mov_id bigint;
  v_mov_no text;
  v_posted int;
  v_delta int;
  r_out record;
  v_stock_type bigint;
BEGIN
  SELECT * INTO v_ship FROM public.global_shipments WHERE id = p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  v_parent := v_ship.parent_tenant_id;

  IF v_ship.status = 'cancelled' THEN
    RAISE EXCEPTION 'shipment is cancelled';
  END IF;

  IF coalesce(v_ship.is_closed, false) THEN
    RAISE EXCEPTION 'shipment is closed';
  END IF;

  PERFORM public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  IF NOT EXISTS (
    SELECT 1 FROM public.global_shipment_cost_entries WHERE shipment_id = p_shipment_id
  ) THEN
    RAISE EXCEPTION 'shipment has no cost entries';
  END IF;

  v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);
  PERFORM public._stamp_global_shipment_outcome_costs(p_shipment_id);

  v_mov_no := 'RP-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.stock_movements_id_seq')::text, 6, '0');

  INSERT INTO public.stock_movements (
    tenant_id,
    movement_no,
    movement_type,
    reference_type,
    reference_id,
    notes,
    created_by_email,
    is_posted,
    posted_at
  ) VALUES (
    v_parent,
    v_mov_no,
    'receive_putaway'::public.stock_movement_type,
    'global_shipment',
    p_shipment_id::text,
    'Outcome receive put-away for shipment ' || p_shipment_id::text,
    public.current_user_email(),
    false,
    NULL
  )
  RETURNING id INTO v_mov_id;

  FOR r_out IN
    SELECT o.*
    FROM public.global_shipment_item_outcomes o
    INNER JOIN public.global_shipment_items gsi ON gsi.id = o.shipment_item_id
    WHERE gsi.shipment_id = p_shipment_id
      AND o.reason <> 'ordered'::public.global_shipment_outcome_reason
    ORDER BY o.id
  LOOP
    IF r_out.kind = 'unsellable'::public.global_shipment_outcome_kind THEN
      CONTINUE;
    END IF;

    SELECT coalesce(sum(gs.quantity), 0)::int INTO v_posted
    FROM public.global_stocks gs WHERE gs.outcome_id = r_out.id;

    v_delta := r_out.quantity - v_posted;
    IF v_delta <= 0 THEN
      CONTINUE;
    END IF;

    v_loc := NULL;
    IF p_stock_rows IS NOT NULL AND jsonb_typeof(p_stock_rows) = 'array' THEN
      SELECT (elem->>'location_id')::bigint INTO v_loc
      FROM jsonb_array_elements(p_stock_rows) elem
      WHERE (elem->>'outcome_id')::bigint = r_out.id
      LIMIT 1;
    END IF;

    IF v_loc IS NULL AND p_stock_rows IS NOT NULL AND jsonb_typeof(p_stock_rows) = 'array' THEN
      SELECT (elem->>'location_id')::bigint INTO v_loc
      FROM jsonb_array_elements(p_stock_rows) elem
      WHERE (elem->>'shipment_item_id')::bigint = r_out.shipment_item_id
      LIMIT 1;
    END IF;

    v_loc := coalesce(v_loc, public.default_putaway_stock_location_id(v_parent));

    IF v_loc IS NULL THEN
      RAISE EXCEPTION 'no put-away location configured';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.stock_locations sl
      WHERE sl.id = v_loc AND sl.parent_tenant_id = v_parent AND sl.is_active = true
        AND public._stock_location_is_leaf(v_loc)
    ) THEN
      RAISE EXCEPTION 'invalid put-away location';
    END IF;

    v_avail := 'sellable'::public.stock_availability;
    v_grade_tag := public.default_stock_grade_tag_id();

    v_stock_type := NULL;
    IF p_stock_rows IS NOT NULL AND jsonb_typeof(p_stock_rows) = 'array' THEN
      SELECT (elem->>'stock_type_id')::bigint INTO v_stock_type
      FROM jsonb_array_elements(p_stock_rows) elem
      WHERE (elem->>'outcome_id')::bigint = r_out.id
        AND nullif(elem->>'stock_type_id', '') IS NOT NULL
      LIMIT 1;
    END IF;

    IF v_stock_type IS NULL AND p_stock_rows IS NOT NULL AND jsonb_typeof(p_stock_rows) = 'array' THEN
      SELECT (elem->>'stock_type_id')::bigint INTO v_stock_type
      FROM jsonb_array_elements(p_stock_rows) elem
      WHERE (elem->>'shipment_item_id')::bigint = r_out.shipment_item_id
        AND nullif(elem->>'stock_type_id', '') IS NOT NULL
      LIMIT 1;
    END IF;

    IF v_stock_type IS NULL THEN
      SELECT gs.stock_type_id INTO v_stock_type
      FROM public.global_stocks gs
      WHERE gs.shipment_item_id = r_out.shipment_item_id
        AND gs.stock_type_id IS NOT NULL
      ORDER BY gs.quantity DESC, gs.id
      LIMIT 1;
    END IF;

    IF v_stock_type IS NULL THEN
      v_stock_type := public.default_sellable_global_stock_type_id(v_parent);
    END IF;

    IF v_stock_type IS NULL THEN
      RAISE EXCEPTION 'no sellable stock type configured';
    END IF;

    v_stock_id := public._stock_spine_upsert_receive_lot(
      v_parent,
      r_out.shipment_item_id,
      r_out.id,
      v_stock_type,
      v_delta,
      v_loc,
      v_avail,
      v_grade_tag
    );

    INSERT INTO public.stock_movement_lines (
      movement_id, stock_id, quantity, to_location_id, to_availability
    ) VALUES (v_mov_id, v_stock_id, v_delta, v_loc, v_avail);

    v_stock_count := v_stock_count + 1;
  END LOOP;

  IF v_stock_count > 0 THEN
    PERFORM public._stock_spine_finalize_inbound_movement(v_mov_id);
  ELSE
    DELETE FROM public.stock_movements WHERE id = v_mov_id;
    v_mov_id := NULL;
  END IF;

  UPDATE public.global_shipment_items gsi
  SET received_quantity = coalesce(extra_totals.total_qty, 0), updated_at = now()
  FROM (
    SELECT o.shipment_item_id AS item_id, sum(o.quantity)::int AS total_qty
    FROM public.global_shipment_item_outcomes o
    INNER JOIN public.global_shipment_items gsi2 ON gsi2.id = o.shipment_item_id
    WHERE gsi2.shipment_id = p_shipment_id
      AND o.reason <> 'ordered'::public.global_shipment_outcome_reason
    GROUP BY o.shipment_item_id
  ) extra_totals
  WHERE gsi.id = extra_totals.item_id AND gsi.shipment_id = p_shipment_id;

  IF v_stock_count > 0 THEN
    UPDATE public.global_shipments
    SET status = 'received',
        stock_ready = true,
        inventory_added = true,
        updated_at = now()
    WHERE id = p_shipment_id;
  END IF;

  RETURN jsonb_build_object(
    'shipment_id', p_shipment_id,
    'items_stamped', v_stamped,
    'stock_rows_posted', v_stock_count,
    'stock_ready', (SELECT stock_ready FROM public.global_shipments WHERE id = p_shipment_id),
    'movement_id', v_mov_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.post_shipment_outcome_stock(
  p_shipment_id bigint,
  p_stock_rows jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_parent bigint;
BEGIN
  SELECT parent_tenant_id INTO v_parent
  FROM public.global_shipments
  WHERE id = p_shipment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_parent_tenant(v_parent) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  RETURN public._stock_spine_receive_shipment_outcomes(p_shipment_id, p_stock_rows);
END;
$$;

GRANT EXECUTE ON FUNCTION public._stock_spine_upsert_receive_lot(
  bigint, bigint, bigint, bigint, integer, bigint, public.stock_availability, bigint
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._stock_spine_finalize_inbound_movement(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._stock_spine_receive_shipment_outcomes(bigint, jsonb) TO authenticated, service_role;

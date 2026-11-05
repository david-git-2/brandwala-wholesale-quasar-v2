-- Stock spine WMS RPCs part 2: cycle count, delivery paper pack/dispatch, short-pick, status, bill guard.

CREATE OR REPLACE FUNCTION public.create_stock_physical_count(
  p_tenant_id bigint,
  p_location_id bigint DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.stock_physical_counts%rowtype;
BEGIN
  IF NOT public.has_active_tenant_membership(p_tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  INSERT INTO public.stock_physical_counts (
    parent_tenant_id,
    location_id,
    status,
    notes,
    created_by_email
  ) VALUES (
    p_tenant_id,
    p_location_id,
    'draft'::public.stock_physical_count_status,
    p_notes,
    public.current_user_email()
  )
  RETURNING * INTO v_row;

  RETURN jsonb_build_object('success', true, 'count', to_jsonb(v_row));
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_stock_physical_count_line(
  p_count_id bigint,
  p_stock_id bigint,
  p_counted_qty integer,
  p_recount_qty integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count public.stock_physical_counts%rowtype;
  v_stock public.global_stocks%rowtype;
  v_line public.stock_physical_count_lines%rowtype;
BEGIN
  SELECT * INTO v_count
  FROM public.stock_physical_counts
  WHERE id = p_count_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'count session not found';
  END IF;

  IF v_count.status NOT IN (
    'draft'::public.stock_physical_count_status,
    'counting'::public.stock_physical_count_status
  ) THEN
    RAISE EXCEPTION 'count session is not editable';
  END IF;

  IF NOT public.has_active_tenant_membership(v_count.parent_tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT * INTO v_stock
  FROM public.global_stocks
  WHERE id = p_stock_id
    AND parent_tenant_id = v_count.parent_tenant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'stock % not found', p_stock_id;
  END IF;

  IF v_count.location_id IS NOT NULL
     AND v_stock.location_id IS DISTINCT FROM v_count.location_id THEN
    RAISE EXCEPTION 'stock % is outside count location scope', p_stock_id;
  END IF;

  INSERT INTO public.stock_physical_count_lines (
    count_id,
    global_stock_id,
    system_qty,
    counted_qty,
    recount_qty
  ) VALUES (
    p_count_id,
    p_stock_id,
    v_stock.quantity,
    p_counted_qty,
    p_recount_qty
  )
  ON CONFLICT (count_id, global_stock_id) DO UPDATE SET
    system_qty = EXCLUDED.system_qty,
    counted_qty = EXCLUDED.counted_qty,
    recount_qty = COALESCE(EXCLUDED.recount_qty, stock_physical_count_lines.recount_qty),
    updated_at = now()
  RETURNING * INTO v_line;

  UPDATE public.stock_physical_counts
  SET
    status = 'counting'::public.stock_physical_count_status,
    updated_at = now()
  WHERE id = p_count_id;

  RETURN jsonb_build_object('success', true, 'line', to_jsonb(v_line));
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_stock_physical_count(p_count_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count public.stock_physical_counts%rowtype;
BEGIN
  SELECT * INTO v_count
  FROM public.stock_physical_counts
  WHERE id = p_count_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'count session not found';
  END IF;

  IF NOT public.has_active_tenant_membership(v_count.parent_tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF v_count.status NOT IN (
    'draft'::public.stock_physical_count_status,
    'counting'::public.stock_physical_count_status
  ) THEN
    RAISE EXCEPTION 'count session cannot be submitted from status %', v_count.status;
  END IF;

  UPDATE public.stock_physical_counts
  SET
    status = 'pending_approval'::public.stock_physical_count_status,
    submitted_at = now(),
    updated_at = now()
  WHERE id = p_count_id;

  RETURN jsonb_build_object('success', true, 'status', 'pending_approval');
END;
$$;

CREATE OR REPLACE FUNCTION public.approve_stock_physical_count(p_count_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count public.stock_physical_counts%rowtype;
  v_line public.stock_physical_count_lines%rowtype;
  v_stock public.global_stocks%rowtype;
  v_mov_payload jsonb;
  v_mov_id bigint;
  v_final_qty integer;
  v_variance integer;
  v_line_count integer := 0;
BEGIN
  SELECT * INTO v_count
  FROM public.stock_physical_counts
  WHERE id = p_count_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'count session not found';
  END IF;

  IF v_count.status <> 'pending_approval'::public.stock_physical_count_status THEN
    RAISE EXCEPTION 'count session must be pending_approval';
  END IF;

  IF NOT public.has_active_tenant_membership(v_count.parent_tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF v_count.movement_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'status', 'posted',
      'movement_id', v_count.movement_id
    );
  END IF;

  v_mov_payload := public.create_stock_movement(
    v_count.parent_tenant_id,
    'adjustment'::public.stock_movement_type,
    coalesce(v_count.notes, 'Cycle count approve'),
    'stock_physical_count',
    p_count_id::text
  );
  v_mov_id := (v_mov_payload->'movement'->>'id')::bigint;

  FOR v_line IN
    SELECT * FROM public.stock_physical_count_lines WHERE count_id = p_count_id
  LOOP
    v_final_qty := coalesce(v_line.recount_qty, v_line.counted_qty, v_line.system_qty);
    UPDATE public.stock_physical_count_lines
    SET approved_qty = v_final_qty, updated_at = now()
    WHERE id = v_line.id;

    v_variance := v_final_qty - v_line.system_qty;
    IF v_variance = 0 THEN
      CONTINUE;
    END IF;

    SELECT * INTO v_stock
    FROM public.global_stocks
    WHERE id = v_line.global_stock_id
      AND parent_tenant_id = v_count.parent_tenant_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'stock % not found for count line', v_line.global_stock_id;
    END IF;

    IF v_variance > 0 THEN
      PERFORM public.add_stock_movement_line(
        v_mov_id,
        v_line.global_stock_id,
        abs(v_variance),
        v_stock.location_id,
        v_stock.location_id,
        NULL,
        v_stock.availability,
        NULL,
        v_stock.grade_tag_id
      );
    ELSE
      PERFORM public.add_stock_movement_line(
        v_mov_id,
        v_line.global_stock_id,
        abs(v_variance),
        v_stock.location_id,
        v_stock.location_id,
        v_stock.availability,
        NULL,
        NULL,
        NULL
      );
    END IF;
    v_line_count := v_line_count + 1;
  END LOOP;

  IF v_line_count > 0 THEN
    PERFORM public.post_stock_movement(v_mov_id);
  ELSE
    DELETE FROM public.stock_movements WHERE id = v_mov_id;
    v_mov_id := NULL;
  END IF;

  UPDATE public.stock_physical_counts
  SET
    status = 'posted'::public.stock_physical_count_status,
    movement_id = v_mov_id,
    approved_at = now(),
    updated_at = now()
  WHERE id = p_count_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'posted',
    'movement_id', v_mov_id,
    'variance_lines', v_line_count
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_delivery_paper_packed(
  p_tenant_id bigint,
  p_delivery_paper_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_line public.delivery_paper_line%rowtype;
  v_packed integer;
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

  IF v_paper.status = 'packed'::public.delivery_paper_status THEN
    RETURN jsonb_build_object('success', true, 'status', 'packed', 'idempotent', true);
  END IF;

  IF v_paper.status <> 'draft'::public.delivery_paper_status THEN
    RAISE EXCEPTION 'delivery paper must be draft to mark packed (current: %)', v_paper.status;
  END IF;

  FOR v_line IN
    SELECT * FROM public.delivery_paper_line dpl
    WHERE dpl.delivery_paper_id = p_delivery_paper_id
  LOOP
    v_packed := public.delivery_paper_line_packed_qty(v_line.splits);
    IF v_line.global_stock_id IS NOT NULL AND v_packed <= 0 THEN
      RAISE EXCEPTION 'line % has no packed quantity', v_line.id;
    END IF;
    IF v_line.global_stock_id IS NULL AND coalesce(v_line.quantity, 0) <= 0 AND v_packed <= 0 THEN
      RAISE EXCEPTION 'planning line % has no quantity', v_line.id;
    END IF;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM public.delivery_paper_line dpl
    WHERE dpl.delivery_paper_id = p_delivery_paper_id
  ) THEN
    RAISE EXCEPTION 'delivery paper has no lines';
  END IF;

  UPDATE public.delivery_paper dp
  SET status = 'packed'::public.delivery_paper_status, updated_at = now()
  WHERE dp.id = p_delivery_paper_id;

  RETURN jsonb_build_object('success', true, 'status', 'packed');
END;
$$;

CREATE OR REPLACE FUNCTION public.dispatch_delivery_paper(
  p_tenant_id bigint,
  p_delivery_paper_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
    v_qty := greatest(
      public.delivery_paper_line_packed_qty(v_line.splits),
      coalesce(v_line.quantity, 0)
    );
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
$$;

CREATE OR REPLACE FUNCTION public.record_delivery_paper_short_pick(
  p_tenant_id bigint,
  p_delivery_paper_id bigint,
  p_line_id bigint,
  p_picked_qty integer,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_line public.delivery_paper_line%rowtype;
  v_requested integer;
  v_short integer;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  IF p_picked_qty IS NULL OR p_picked_qty < 0 THEN
    RAISE EXCEPTION 'picked_qty must be >= 0';
  END IF;

  SELECT * INTO v_paper
  FROM public.delivery_paper dp
  WHERE dp.id = p_delivery_paper_id
    AND dp.parent_tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper not found';
  END IF;

  IF v_paper.status NOT IN (
    'draft'::public.delivery_paper_status,
    'packed'::public.delivery_paper_status
  ) THEN
    RAISE EXCEPTION 'short pick not allowed when paper status is %', v_paper.status;
  END IF;

  SELECT * INTO v_line
  FROM public.delivery_paper_line dpl
  WHERE dpl.id = p_line_id
    AND dpl.delivery_paper_id = p_delivery_paper_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper line not found';
  END IF;

  v_requested := greatest(
    public.delivery_paper_line_packed_qty(v_line.splits),
    coalesce(v_line.quantity, 0)
  );

  IF p_picked_qty >= v_requested THEN
    RAISE EXCEPTION 'short pick requires picked_qty < requested (% >= %)', p_picked_qty, v_requested;
  END IF;

  v_short := v_requested - p_picked_qty;

  INSERT INTO public.delivery_paper_pick_exceptions (
    delivery_paper_id,
    delivery_paper_line_id,
    requested_qty,
    picked_qty,
    reason,
    created_by_email
  ) VALUES (
    p_delivery_paper_id,
    p_line_id,
    v_requested,
    p_picked_qty,
    p_reason,
    public.current_user_email()
  );

  UPDATE public.delivery_paper_line dpl
  SET
    quantity = p_picked_qty,
    splits = jsonb_build_array(
      jsonb_build_object('quantity', p_picked_qty, 'status', 'packed')
    ),
    updated_at = now()
  WHERE dpl.id = p_line_id;

  UPDATE public.preorder_demand pd
  SET
    open_quantity = coalesce(pd.open_quantity, 0) + v_short,
    updated_at = now()
  WHERE pd.id = v_line.preorder_demand_id;

  RETURN jsonb_build_object(
    'success', true,
    'requested_qty', v_requested,
    'picked_qty', p_picked_qty,
    'short_qty', v_short
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.update_delivery_paper_status(
  p_tenant_id bigint,
  p_delivery_paper_id bigint,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_new public.delivery_paper_status;
  v_dispatch jsonb;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  IF p_delivery_paper_id IS NULL THEN
    RAISE EXCEPTION 'delivery_paper_id is required';
  END IF;

  BEGIN
    v_new := lower(trim(coalesce(p_status, '')))::public.delivery_paper_status;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'invalid delivery paper status: %', p_status;
  END;

  IF v_new = 'packed'::public.delivery_paper_status THEN
    RETURN public.mark_delivery_paper_packed(p_tenant_id, p_delivery_paper_id);
  END IF;

  IF v_new = 'dispatched'::public.delivery_paper_status THEN
    RETURN public.dispatch_delivery_paper(p_tenant_id, p_delivery_paper_id);
  END IF;

  SELECT * INTO v_paper
  FROM public.delivery_paper dp
  WHERE dp.id = p_delivery_paper_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper not found';
  END IF;

  IF v_paper.status <> 'draft'::public.delivery_paper_status
     AND v_new = 'draft'::public.delivery_paper_status THEN
    RAISE EXCEPTION 'delivery paper cannot return to draft after it has left draft';
  END IF;

  IF v_paper.status = v_new THEN
    RETURN jsonb_build_object('success', true, 'status', v_new);
  END IF;

  UPDATE public.delivery_paper dp
  SET status = v_new, updated_at = now()
  WHERE dp.id = p_delivery_paper_id;

  RETURN jsonb_build_object('success', true, 'status', v_new);
END;
$$;

GRANT EXECUTE ON FUNCTION public.post_stock_movement(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.stock_dispatch_deduct_covers(bigint, bigint, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delivery_paper_dispatch_movement_id(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_stock_physical_count(bigint, bigint, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.upsert_stock_physical_count_line(bigint, bigint, integer, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_stock_physical_count(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.approve_stock_physical_count(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mark_delivery_paper_packed(bigint, bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.dispatch_delivery_paper(bigint, bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_delivery_paper_short_pick(bigint, bigint, bigint, integer, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_delivery_paper_status(bigint, bigint, text) TO authenticated, service_role;

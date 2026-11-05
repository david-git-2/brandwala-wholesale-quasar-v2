-- delivery_paper_line has no quantity column; qty lives in splits jsonb only.

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
  v_line_total integer;
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
    v_line_total := public.delivery_paper_line_total_qty(v_line.splits);
    IF v_line.global_stock_id IS NOT NULL AND v_packed <= 0 THEN
      RAISE EXCEPTION 'line % has no packed quantity', v_line.id;
    END IF;
    IF v_line.global_stock_id IS NULL AND v_line_total <= 0 AND v_packed <= 0 THEN
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

  v_requested := public.delivery_paper_line_packed_qty(v_line.splits);

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

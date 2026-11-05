CREATE FUNCTION public.approve_stock_physical_count (
  p_count_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.approve_stock_physical_count(bigint) TO anon;

GRANT ALL ON FUNCTION public.approve_stock_physical_count(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.approve_stock_physical_count(bigint) TO service_role;
CREATE FUNCTION public.record_delivery_paper_short_pick (
  p_tenant_id         bigint,
  p_delivery_paper_id bigint,
  p_line_id           bigint,
  p_picked_qty        integer,
  p_reason            text    DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.record_delivery_paper_short_pick(bigint, bigint, bigint, integer, text) TO anon;

GRANT ALL ON FUNCTION public.record_delivery_paper_short_pick(bigint, bigint, bigint, integer, text) TO authenticated;

GRANT ALL ON FUNCTION public.record_delivery_paper_short_pick(bigint, bigint, bigint, integer, text) TO service_role;
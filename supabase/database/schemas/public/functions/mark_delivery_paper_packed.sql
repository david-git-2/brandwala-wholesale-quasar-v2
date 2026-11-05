CREATE FUNCTION public.mark_delivery_paper_packed (
  p_tenant_id         bigint,
  p_delivery_paper_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.mark_delivery_paper_packed(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.mark_delivery_paper_packed(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.mark_delivery_paper_packed(bigint, bigint) TO service_role;
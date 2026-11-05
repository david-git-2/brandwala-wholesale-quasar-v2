CREATE FUNCTION public.delivery_paper_line_reduce_null_plan_splits (
  p_delivery_paper_id  bigint,
  p_preorder_demand_id bigint,
  p_status             text,
  p_reduce_qty         integer
)
  RETURNS void
  LANGUAGE plpgsql
  AS $function$
DECLARE
  v_line public.delivery_paper_line%rowtype;
  v_target text := lower(trim(coalesce(p_status, '')));
  v_need integer := greatest(coalesce(p_reduce_qty, 0), 0);
  v_elem jsonb;
  v_status text;
  v_qty integer;
  v_take integer;
  v_out jsonb := '[]'::jsonb;
BEGIN
  IF v_need <= 0 THEN
    RETURN;
  END IF;

  IF v_target NOT IN ('accepted', 'conditioned', 'rejected') THEN
    RETURN;
  END IF;

  SELECT * INTO v_line
  FROM public.delivery_paper_line dpl
  WHERE dpl.delivery_paper_id = p_delivery_paper_id
    AND dpl.preorder_demand_id = p_preorder_demand_id
    AND dpl.global_stock_id IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  FOR v_elem IN SELECT value FROM jsonb_array_elements(coalesce(v_line.splits, '[]'::jsonb)) LOOP
    v_status := lower(trim(coalesce(v_elem->>'status', '')));
    v_qty := greatest(0, coalesce((v_elem->>'quantity')::integer, 0));

    IF v_qty <= 0 THEN
      CONTINUE;
    END IF;

    IF v_status = v_target
      AND nullif(v_elem->>'invoice_id', '') IS NULL
      AND nullif(v_elem->>'returned_at', '') IS NULL
      AND v_need > 0
    THEN
      v_take := least(v_need, v_qty);
      v_need := v_need - v_take;
      v_qty := v_qty - v_take;
    END IF;

    IF v_qty > 0 THEN
      v_out := v_out || jsonb_build_array(v_elem || jsonb_build_object('quantity', v_qty));
    END IF;
  END LOOP;

  IF jsonb_array_length(v_out) = 0 THEN
    DELETE FROM public.delivery_paper_line dpl WHERE dpl.id = v_line.id;
  ELSE
    IF NOT public.validate_delivery_paper_line_splits(v_out) THEN
      RAISE EXCEPTION 'invalid splits after null plan reconcile';
    END IF;
    UPDATE public.delivery_paper_line dpl
    SET splits = v_out, updated_at = now()
    WHERE dpl.id = v_line.id;
  END IF;
END;
$function$;

GRANT ALL ON FUNCTION public.delivery_paper_line_reduce_null_plan_splits(bigint, bigint, text, integer) TO anon;

GRANT ALL ON FUNCTION public.delivery_paper_line_reduce_null_plan_splits(bigint, bigint, text, integer) TO authenticated;

GRANT ALL ON FUNCTION public.delivery_paper_line_reduce_null_plan_splits(bigint, bigint, text, integer) TO service_role;
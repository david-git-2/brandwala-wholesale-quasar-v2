CREATE FUNCTION public.delivery_paper_line_lock_for_outcome (
  p_delivery_paper_id  bigint,
  p_allocation         jsonb
)
  RETURNS public.delivery_paper_line
  LANGUAGE plpgsql
  AS $function$
DECLARE
  v_line public.delivery_paper_line%rowtype;
  v_line_id bigint;
  v_demand_id bigint;
  v_stock_id bigint;
BEGIN
  v_line_id := nullif(p_allocation->>'delivery_paper_line_id', '')::bigint;
  v_demand_id := nullif(p_allocation->>'preorder_demand_id', '')::bigint;
  v_stock_id := nullif(p_allocation->>'global_stock_id', '')::bigint;

  IF v_line_id IS NOT NULL THEN
    SELECT * INTO v_line
    FROM public.delivery_paper_line dpl
    WHERE dpl.id = v_line_id
      AND dpl.delivery_paper_id = p_delivery_paper_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'delivery paper line % not found', v_line_id;
    END IF;

    IF v_demand_id IS NOT NULL AND v_line.preorder_demand_id IS DISTINCT FROM v_demand_id THEN
      RAISE EXCEPTION 'delivery_paper_line_id % does not match preorder_demand_id', v_line_id;
    END IF;

    RETURN v_line;
  END IF;

  IF v_demand_id IS NULL OR v_stock_id IS NULL THEN
    RAISE EXCEPTION 'each allocation requires delivery_paper_line_id or preorder_demand_id with global_stock_id';
  END IF;

  SELECT * INTO v_line
  FROM public.delivery_paper_line dpl
  WHERE dpl.delivery_paper_id = p_delivery_paper_id
    AND dpl.preorder_demand_id = v_demand_id
    AND (
      dpl.global_stock_id = v_stock_id
      OR dpl.dispatched_global_stock_id = v_stock_id
    )
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper line not found for demand % stock %', v_demand_id, v_stock_id;
  END IF;

  RETURN v_line;
END;
$function$;

GRANT ALL ON FUNCTION public.delivery_paper_line_lock_for_outcome(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.delivery_paper_line_lock_for_outcome(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.delivery_paper_line_lock_for_outcome(bigint, jsonb) TO service_role;

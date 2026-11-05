CREATE FUNCTION public.upsert_stock_physical_count_line (
  p_count_id    bigint,
  p_stock_id    bigint,
  p_counted_qty integer,
  p_recount_qty integer DEFAULT NULL::integer
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.upsert_stock_physical_count_line(bigint, bigint, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.upsert_stock_physical_count_line(bigint, bigint, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_stock_physical_count_line(bigint, bigint, integer, integer) TO service_role;
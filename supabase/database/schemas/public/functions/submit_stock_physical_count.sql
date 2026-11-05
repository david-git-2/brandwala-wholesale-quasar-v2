CREATE FUNCTION public.submit_stock_physical_count (
  p_count_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.submit_stock_physical_count(bigint) TO anon;

GRANT ALL ON FUNCTION public.submit_stock_physical_count(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.submit_stock_physical_count(bigint) TO service_role;
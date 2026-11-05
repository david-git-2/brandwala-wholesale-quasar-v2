CREATE FUNCTION public.delete_cashbook_point_for_staff (
  p_tenant_id bigint,
  p_point_id  bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_books_id bigint;
  v_point public.cashbook_points;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  IF NOT public.wallet_staff_can_edit(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  SELECT * INTO v_point
  FROM public.cashbook_points cp
  WHERE cp.id = p_point_id
    AND cp.parent_tenant_id = v_books_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'cash point not found');
  END IF;

  UPDATE public.cashbook_entries
  SET cashbook_point_id = NULL
  WHERE cashbook_point_id = p_point_id;

  DELETE FROM public.cashbook_points
  WHERE id = p_point_id;

  RETURN jsonb_build_object('success', true, 'id', p_point_id);
END;
$function$;

GRANT ALL ON FUNCTION public.delete_cashbook_point_for_staff(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.delete_cashbook_point_for_staff(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delete_cashbook_point_for_staff(bigint, bigint) TO service_role;
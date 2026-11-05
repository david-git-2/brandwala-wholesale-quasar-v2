CREATE FUNCTION public.staff_mark_pbc_packed (
  p_file_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_file record;
BEGIN
  SELECT * INTO v_file
  FROM public.product_based_costing_files
  WHERE id = p_file_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'costing file not found: %', p_file_id;
  END IF;

  IF NOT public.is_tenant_staff(v_file.tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF public.normalize_pbc_procurement_status(v_file.status) <> 'procuring' THEN
    RAISE EXCEPTION 'costing file must be procuring to mark dispatch';
  END IF;

  UPDATE public.product_based_costing_files
  SET status = 'dispatch', updated_at = now()
  WHERE id = p_file_id;

  RETURN jsonb_build_object(
    'success', true,
    'file_id', p_file_id,
    'status', 'dispatch'
  );
END;
$function$;

GRANT ALL ON FUNCTION public.staff_mark_pbc_packed(bigint) TO anon;

GRANT ALL ON FUNCTION public.staff_mark_pbc_packed(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.staff_mark_pbc_packed(bigint) TO service_role;
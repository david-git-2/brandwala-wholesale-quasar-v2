CREATE FUNCTION public.create_stock_physical_count (
  p_tenant_id   bigint,
  p_location_id bigint DEFAULT NULL::bigint,
  p_notes       text   DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_row public.stock_physical_counts%rowtype;
BEGIN
  IF NOT public.has_active_tenant_membership(p_tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  INSERT INTO public.stock_physical_counts (
    parent_tenant_id,
    location_id,
    status,
    notes,
    created_by_email
  ) VALUES (
    p_tenant_id,
    p_location_id,
    'draft'::public.stock_physical_count_status,
    p_notes,
    public.current_user_email()
  )
  RETURNING * INTO v_row;

  RETURN jsonb_build_object('success', true, 'count', to_jsonb(v_row));
END;
$function$;

GRANT ALL ON FUNCTION public.create_stock_physical_count(bigint, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.create_stock_physical_count(bigint, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.create_stock_physical_count(bigint, bigint, text) TO service_role;
CREATE FUNCTION public.post_shipment_outcome_stock (
  p_shipment_id bigint,
  p_stock_rows  jsonb  DEFAULT NULL::jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_parent bigint;
BEGIN
  SELECT parent_tenant_id INTO v_parent
  FROM public.global_shipments
  WHERE id = p_shipment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_parent_tenant(v_parent) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  RETURN public._stock_spine_receive_shipment_outcomes(p_shipment_id, p_stock_rows);
END;
$function$;

GRANT ALL ON FUNCTION public.post_shipment_outcome_stock(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.post_shipment_outcome_stock(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.post_shipment_outcome_stock(bigint, jsonb) TO service_role;
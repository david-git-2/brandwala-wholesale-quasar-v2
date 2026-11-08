CREATE FUNCTION public.list_shipment_payee_settlements (
  p_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
BEGIN
  SELECT * INTO v_ship
  FROM public.global_shipments
  WHERE id = p_shipment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.has_active_tenant_membership(v_ship.tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  RETURN jsonb_build_object(
    'vendor', public.get_payee_settlement_summary(v_ship.tenant_id, p_shipment_id, 'vendor', v_ship.vendor_id),
    'cargo_company', public.get_payee_settlement_summary(v_ship.tenant_id, p_shipment_id, 'cargo_company', v_ship.cargo_company_id)
  );
END;
$function$;

GRANT ALL ON FUNCTION public.list_shipment_payee_settlements(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_shipment_payee_settlements(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_shipment_payee_settlements(bigint) TO service_role;
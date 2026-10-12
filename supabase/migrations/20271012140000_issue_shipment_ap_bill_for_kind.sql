-- Per-bucket AP issue (draft → issued) without issuing all shipment AP bills.

CREATE OR REPLACE FUNCTION public.issue_shipment_ap_bill_for_kind(p_shipment_id bigint, p_ap_kind text)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_parent bigint;
  v_bill_id bigint;
BEGIN
  IF p_shipment_id IS NULL THEN
    RAISE EXCEPTION 'shipment_id is required';
  END IF;

  IF p_ap_kind IS NULL OR trim(p_ap_kind) = '' THEN
    RAISE EXCEPTION 'ap_kind is required';
  END IF;

  IF p_ap_kind NOT IN (
    'vendor', 'cargo', 'local',
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ) THEN
    RAISE EXCEPTION 'Invalid ap_kind %', p_ap_kind;
  END IF;

  SELECT gs.parent_tenant_id INTO v_parent
  FROM public.global_shipments gs
  WHERE gs.id = p_shipment_id;

  IF v_parent IS NULL THEN
    RAISE EXCEPTION 'Shipment % not found', p_shipment_id;
  END IF;

  IF NOT (
    coalesce(auth.role(), '') = 'service_role'
    OR public.user_can_manage_parent_tenant(v_parent)
  ) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  UPDATE public.bills b
  SET
    invoice_status = 'issued'::public.global_invoice_status,
    payment_status = coalesce(nullif(b.payment_status, ''), 'due'),
    updated_at = now()
  WHERE b.parent_tenant_id = v_parent
    AND b.ap_shipment_id = p_shipment_id
    AND b.invoice_type = 'ap'::public.global_invoice_type
    AND b.ap_kind = p_ap_kind
    AND b.invoice_status = 'draft'::public.global_invoice_status
    AND coalesce(b.total_amount, 0) > 0
  RETURNING b.id INTO v_bill_id;

  IF v_bill_id IS NULL THEN
    RAISE EXCEPTION 'No draft AP bill to issue for bucket %', p_ap_kind;
  END IF;

  RETURN v_bill_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.issue_shipment_ap_bill_for_kind(bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.issue_shipment_ap_bill_for_kind(bigint, text) TO service_role;

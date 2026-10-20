-- Settings drawer: one finance bundle (cost entries, AP bills, FX) with narrow JSON projections.

CREATE OR REPLACE FUNCTION public.get_shipment_settings_finance_bundle(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_parent bigint;
  v_cost_entries jsonb;
  v_ap_bills jsonb;
  v_ap_fx jsonb;
  v_sid text;
BEGIN
  SELECT gs.parent_tenant_id INTO v_parent
  FROM public.global_shipments gs
  WHERE gs.id = p_shipment_id;

  IF v_parent IS NULL THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT (
    public.user_can_manage_parent_tenant(v_parent)
    OR EXISTS (
      SELECT 1 FROM public.memberships m
      WHERE m.tenant_id = v_parent
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
    )
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  PERFORM public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);
  PERFORM public.sync_shipment_ap_bills(p_shipment_id);

  v_sid := p_shipment_id::text;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ce.id,
        'shipment_id', ce.shipment_id,
        'cost_bucket', ce.cost_bucket,
        'cost_component', ce.cost_component,
        'is_capitalizable', ce.is_capitalizable,
        'description', ce.description,
        'amount', ce.amount,
        'currency_id', ce.currency_id,
        'metadata', ce.metadata,
        'section_id', ce.section_id
      )
      ORDER BY ce.cost_bucket, ce.cost_component, ce.id
    ),
    '[]'::jsonb
  )
  INTO v_cost_entries
  FROM public.global_shipment_cost_entries ce
  WHERE ce.shipment_id = p_shipment_id;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'invoice_no', b.invoice_no,
        'ap_kind', b.ap_kind,
        'source_type', b.source_type,
        'source_id', b.source_id,
        'source_key', b.source_key,
        'invoice_status', b.invoice_status,
        'payment_status', b.payment_status,
        'total_amount', b.total_amount,
        'due_amount', b.due_amount
      )
      ORDER BY b.id
    ),
    '[]'::jsonb
  )
  INTO v_ap_bills
  FROM public.bills b
  WHERE b.invoice_type = 'ap'
    AND b.document_kind = 'standard'
    AND b.invoice_status <> 'voided'
    AND (
      (b.source_type = 'shipment_cost' AND b.source_id = v_sid)
      OR b.ap_shipment_id = p_shipment_id
    )
    AND coalesce(b.source_key, b.ap_kind) IN (
      'material', 'freight', 'customs', 'handling', 'finance', 'other',
      'vendor', 'cargo', 'local'
    );

  v_ap_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_ap_fx := v_ap_fx - 'blended_rate';

  RETURN jsonb_build_object(
    'cost_entries', v_cost_entries,
    'ap_bills', v_ap_bills,
    'ap_fx', v_ap_fx
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_shipment_settings_finance_bundle(bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_shipment_settings_finance_bundle(bigint) TO authenticated;

-- Allow void_shipment_ap_bill_v2 for sync-created legacy public.bills (and broader kernel link checks).

CREATE OR REPLACE FUNCTION public._shipment_bill_belongs_to_shipment(
  p_shipment_id bigint,
  p_bill_id bigint
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_found boolean := false;
  v_parent bigint;
  v_issued_by bigint;
BEGIN
  SELECT gs.tenant_id, COALESCE(gs.assigned_child_tenant_id, gs.tenant_id)
    INTO v_parent, v_issued_by
  FROM public.global_shipments gs
  WHERE gs.id = p_shipment_id;

  SELECT EXISTS (
    SELECT 1 FROM jsonb_array_elements(
      COALESCE((SELECT buckets FROM public.global_shipments WHERE id = p_shipment_id), '[]'::jsonb)
    ) elem
    WHERE (elem->>'bill_id')::bigint = p_bill_id
  ) INTO v_found;
  IF v_found THEN
    RETURN true;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM money_kernel.bills b
     WHERE b.id = p_bill_id
       AND b.kind = 'shipment_cost_ap'
       AND (
         (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
         OR (b.meta->>'shipment_id')::bigint = p_shipment_id
       )
  ) INTO v_found;
  IF v_found THEN
    RETURN true;
  END IF;

  IF v_parent IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.bills b
      WHERE b.id = p_bill_id
        AND b.tenant_id IN (v_parent, v_issued_by)
        AND b.invoice_type = 'ap'::public.global_invoice_type
        AND b.document_kind = 'standard'::public.bill_document_kind
        AND (
          (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
          OR b.ap_shipment_id = p_shipment_id
        )
    ) INTO v_found;
  END IF;

  RETURN COALESCE(v_found, false);
END;
$$;

CREATE OR REPLACE FUNCTION public.void_shipment_ap_bill_v2(p_shipment_id bigint, p_bill_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent bigint;
  v_issued_by bigint;
  v_bill money_kernel.bills;
  v_legacy public.bills;
  v_result jsonb;
BEGIN
  PERFORM public._shipment_money_advisory_lock(p_shipment_id);

  SELECT gs.tenant_id, COALESCE(gs.assigned_child_tenant_id, gs.tenant_id)
    INTO v_parent, v_issued_by
  FROM public.global_shipments gs
  WHERE gs.id = p_shipment_id
  FOR UPDATE;
  IF v_parent IS NULL THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_books_tenant(v_parent) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  IF NOT public._shipment_bill_belongs_to_shipment(p_shipment_id, p_bill_id) THEN
    RAISE EXCEPTION 'bill % is not linked to shipment %', p_bill_id, p_shipment_id;
  END IF;

  SELECT * INTO v_bill FROM money_kernel.bills
   WHERE id = p_bill_id AND tenant_id = v_parent;
  IF FOUND THEN
    IF v_bill.status <> 'draft' THEN
      RAISE EXCEPTION 'only draft bills can be deleted (voided)';
    END IF;

    v_result := public.rpc_void_bill(v_parent, p_bill_id);
    PERFORM public._shipment_buckets_remove(p_shipment_id, p_bill_id);

    RETURN v_result || jsonb_build_object('shipment_id', p_shipment_id, 'bill_id', p_bill_id);
  END IF;

  SELECT * INTO v_legacy
  FROM public.bills b
  WHERE b.id = p_bill_id
    AND b.tenant_id IN (v_parent, v_issued_by)
    AND b.invoice_type = 'ap'::public.global_invoice_type
    AND b.document_kind = 'standard'::public.bill_document_kind
    AND (
      (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
      OR b.ap_shipment_id = p_shipment_id
    );

  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;
  IF v_legacy.invoice_status IS DISTINCT FROM 'draft'::public.global_invoice_status THEN
    RAISE EXCEPTION 'only draft bills can be deleted (voided)';
  END IF;
  IF COALESCE(v_legacy.paid_amount, 0) > 0 THEN
    RAISE EXCEPTION 'cannot void a bill with payments';
  END IF;

  PERFORM public.void_bill(p_bill_id);

  RETURN jsonb_build_object(
    'bill_id', p_bill_id,
    'status', 'voided',
    'shipment_id', p_shipment_id
  );
END;
$$;

-- Shipment Costs: delete draft AP bills (remove row), do not leave voided tombstones.

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
   WHERE id = p_bill_id AND tenant_id = v_parent
   FOR UPDATE;
  IF FOUND THEN
    IF v_bill.status <> 'draft' THEN
      RAISE EXCEPTION 'only draft bills can be permanently deleted';
    END IF;
    IF EXISTS (
      SELECT 1 FROM money_kernel.bill_settlements bs
      WHERE bs.bill_id = p_bill_id OR bs.source_bill_id = p_bill_id
    ) THEN
      RAISE EXCEPTION 'cannot delete bill with settlements';
    END IF;

    PERFORM public.assert_kernel_money_access(v_parent, 'void');
    PERFORM public._shipment_buckets_remove(p_shipment_id, p_bill_id);

    DELETE FROM money_kernel.bills
     WHERE id = p_bill_id AND tenant_id = v_parent;

    DELETE FROM public.bills pb
     WHERE pb.id = p_bill_id
       AND pb.tenant_id IN (v_parent, v_issued_by)
       AND pb.invoice_status = 'draft'::public.global_invoice_status
       AND NOT EXISTS (
         SELECT 1 FROM public.bill_settlements bs WHERE bs.bill_id = pb.id
       );

    RETURN jsonb_build_object(
      'bill_id', p_bill_id,
      'status', 'deleted',
      'permanent', true,
      'shipment_id', p_shipment_id
    );
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
    )
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;
  IF v_legacy.invoice_status IS DISTINCT FROM 'draft'::public.global_invoice_status THEN
    RAISE EXCEPTION 'only draft bills can be permanently deleted';
  END IF;
  IF COALESCE(v_legacy.paid_amount, 0) > 0 THEN
    RAISE EXCEPTION 'cannot delete a bill with payments';
  END IF;
  IF EXISTS (SELECT 1 FROM public.bill_settlements bs WHERE bs.bill_id = p_bill_id) THEN
    RAISE EXCEPTION 'cannot delete bill with settlements';
  END IF;

  PERFORM public._shipment_buckets_remove(p_shipment_id, p_bill_id);
  DELETE FROM public.bills WHERE id = p_bill_id;

  RETURN jsonb_build_object(
    'bill_id', p_bill_id,
    'status', 'deleted',
    'permanent', true,
    'shipment_id', p_shipment_id
  );
END;
$$;

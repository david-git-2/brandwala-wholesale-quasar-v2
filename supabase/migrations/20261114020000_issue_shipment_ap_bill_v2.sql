-- Issue one shipment AP draft + return finance bundle (one round trip).

CREATE OR REPLACE FUNCTION public.issue_shipment_ap_bill_v2(
  p_shipment_id bigint,
  p_bill_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent bigint;
  v_bill money_kernel.bills;
  v_issue jsonb;
  v_bundle jsonb;
BEGIN
  PERFORM public._shipment_money_advisory_lock(p_shipment_id);

  SELECT tenant_id INTO v_parent
    FROM public.global_shipments
   WHERE id = p_shipment_id
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

  SELECT * INTO v_bill
    FROM money_kernel.bills
   WHERE id = p_bill_id AND tenant_id = v_parent
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;
  IF v_bill.kind IS DISTINCT FROM 'shipment_cost_ap' THEN
    RAISE EXCEPTION 'not a shipment cost AP bill';
  END IF;
  IF v_bill.status NOT IN ('draft', 'issued') THEN
    RAISE EXCEPTION 'cannot issue bill in status %', v_bill.status;
  END IF;

  IF v_bill.status = 'draft' THEN
    PERFORM set_config('app.bill_desk_issue_shipment_ap', '1', true);
    PERFORM set_config('app.shipment_ap_issue', '1', true);
    BEGIN
      v_issue := public.rpc_issue_bill(v_parent, p_bill_id);
    EXCEPTION
      WHEN OTHERS THEN
        PERFORM set_config('app.bill_desk_issue_shipment_ap', '0', true);
        PERFORM set_config('app.shipment_ap_issue', '0', true);
        RAISE;
    END;
    PERFORM set_config('app.bill_desk_issue_shipment_ap', '0', true);
    PERFORM set_config('app.shipment_ap_issue', '0', true);
  ELSE
    v_issue := jsonb_build_object(
      'bill_id', v_bill.id,
      'invoice_no', v_bill.invoice_no,
      'status', 'issued',
      'idempotent', true
    );
  END IF;

  v_bundle := public.get_shipment_money_kernel_bundle(p_shipment_id);

  RETURN jsonb_build_object(
    'shipment_id', p_shipment_id,
    'bill_id', p_bill_id,
    'issue', v_issue,
    'finance_bundle', v_bundle
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.issue_shipment_ap_bill_v2(bigint, bigint) TO authenticated, service_role;

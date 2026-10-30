-- Shipment AP lifecycle guards + upsert immutability
BEGIN;

SELECT plan(4);

DO $$
DECLARE
  v_kernel jsonb;
  v_parent bigint;
  v_shipment bigint;
  v_err text;
BEGIN
  v_kernel := public._test_money_kernel_bootstrap();
  v_parent := (v_kernel ->> 'tenant_id')::bigint;

  INSERT INTO public.global_shipments (
    parent_tenant_id, name, status, stock_ready, costs_locked
  )
  VALUES (v_parent, 'lifecycle-draft', 'in_transit', true, false)
  RETURNING id INTO v_shipment;

  BEGIN
    PERFORM public.issue_shipment_ap_bills(v_shipment);
    RAISE EXCEPTION 'expected issue_shipment_ap_bills to fail without lock path';
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SQLERRM;
      IF v_err NOT LIKE '%locked%' AND v_err NOT LIKE '%lock_global_shipment_costs%' THEN
        RAISE EXCEPTION 'unexpected issue error: %', v_err;
      END IF;
  END;
END;
$$;

SELECT ok(true, 'issue_shipment_ap_bills blocked without costs_locked and session flag');

DO $$
DECLARE
  v_kernel jsonb;
  v_ctx jsonb;
  v_parent bigint;
  v_point bigint;
  v_shipment bigint;
  v_bill bigint;
  v_profile bigint;
  v_err text;
BEGIN
  v_kernel := public._test_money_kernel_bootstrap();
  v_parent := (v_kernel ->> 'tenant_id')::bigint;
  v_point := (v_kernel ->> 'cashbook_point_id')::bigint;

  v_ctx := public._test_bootstrap_shipment_ap_fx(v_parent);
  v_shipment := (v_ctx ->> 'shipment_id')::bigint;
  v_bill := (v_ctx ->> 'freight_bill_id')::bigint;
  v_profile := (v_ctx ->> 'cargo_profile_id')::bigint;

  UPDATE public.global_shipments SET status = 'draft', costs_locked = false WHERE id = v_shipment;

  PERFORM public._test_pgtap_auth();
  PERFORM public._test_fund_cashbook_pot(v_parent, v_point, 50000.00, 'BDT');

  BEGIN
    PERFORM public.post_shipment_ap_money_out(
      ARRAY[v_shipment],
      v_parent,
      v_profile,
      current_date,
      1000.00,
      'ap_payout',
      null,
      null,
      v_point,
      jsonb_build_array(
        jsonb_build_object('payment_method_code', 'cash', 'amount', 1000.00, 'cashbook_point_id', v_point)
      ),
      jsonb_build_array(jsonb_build_object('bill_id', v_bill, 'amount', 10.00)),
      'GBP',
      10.00,
      100.00,
      'shipment_cost',
      v_shipment::text,
      'lifecycle-pay-block-' || v_shipment::text
    );
    RAISE EXCEPTION 'expected post_shipment_ap_money_out to fail on draft shipment';
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SQLERRM;
      IF v_err NOT LIKE '%in transit%' AND v_err NOT LIKE '%locked%' THEN
        RAISE EXCEPTION 'unexpected pay error: %', v_err;
      END IF;
  END;
END;
$$;

SELECT ok(true, 'post_shipment_ap_money_out blocked on draft / unlocked shipment');

DO $$
DECLARE
  v_kernel jsonb;
  v_ctx jsonb;
  v_parent bigint;
  v_shipment bigint;
  v_bill bigint;
  v_before numeric;
  v_after numeric;
BEGIN
  v_kernel := public._test_money_kernel_bootstrap();
  v_parent := (v_kernel ->> 'tenant_id')::bigint;
  v_ctx := public._test_bootstrap_shipment_ap_fx(v_parent);
  v_shipment := (v_ctx ->> 'shipment_id')::bigint;
  v_bill := (v_ctx ->> 'freight_bill_id')::bigint;

  SELECT b.total_amount INTO v_before FROM public.bills b WHERE b.id = v_bill;

  UPDATE public.bills
  SET paid_amount = 999999.00, payment_status = 'paid'
  WHERE id = v_bill;

  PERFORM public.sync_shipment_ap_bills(v_shipment);

  SELECT b.total_amount INTO v_after FROM public.bills b WHERE b.id = v_bill;

  IF v_before IS DISTINCT FROM v_after THEN
    RAISE EXCEPTION 'issued AP total changed after sync: % -> %', v_before, v_after;
  END IF;
END;
$$;

SELECT ok(true, 'sync does not rewrite issued AP total_amount after pay header mutation');

DO $$
DECLARE
  v_kernel jsonb;
  v_ctx jsonb;
  v_parent bigint;
  v_shipment bigint;
  v_bill_id bigint;
  v_note text;
BEGIN
  v_kernel := public._test_money_kernel_bootstrap();
  v_parent := (v_kernel ->> 'tenant_id')::bigint;
  v_ctx := public._test_bootstrap_shipment_ap_fx(v_parent);
  v_shipment := (v_ctx ->> 'shipment_id')::bigint;

  UPDATE public.global_shipments
  SET costs_locked = false, status = 'in_transit'
  WHERE id = v_shipment;

  UPDATE public.bills
  SET invoice_status = 'draft'::public.global_invoice_status,
      paid_amount = 0,
      due_amount = total_amount,
      payment_status = 'due'
  WHERE source_type = 'shipment_cost'
    AND source_id = v_shipment::text
    AND document_kind = 'standard'::public.bill_document_kind;

  SELECT b.id INTO v_bill_id
  FROM public.bills b
  WHERE b.source_type = 'shipment_cost'
    AND b.source_id = v_shipment::text
    AND b.source_key = 'material'
  LIMIT 1;

  UPDATE public.global_shipment_cost_entries
  SET amount = 110.00
  WHERE shipment_id = v_shipment
    AND cost_bucket = 'material'
    AND cost_component = 'subtotal';

  PERFORM public.sync_shipment_ap_bills(v_shipment);

  SELECT b.note INTO v_note FROM public.bills b WHERE b.id = v_bill_id;

  IF v_note IS NULL OR v_note NOT LIKE '%Cost sync%' THEN
    RAISE EXCEPTION 'expected Cost sync note on draft AP, got: %', v_note;
  END IF;
END;
$$;

SELECT ok(true, 'draft AP sync appends note when foreign total changes');

SELECT * FROM finish();
ROLLBACK;

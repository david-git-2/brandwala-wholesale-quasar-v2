-- T4-4 — reverse_pay leaves bill issued; due restored
BEGIN;

SELECT plan(2);

DO $$
DECLARE
  v_ctx jsonb;
  v_tenant bigint;
  v_profile bigint;
  v_point bigint;
  v_bill_id bigint;
  v_pay public.pays;
  v_due numeric;
BEGIN
  v_ctx := public._test_money_kernel_bootstrap();
  v_tenant := (v_ctx ->> 'tenant_id')::bigint;
  v_profile := (v_ctx ->> 'customer_profile_id')::bigint;
  v_point := (v_ctx ->> 'cashbook_point_id')::bigint;

  v_bill_id := public._test_issue_ar_bill(v_tenant, v_profile, 800.00);
  PERFORM public._test_pgtap_auth();

  v_pay := public.post_money_in(
    v_tenant,
    v_profile,
    current_date,
    null,
    null,
    'customer_cash',
    jsonb_build_array(
      jsonb_build_object('payment_method_code', 'cash', 'amount', 800.00, 'cashbook_point_id', v_point)
    ),
    jsonb_build_array(jsonb_build_object('bill_id', v_bill_id, 'amount', 800.00)),
    null,
    'BDT',
    null,
    null,
    null,
    v_point
  );

  PERFORM public.reverse_pay(v_pay.id, 'pgTAP reverse');

  IF NOT EXISTS (
    SELECT 1 FROM public.bills b
    WHERE b.id = v_bill_id
      AND b.invoice_status = 'issued'::public.global_invoice_status
      AND b.payment_status IN ('due', 'partially_paid')
  ) THEN
    RAISE EXCEPTION 'T4-4: bill must stay issued with due/partial status';
  END IF;

  v_due := (public.get_bill_net_balances(v_bill_id) ->> 'due_amount')::numeric;
  IF v_due < 800.00 THEN
    RAISE EXCEPTION 'T4-4: expected due restored, got %', v_due;
  END IF;
END;
$$;

SELECT ok(true, 'T4-4 reverse_pay keeps bill issued');
SELECT ok(true, 'T4-4 due restored after reverse');

SELECT finish();
ROLLBACK;

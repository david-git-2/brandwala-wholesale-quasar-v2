-- Golden D — wholesale take: issue AR, collect, bill paid
BEGIN;

SELECT plan(3);

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

  v_bill_id := public._test_issue_ar_bill(v_tenant, v_profile, 1500.00);

  PERFORM public._test_pgtap_auth();

  v_pay := public.post_money_in(
    v_tenant,
    v_profile,
    current_date,
    'golden D',
    null,
    'customer_cash',
    jsonb_build_array(
      jsonb_build_object(
        'payment_method_code', 'cash',
        'amount', 1500.00,
        'cashbook_point_id', v_point
      )
    ),
    jsonb_build_array(jsonb_build_object('bill_id', v_bill_id, 'amount', 1500.00)),
    null,
    'BDT',
    null,
    null,
    null,
    v_point
  );

  v_due := (public.get_bill_net_balances(v_bill_id) ->> 'due_amount')::numeric;
  IF v_due <> 0 THEN
    RAISE EXCEPTION 'golden D: expected due 0, got %', v_due;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.bill_settlements bs
    WHERE bs.bill_id = v_bill_id
      AND bs.allocator_kind = 'pay'
      AND bs.allocator_id = v_pay.id
  ) THEN
    RAISE EXCEPTION 'golden D: missing bill_settlements';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.bills b
    WHERE b.id = v_bill_id
      AND b.invoice_status = 'issued'::public.global_invoice_status
      AND b.payment_status = 'paid'
  ) THEN
    RAISE EXCEPTION 'golden D: bill not issued/paid';
  END IF;
END;
$$;

SELECT ok(true, 'golden D end-to-end wholesale take');
SELECT ok(true, 'golden D settlements + payment status');
SELECT ok(true, 'golden D get_bill_net_balances due zero');

SELECT finish();
ROLLBACK;

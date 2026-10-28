-- Golden C — overpay custody then apply to second bill
BEGIN;

SELECT plan(2);

DO $$
DECLARE
  v_ctx jsonb;
  v_tenant bigint;
  v_profile bigint;
  v_point bigint;
  v_b1 bigint;
  v_b2 bigint;
  v_pay public.pays;
  v_due2 numeric;
BEGIN
  v_ctx := public._test_money_kernel_bootstrap();
  v_tenant := (v_ctx ->> 'tenant_id')::bigint;
  v_profile := (v_ctx ->> 'customer_profile_id')::bigint;
  v_point := (v_ctx ->> 'cashbook_point_id')::bigint;

  v_b1 := public._test_issue_ar_bill(v_tenant, v_profile, 1500.00);
  v_b2 := public._test_issue_ar_bill(v_tenant, v_profile, 800.00);

  PERFORM public._test_pgtap_auth();

  v_pay := public.post_money_in(
    v_tenant,
    v_profile,
    current_date,
    'golden C overpay',
    null,
    'customer_cash',
    jsonb_build_array(
      jsonb_build_object('payment_method_code', 'cash', 'amount', 2000.00, 'cashbook_point_id', v_point)
    ),
    jsonb_build_array(jsonb_build_object('bill_id', v_b1, 'amount', 1500.00)),
    null,
    'BDT',
    null,
    null,
    null,
    v_point
  );

  IF coalesce(v_pay.unallocated_amount, 0) < 500.00 THEN
    RAISE EXCEPTION 'golden C: expected ~500 leftover, got %', v_pay.unallocated_amount;
  END IF;

  PERFORM public.apply_settlement_to_bill(v_tenant, v_b2, 'pay', v_pay.id, 500.00);

  PERFORM public._test_pgtap_auth();

  v_pay := public.post_money_in(
    v_tenant,
    v_profile,
    current_date,
    'golden C cash slice',
    null,
    'customer_cash',
    jsonb_build_array(
      jsonb_build_object('payment_method_code', 'cash', 'amount', 300.00, 'cashbook_point_id', v_point)
    ),
    jsonb_build_array(jsonb_build_object('bill_id', v_b2, 'amount', 300.00)),
    null,
    'BDT',
    null,
    null,
    null,
    v_point
  );

  v_due2 := (public.get_bill_net_balances(v_b2) ->> 'due_amount')::numeric;
  IF v_due2 <> 0 THEN
    RAISE EXCEPTION 'golden C: B2 due expected 0, got %', v_due2;
  END IF;
END;
$$;

SELECT ok(true, 'golden C custody + cash settles B2');
SELECT ok(true, 'golden C get_bill_net_balances B2 due zero');

SELECT finish();
ROLLBACK;

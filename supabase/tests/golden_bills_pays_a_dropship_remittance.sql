-- Golden A — dropship courier remittance + merchant commission payout
BEGIN;

SELECT plan(3);

DO $$
DECLARE
  v_ctx jsonb;
  v_tenant bigint;
  v_merchant bigint;
  v_point bigint;
  v_order bigint;
  v_merchant_bill bigint;
  v_courier_ap bigint;
  v_pay public.pays;
  v_merchant_due numeric;
  v_custody numeric;
BEGIN
  v_ctx := public._test_money_kernel_bootstrap();
  v_ctx := public._test_bootstrap_dropship_golden_a(v_ctx);
  v_tenant := (v_ctx ->> 'tenant_id')::bigint;
  v_merchant := (v_ctx ->> 'dropship_merchant_profile_id')::bigint;
  v_point := (v_ctx ->> 'cashbook_point_id')::bigint;
  v_order := (v_ctx ->> 'dropship_order_id')::bigint;

  SELECT o.global_invoice_id INTO v_merchant_bill
  FROM public.shop_orders o
  WHERE o.id = v_order;

  SELECT public.resolve_dropship_courier_ap_bill_id(v_order, v_tenant) INTO v_courier_ap;

  IF NOT EXISTS (
    SELECT 1 FROM public.bills b
    WHERE b.id = v_merchant_bill
      AND b.total_amount = 1500.00
      AND b.invoice_status = 'issued'::public.global_invoice_status
  ) THEN
    RAISE EXCEPTION 'golden A: merchant AR must be issued 1500';
  END IF;

  IF v_courier_ap IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.bills b
    WHERE b.id = v_courier_ap
      AND b.invoice_type = 'ap'::public.global_invoice_type
      AND b.total_amount > 0
  ) THEN
    RAISE EXCEPTION 'golden A: courier AP bill missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.cashbook_entries ce
    JOIN public.cashbook_accounts ca
      ON ca.parent_tenant_id = ce.parent_tenant_id
     AND ca.entity_type = ce.entity_type
     AND ca.entity_id = ce.entity_id
     AND ca.currency_code = ce.currency_code
    WHERE ce.source_type = 'shop_order'
      AND ce.source_id = v_order::text
      AND ca.account_class = 'profile_custody'::public.cashbook_account_class
      AND ce.type = 'credit'
      AND ce.amount >= 2199.00
  ) THEN
    RAISE EXCEPTION 'golden A: expected courier custody credit ~2200 COD';
  END IF;

  PERFORM public._test_pgtap_auth();
  PERFORM public._test_fund_cashbook_pot(v_tenant, v_point, 5000.00, 'BDT');

  PERFORM public.process_dropship_courier_remittance_uwl(
    p_order_id => v_order,
    p_net_amount => 2120.00,
    p_courier_charge => 80.00,
    p_remittance_ref => 'REMIT-GOLDEN-A'
  );

  v_pay := public.post_money_in(
    v_tenant,
    v_merchant,
    current_date,
    'golden A remittance',
    'REMIT-GOLDEN-A',
    'courier_remittance',
    jsonb_build_array(
      jsonb_build_object(
        'payment_method_code', 'cash',
        'amount', 2120.00,
        'cashbook_point_id', v_point
      )
    ),
    jsonb_build_array(jsonb_build_object('bill_id', v_merchant_bill, 'amount', 1500.00)),
    v_order,
    'BDT',
    null,
    null,
    null,
    v_point
  );

  IF v_pay.amount <> 2120.00 THEN
    RAISE EXCEPTION 'golden A: remittance pay amount expected 2120, got %', v_pay.amount;
  END IF;

  v_merchant_due := (public.get_bill_net_balances(v_merchant_bill) ->> 'due_amount')::numeric;
  IF v_merchant_due <> 0 THEN
    RAISE EXCEPTION 'golden A: merchant bill due expected 0 after remittance, got %', v_merchant_due;
  END IF;

  SELECT coalesce(ca.available_balance, 0) INTO v_custody
  FROM public.cashbook_accounts ca
  WHERE ca.parent_tenant_id = v_tenant
    AND ca.entity_type = 'customer'
    AND ca.entity_id = v_merchant
    AND ca.currency_code = 'BDT'
    AND ca.account_class = 'profile_custody'::public.cashbook_account_class;

  IF v_custody < 619.00 OR v_custody > 621.00 THEN
    RAISE EXCEPTION 'golden A: expected merchant custody ~620, got %', v_custody;
  END IF;
END;
$$;

SELECT ok(true, 'golden A ship + deliver bills');
SELECT ok(true, 'golden A remittance 2120 allocates 1500');
SELECT ok(true, 'golden A merchant custody ~620 after remittance');

SELECT finish();
ROLLBACK;

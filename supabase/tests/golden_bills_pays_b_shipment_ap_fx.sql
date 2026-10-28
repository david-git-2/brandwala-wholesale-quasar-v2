-- Golden B — multi-currency shipment AP + freight pay + landed FX refresh
BEGIN;

SELECT plan(3);

DO $$
DECLARE
  v_ctx jsonb;
  v_kernel jsonb;
  v_tenant bigint;
  v_point bigint;
  v_shipment bigint;
  v_freight_bill bigint;
  v_cargo_profile bigint;
  v_fx jsonb;
  v_pay public.pays;
  v_rate numeric;
BEGIN
  v_kernel := public._test_money_kernel_bootstrap();
  v_tenant := (v_kernel ->> 'tenant_id')::bigint;
  v_point := (v_kernel ->> 'cashbook_point_id')::bigint;

  v_ctx := public._test_bootstrap_shipment_ap_fx(v_tenant);
  v_shipment := (v_ctx ->> 'shipment_id')::bigint;
  v_freight_bill := (v_ctx ->> 'freight_bill_id')::bigint;
  v_cargo_profile := (v_ctx ->> 'cargo_profile_id')::bigint;

  IF NOT EXISTS (
    SELECT 1 FROM public.bills b
    WHERE b.id = (v_ctx ->> 'material_bill_id')::bigint
      AND upper(b.currency_code) = 'USD'
  ) THEN
    RAISE EXCEPTION 'golden B: material bill must be USD';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.bills b
    WHERE b.id = v_freight_bill
      AND upper(b.currency_code) = 'GBP'
  ) THEN
    RAISE EXCEPTION 'golden B: freight bill must be GBP';
  END IF;

  PERFORM public._test_pgtap_auth();
  PERFORM public._test_fund_cashbook_pot(v_tenant, v_point, 100000.00, 'BDT');

  v_pay := public.post_ap_payout_with_allocations(
    v_tenant,
    v_cargo_profile,
    current_date,
    v_point,
    'golden B freight pay',
    'FREIGHT-B',
    jsonb_build_array(
      jsonb_build_object(
        'payment_method_code', 'cash',
        'amount', 7775.00,
        'cashbook_point_id', v_point
      )
    ),
    jsonb_build_array(jsonb_build_object('bill_id', v_freight_bill, 'amount', 50.00)),
    'GBP',
    50.00,
    155.50,
    'BDT',
    155.50,
    null,
    null
  );

  SELECT py.exchange_rate INTO v_rate
  FROM public.pays py
  WHERE py.id = v_pay.id;

  IF v_rate IS NULL OR abs(v_rate - 155.50) > 0.001 THEN
    RAISE EXCEPTION 'golden B: expected frozen books rate 155.50 on GBP leg, got %', v_rate;
  END IF;

  v_fx := public.refresh_global_shipment_fx_from_ap_payments(v_shipment);
  IF v_fx IS NULL THEN
    RAISE EXCEPTION 'golden B: refresh_global_shipment_fx_from_ap_payments returned null';
  END IF;

  IF (public.get_bill_net_balances(v_freight_bill) ->> 'due_amount')::numeric <> 0 THEN
    RAISE EXCEPTION 'golden B: freight bill should be paid';
  END IF;
END;
$$;

SELECT ok(true, 'golden B sync material USD + freight GBP');
SELECT ok(true, 'golden B freight pay freezes rate 155.50');
SELECT ok(true, 'golden B refresh_global_shipment_fx_from_ap_payments');

SELECT finish();
ROLLBACK;

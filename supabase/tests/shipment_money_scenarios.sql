-- Shipment money edge scenarios (reuses S54 bootstrap shape)
BEGIN;

SELECT plan(6);

DO $$
DECLARE
  v_kernel jsonb;
  v_ctx jsonb;
  v_tenant bigint;
  v_shipment bigint;
  v_material_bill bigint;
  v_payer bigint;
  v_mat_pot bigint;
  v_dep jsonb;
  v_mat jsonb;
  v_err text;
BEGIN
  v_kernel := public._test_money_kernel_bootstrap();
  v_ctx := public._test_bootstrap_shipment_s54((v_kernel ->> 'tenant_id')::bigint);
  v_ctx := v_ctx || jsonb_build_object('tenant_profile_id', v_kernel ->> 'tenant_profile_id');
  v_tenant := (v_ctx ->> 'tenant_id')::bigint;
  v_shipment := (v_ctx ->> 'shipment_id')::bigint;
  v_material_bill := (v_ctx ->> 'material_bill_id')::bigint;
  v_payer := (v_ctx ->> 'tenant_profile_id')::bigint;

  PERFORM public._test_pgtap_auth();
  PERFORM public._test_set_workspace_tenant(v_tenant);
  PERFORM public._test_enable_tenant_module(v_tenant, 'payments');

  v_dep := public.rpc_deposit(
    v_tenant, v_payer, 5000, 'GBP', NULL, '{}'::jsonb,
    'pgtap-s54-partial-' || v_shipment::text, 168::numeric, 'main'
  );
  v_mat_pot := NULLIF(v_dep ->> 'cash_bundle_id', '')::bigint;
  PERFORM public._test_flush_kernel_pays();

  PERFORM public.rpc_pay_bills(
    v_tenant,
    v_payer,
    v_mat_pot,
    2347.5,
    jsonb_build_array(jsonb_build_object('bill_id', v_material_bill, 'amount', 2347.5)),
    NULL, NULL, '{}'::jsonb,
    'pgtap-s54-partial-pay-' || v_shipment::text
  );
  PERFORM public._test_flush_kernel_pays();

  v_mat := public.shipment_ap_bucket_paid_totals(v_shipment, 'material');
  IF round((v_mat ->> 'foreign_paid')::numeric, 2) <> 2347.5::numeric THEN
    RAISE EXCEPTION 'partial foreign_paid expected 2347.5 got %', v_mat ->> 'foreign_paid';
  END IF;
END;
$$;

SELECT ok(true, 'partial material pay updates bucket foreign_paid');

DO $$
DECLARE
  v_kernel jsonb;
  v_ctx jsonb;
  v_tenant bigint;
  v_payer bigint;
  v_mat_pot bigint;
  v_dep jsonb;
BEGIN
  v_kernel := public._test_money_kernel_bootstrap();
  v_ctx := public._test_bootstrap_shipment_s54((v_kernel ->> 'tenant_id')::bigint);
  v_ctx := v_ctx || jsonb_build_object('tenant_profile_id', v_kernel ->> 'tenant_profile_id');
  v_tenant := (v_ctx ->> 'tenant_id')::bigint;
  v_payer := (v_ctx ->> 'tenant_profile_id')::bigint;

  PERFORM public._test_pgtap_auth();
  PERFORM public._test_set_workspace_tenant(v_tenant);
  PERFORM public._test_enable_tenant_module(v_tenant, 'payments');
  v_dep := public.rpc_deposit(
    v_tenant, v_payer, 100, 'BDT', NULL, '{}'::jsonb,
    'pgtap-s54-wrong-ccy-' || (v_ctx ->> 'shipment_id'), 1::numeric, 'main'
  );
  v_mat_pot := NULLIF(v_dep ->> 'cash_bundle_id', '')::bigint;
  PERFORM public._test_flush_kernel_pays();

  BEGIN
    PERFORM public.rpc_pay_bills(
      v_tenant,
      v_payer,
      v_mat_pot,
      50,
      jsonb_build_array(jsonb_build_object(
        'bill_id', (v_ctx ->> 'material_bill_id')::bigint,
        'amount', 50
      )),
      NULL, NULL, '{}'::jsonb,
      'pgtap-s54-wrong-pay-' || (v_ctx ->> 'shipment_id')
    );
    RAISE EXCEPTION 'expected pay with wrong currency pot to fail';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT ILIKE '%currency%'
         AND SQLERRM NOT ILIKE '%invalid_arguments%'
         AND SQLERRM NOT ILIKE '%insufficient%' THEN
        RAISE;
      END IF;
  END;
END;
$$;

SELECT ok(true, 'GBP bill pay from BDT bundle raises');

DO $$
DECLARE
  v_kernel jsonb;
  v_ctx jsonb;
  v_pay jsonb;
BEGIN
  v_kernel := public._test_money_kernel_bootstrap();
  v_ctx := public._test_bootstrap_shipment_s54((v_kernel ->> 'tenant_id')::bigint);
  v_ctx := v_ctx || jsonb_build_object('tenant_profile_id', v_kernel ->> 'tenant_profile_id');
  v_ctx := public._test_shipment_s54_fund_and_pay(v_ctx);
  v_pay := public.rpc_pay_bills(
    (v_ctx ->> 'tenant_id')::bigint,
    (v_ctx ->> 'tenant_profile_id')::bigint,
    (v_ctx ->> 'material_pot_id')::bigint,
    4695,
    jsonb_build_array(jsonb_build_object(
      'bill_id', (v_ctx ->> 'material_bill_id')::bigint,
      'amount', 4695
    )),
    NULL, NULL, '{}'::jsonb,
    'pgtap-s54-pay-mat-' || (v_ctx ->> 'shipment_id')
  );
  IF coalesce(v_pay ->> 'idempotent', 'false') <> 'true' THEN
    RAISE EXCEPTION 'expected idempotent replay got %', v_pay;
  END IF;
END;
$$;

SELECT ok(true, 'idempotent pay replay returns idempotent true');

DO $$
DECLARE
  v_kernel jsonb;
  v_ctx jsonb;
  v_tenant bigint;
  v_shipment bigint;
  v_payer bigint;
  v_mat_pot bigint;
  v_dep jsonb;
  v_line_before numeric;
  v_line_after numeric;
BEGIN
  v_kernel := public._test_money_kernel_bootstrap();
  v_ctx := public._test_bootstrap_shipment_s54((v_kernel ->> 'tenant_id')::bigint);
  v_ctx := v_ctx || jsonb_build_object('tenant_profile_id', v_kernel ->> 'tenant_profile_id');
  v_tenant := (v_ctx ->> 'tenant_id')::bigint;
  v_shipment := (v_ctx ->> 'shipment_id')::bigint;
  v_payer := (v_ctx ->> 'tenant_profile_id')::bigint;

  PERFORM public._test_pgtap_auth();
  PERFORM public._test_set_workspace_tenant(v_tenant);
  PERFORM public._test_enable_tenant_module(v_tenant, 'payments');

  UPDATE public.global_shipment_items
  SET landed_cost_bdt = 100
  WHERE shipment_id = v_shipment;

  v_dep := public.rpc_deposit(
    v_tenant, v_payer, 5000, 'GBP', NULL, '{}'::jsonb,
    'pgtap-s54-stale-' || v_shipment::text, 168::numeric, 'main'
  );
  v_mat_pot := NULLIF(v_dep ->> 'cash_bundle_id', '')::bigint;
  PERFORM public._test_flush_kernel_pays();

  SELECT coalesce(sum(gsi.landed_cost_bdt * gsi.ordered_quantity), 0)
    INTO v_line_before
    FROM public.global_shipment_items gsi
   WHERE gsi.shipment_id = v_shipment;

  PERFORM public.rpc_pay_bills(
    v_tenant,
    v_payer,
    v_mat_pot,
    4695,
    jsonb_build_array(jsonb_build_object(
      'bill_id', (v_ctx ->> 'material_bill_id')::bigint,
      'amount', 4695
    )),
    NULL, NULL, '{}'::jsonb,
    'pgtap-s54-stale-pay-' || v_shipment::text
  );
  PERFORM public._test_flush_kernel_pays();
  PERFORM public.refresh_global_shipment_fx_from_ap_payments(v_shipment);

  SELECT coalesce(sum(gsi.landed_cost_bdt * gsi.ordered_quantity), 0)
    INTO v_line_after
    FROM public.global_shipment_items gsi
   WHERE gsi.shipment_id = v_shipment;

  IF v_line_after <> v_line_before THEN
    RAISE EXCEPTION 'stale stamp: landed sum changed without stamp (% -> %)', v_line_before, v_line_after;
  END IF;
END;
$$;

SELECT ok(true, 'pay without stamp leaves stored landed sum unchanged (known gap)');

DO $$
DECLARE
  v_kernel jsonb;
  v_ctx jsonb;
  v_tenant bigint;
  v_payer bigint;
  v_mat_pot bigint;
  v_err text;
BEGIN
  v_kernel := public._test_money_kernel_bootstrap();
  v_ctx := public._test_bootstrap_shipment_s54((v_kernel ->> 'tenant_id')::bigint);
  v_ctx := v_ctx || jsonb_build_object('tenant_profile_id', v_kernel ->> 'tenant_profile_id');
  v_tenant := (v_ctx ->> 'tenant_id')::bigint;
  v_payer := (v_ctx ->> 'tenant_profile_id')::bigint;

  PERFORM public._test_pgtap_auth();
  PERFORM public._test_set_workspace_tenant(v_tenant);
  PERFORM public._test_enable_tenant_module(v_tenant, 'payments');

  v_mat_pot := (public.rpc_deposit(
    v_tenant, v_payer, 100, 'GBP', NULL, '{}'::jsonb,
    'pgtap-s54-over-' || (v_ctx ->> 'shipment_id'), 168::numeric, 'main'
  ) ->> 'cash_bundle_id')::bigint;
  PERFORM public._test_flush_kernel_pays();

  BEGIN
    PERFORM public.rpc_pay_bills(
      v_tenant,
      v_payer,
      v_mat_pot,
      4695,
      jsonb_build_array(jsonb_build_object(
        'bill_id', (v_ctx ->> 'material_bill_id')::bigint,
        'amount', 4695
      )),
      NULL, NULL, '{}'::jsonb,
      'pgtap-s54-overpay-' || (v_ctx ->> 'shipment_id')
    );
    RAISE EXCEPTION 'expected overpay to fail';
  EXCEPTION
    WHEN OTHERS THEN
      v_err := SQLERRM;
      IF v_err NOT ILIKE '%insufficient%' AND v_err NOT ILIKE '%balance%' THEN
        RAISE;
      END IF;
  END;
END;
$$;

SELECT ok(true, 'overpay raises insufficient balance');

DO $$
DECLARE
  v_kernel jsonb;
  v_ctx jsonb;
  v_tenant bigint;
  v_shipment bigint;
  v_mat jsonb;
BEGIN
  v_kernel := public._test_money_kernel_bootstrap();
  v_ctx := public._test_bootstrap_shipment_s54((v_kernel ->> 'tenant_id')::bigint);
  v_tenant := (v_ctx ->> 'tenant_id')::bigint;
  v_shipment := (v_ctx ->> 'shipment_id')::bigint;

  PERFORM public._test_set_workspace_tenant(v_tenant);

  PERFORM public.create_shipment_ap_bill_v2(
    v_shipment,
    'customs',
    jsonb_build_object(
      'currency_code', 'BDT',
      'source_key_suffix', 'allbdt',
      'lines', jsonb_build_array(jsonb_build_object('amount', 500, 'cost_component', 'subtotal'))
    )
  );

  v_mat := public.shipment_ap_bucket_paid_totals(v_shipment, 'customs');
  IF coalesce((v_mat ->> 'conversion_rate')::numeric, 0) <> 1 THEN
    RAISE EXCEPTION 'BDT bucket conversion_rate expected 1 got %', v_mat ->> 'conversion_rate';
  END IF;
END;
$$;

SELECT ok(true, 'BDT AP bucket unpaid preview conversion_rate is 1');

SELECT * FROM finish();
ROLLBACK;
-- Golden shipment report (bootstrap S54) — cost buckets, ap bdt_amount, warehouse value on landed+paid batch
BEGIN;

SELECT plan(5);

DO $$
DECLARE
  v_kernel jsonb;
  v_ctx jsonb;
  v_tenant bigint;
  v_shipment bigint;
  v_detail jsonb;
  v_wh numeric;
  v_mat_bdt numeric;
  v_fre_bdt numeric;
  v_total_cost numeric;
BEGIN
  v_kernel := public._test_money_kernel_bootstrap();
  v_ctx := public._test_bootstrap_shipment_s54((v_kernel ->> 'tenant_id')::bigint);
  v_ctx := v_ctx || jsonb_build_object('tenant_profile_id', v_kernel ->> 'tenant_profile_id');
  v_ctx := public._test_shipment_s54_fund_and_pay(v_ctx);

  v_tenant := (v_ctx ->> 'tenant_id')::bigint;
  v_shipment := (v_ctx ->> 'shipment_id')::bigint;

  PERFORM public._test_enable_tenant_module(v_tenant, 'reporting_treasury');
  PERFORM public._test_pgtap_auth();

  v_detail := public.get_tenant_shipment_report_detail(v_tenant, v_shipment);

  v_wh := (v_detail -> 'qty_summary' ->> 'warehouse_value_bdt')::numeric;
  IF coalesce(v_wh, -1) <> 0 THEN
    RAISE EXCEPTION 'warehouse_value_bdt expected 0 got %', v_wh;
  END IF;

  SELECT (elem ->> 'bdt_amount')::numeric INTO v_mat_bdt
  FROM jsonb_array_elements(v_detail -> 'ap_bills') elem
  WHERE elem ->> 'ap_kind' = 'material'
  LIMIT 1;

  SELECT (elem ->> 'bdt_amount')::numeric INTO v_fre_bdt
  FROM jsonb_array_elements(v_detail -> 'ap_bills') elem
  WHERE elem ->> 'ap_kind' = 'freight'
  LIMIT 1;

  IF round(coalesce(v_mat_bdt, 0), 2) <> 788760::numeric THEN
    RAISE EXCEPTION 'ap material bdt_amount expected 788760 got %', v_mat_bdt;
  END IF;
  IF round(coalesce(v_fre_bdt, 0), 2) <> 340429.48::numeric THEN
    RAISE EXCEPTION 'ap freight bdt_amount expected 340429.48 got %', v_fre_bdt;
  END IF;

  v_total_cost := (v_detail -> 'profit_matrix' ->> 'total_cost_bdt')::numeric;
  IF abs(coalesce(v_total_cost, 0) - 1129189.48) > 0.5 THEN
    RAISE EXCEPTION 'profit_matrix.total_cost_bdt expected ~1129189.48 got %', v_total_cost;
  END IF;

  IF (v_detail -> 'qty_summary' ->> 'should_arrive')::int <> 1500 THEN
    RAISE EXCEPTION 'should_arrive expected 1500';
  END IF;
END;
$$;

SELECT pass('report detail warehouse value zero after stamp');
SELECT pass('report ap bdt_amount material/freight golden');
SELECT pass('report profit_matrix total_cost golden');
SELECT pass('report qty should_arrive 1500');
SELECT pass('report golden s54 pgtap block');

SELECT * FROM finish();
ROLLBACK;
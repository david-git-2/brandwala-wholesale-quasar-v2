-- Golden shipment report (bootstrap S45) — twin material AP, freight, vendor CN + refund, receive loss
BEGIN;

SELECT plan(6);

DO $$
DECLARE
  v_kernel jsonb;
  v_ctx jsonb;
  v_tenant bigint;
  v_shipment bigint;
  v_detail jsonb;
  v_total_cost numeric;
  v_vendor_credit numeric;
  v_net_cost numeric;
  v_ap_books numeric;
  v_recv_loss numeric;
  v_loss_qty int;
  v_cn_count int;
BEGIN
  v_kernel := public._test_money_kernel_bootstrap();
  v_ctx := public._test_bootstrap_shipment_s45((v_kernel ->> 'tenant_id')::bigint);
  v_ctx := v_ctx
    || jsonb_build_object(
      'tenant_profile_id', v_kernel ->> 'tenant_profile_id',
      'cashbook_point_id', v_kernel ->> 'cashbook_point_id'
    );
  v_ctx := public._test_shipment_s45_fund_pay_and_credit(v_ctx);

  v_tenant := (v_ctx ->> 'tenant_id')::bigint;
  v_shipment := (v_ctx ->> 'shipment_id')::bigint;

  PERFORM public._test_enable_tenant_module(v_tenant, 'reporting_treasury');
  PERFORM public._test_pgtap_auth();

  v_detail := public.get_tenant_shipment_report_detail(v_tenant, v_shipment);

  v_total_cost := (v_detail -> 'profit_matrix' ->> 'total_cost_bdt')::numeric;
  IF abs(coalesce(v_total_cost, 0) - 424647.40) > 1 THEN
    RAISE EXCEPTION 'profit_matrix.total_cost_bdt expected ~424647.40 got %', v_total_cost;
  END IF;

  v_ap_books := (v_detail ->> 'ap_books_total_bdt')::numeric;
  IF abs(coalesce(v_ap_books, 0) - 424647.40) > 1 THEN
    RAISE EXCEPTION 'ap_books_total_bdt expected ~424647.40 got %', v_ap_books;
  END IF;

  v_vendor_credit := (v_detail -> 'profit_matrix' ->> 'vendor_credit_bdt')::numeric;
  IF abs(coalesce(v_vendor_credit, 0) - 4173.12) > 1 THEN
    RAISE EXCEPTION 'profit_matrix.vendor_credit_bdt expected ~4173.12 got %', v_vendor_credit;
  END IF;

  v_cn_count := (v_detail -> 'profit_matrix' ->> 'vendor_credit_count')::int;
  IF coalesce(v_cn_count, 0) < 1 THEN
    RAISE EXCEPTION 'vendor_credit_count expected >= 1 got %', v_cn_count;
  END IF;

  v_net_cost := (v_detail -> 'profit_matrix' ->> 'net_cost_bdt')::numeric;
  IF abs(coalesce(v_net_cost, 0) - (424647.40 - 4173.12)) > 1.5 THEN
    RAISE EXCEPTION 'profit_matrix.net_cost_bdt expected ~420474.28 got %', v_net_cost;
  END IF;

  v_recv_loss := (v_detail -> 'profit_matrix' ->> 'receive_loss_bdt')::numeric;
  IF coalesce(v_recv_loss, 0) <= 0 THEN
    RAISE EXCEPTION 'receive_loss_bdt expected > 0 got %', v_recv_loss;
  END IF;

  v_loss_qty := (v_detail -> 'qty_summary' ->> 'loss_at_shipment')::int;
  IF coalesce(v_loss_qty, 0) <> 12 THEN
    RAISE EXCEPTION 'loss_at_shipment expected 12 got %', v_loss_qty;
  END IF;
END;
$$;

SELECT pass('report s45 total_cost ap books golden');
SELECT pass('report s45 vendor credit bdt golden');
SELECT pass('report s45 net_cost after vendor credit');
SELECT pass('report s45 vendor_credit_count');
SELECT pass('report s45 receive loss and loss qty');
SELECT pass('report golden s45 pgtap block');

SELECT * FROM finish();
ROLLBACK;
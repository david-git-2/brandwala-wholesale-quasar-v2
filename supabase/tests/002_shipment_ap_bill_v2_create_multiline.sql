-- create_shipment_ap_bill_v2 contract: one rpc_create_bill, many bill_lines (regression guard)
BEGIN;

SELECT plan(4);

SELECT ok(
  (
    SELECT strpos(
      pg_get_functiondef('public.create_shipment_ap_bill_v2'::regproc),
      'v_lines := v_lines ||'
    ) > 0
  ),
  'adapter accumulates payload lines into v_lines before create'
);

SELECT ok(
  (
    SELECT (
      length(pg_get_functiondef('public.create_shipment_ap_bill_v2'::regproc))
      - length(replace(pg_get_functiondef('public.create_shipment_ap_bill_v2'::regproc), 'v_result := public.rpc_create_bill', ''))
    ) / length('v_result := public.rpc_create_bill') = 1
  ),
  'single rpc_create_bill call per Create (not one bill per component)'
);

SELECT ok(
  (
    SELECT strpos(
      pg_get_functiondef('public.create_shipment_ap_bill_v2'::regproc),
      '''quantity'', 1'
    ) > 0
  ),
  'each charge line uses quantity 1'
);

SELECT ok(
  (
    SELECT strpos(
      pg_get_functiondef('public.create_shipment_ap_bill_v2'::regproc),
      '''cost_lines'''
    ) > 0
  ),
  'create response includes cost_lines from money_kernel.bill_lines'
);

SELECT finish();
ROLLBACK;

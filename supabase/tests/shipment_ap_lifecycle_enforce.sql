-- Shipment AP: issue blocked until costs lock path (legacy sync_shipment_ap_bills guard)
BEGIN;

SELECT plan(1);

DO $$
DECLARE
  v_kernel jsonb;
  v_tenant bigint;
  v_shipment bigint;
  v_err text;
BEGIN
  v_kernel := public._test_money_kernel_bootstrap();
  v_tenant := (v_kernel ->> 'tenant_id')::bigint;

  INSERT INTO public.global_shipments (
    tenant_id, name, status, stock_ready, costs_locked
  )
  VALUES (v_tenant, 'lifecycle-draft', 'in_transit', true, false)
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

SELECT * FROM finish();
ROLLBACK;
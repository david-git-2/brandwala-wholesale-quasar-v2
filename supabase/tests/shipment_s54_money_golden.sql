-- Golden shipment S54 — kernel AP bills, pays, bucket totals, landed stamp
BEGIN;

SELECT plan(8);

DO $$
DECLARE
  v_kernel jsonb;
  v_ctx jsonb;
  v_shipment bigint;
  v_material_bill bigint;
  v_freight_bill bigint;
  v_mat jsonb;
  v_fre jsonb;
  v_fx jsonb;
  v_unit_a numeric;
  v_unit_b numeric;
  v_line_sum numeric;
  v_due numeric;
BEGIN
  v_kernel := public._test_money_kernel_bootstrap();
  v_ctx := public._test_bootstrap_shipment_s54((v_kernel ->> 'tenant_id')::bigint);
  v_ctx := v_ctx || jsonb_build_object('tenant_profile_id', v_kernel ->> 'tenant_profile_id');
  v_ctx := public._test_shipment_s54_fund_and_pay(v_ctx);

  v_shipment := (v_ctx ->> 'shipment_id')::bigint;
  v_material_bill := (v_ctx ->> 'material_bill_id')::bigint;
  v_freight_bill := (v_ctx ->> 'freight_bill_id')::bigint;

  v_mat := public.shipment_ap_bucket_paid_totals(v_shipment, 'material');
  v_fre := public.shipment_ap_bucket_paid_totals(v_shipment, 'freight');

  IF round((v_mat ->> 'bdt_paid')::numeric, 2) <> 788760::numeric THEN
    RAISE EXCEPTION 'material bdt_paid expected 788760 got %', v_mat ->> 'bdt_paid';
  END IF;
  IF round((v_mat ->> 'foreign_paid')::numeric, 2) <> 4695::numeric THEN
    RAISE EXCEPTION 'material foreign_paid expected 4695 got %', v_mat ->> 'foreign_paid';
  END IF;
  IF round((v_fre ->> 'bdt_paid')::numeric, 2) <> 340429.48::numeric THEN
    RAISE EXCEPTION 'freight bdt_paid expected 340429.48 got %', v_fre ->> 'bdt_paid';
  END IF;

  v_fx := public._global_shipment_landed_fx_inputs(v_shipment);
  IF abs((v_fx ->> 'freight_bdt_per_kg')::numeric - 1119.835289) > 0.01 THEN
    RAISE EXCEPTION 'freight_bdt_per_kg drift: %', v_fx ->> 'freight_bdt_per_kg';
  END IF;
  IF abs((v_fx ->> 'kg_basis')::numeric - 303.9996) > 0.01 THEN
    RAISE EXCEPTION 'kg_basis drift: %', v_fx ->> 'kg_basis';
  END IF;
  IF round((v_fx ->> 'goods_bdt')::numeric, 2) <> 788760::numeric THEN
    RAISE EXCEPTION 'goods_bdt expected 788760 got %', v_fx ->> 'goods_bdt';
  END IF;

  SELECT gsi.landed_cost_bdt INTO v_unit_a
    FROM public.global_shipment_items gsi
    WHERE gsi.shipment_id = v_shipment AND gsi.name = 'Astral Cream 50ML'
    LIMIT 1;

  SELECT gsi.landed_cost_bdt INTO v_unit_b
    FROM public.global_shipment_items gsi
    WHERE gsi.shipment_id = v_shipment AND gsi.name = 'Astral Cream 200ML'
    LIMIT 1;

  IF abs(v_unit_a - 293.9652) > 0.0001 OR abs(v_unit_b - 867.4999) > 0.0001 THEN
    RAISE EXCEPTION 'landed per unit: % / %', v_unit_a, v_unit_b;
  END IF;

  SELECT coalesce(sum(gsi.landed_cost_bdt * gsi.ordered_quantity), 0)
    INTO v_line_sum
    FROM public.global_shipment_items gsi
   WHERE gsi.shipment_id = v_shipment;

  IF abs(v_line_sum - 1129189.48) > 0.05 THEN
    RAISE EXCEPTION 'line landed sum expected ~1129189.48 got %', v_line_sum;
  END IF;

  SELECT coalesce(sum(b.due_amount), 0) INTO v_due
    FROM money_kernel.bills b
   WHERE b.id IN (v_material_bill, v_freight_bill);

  IF v_due <> 0 THEN
    RAISE EXCEPTION 'expected AP bills paid (due 0) got due %', v_due;
  END IF;
END;
$$;

SELECT ok(true, 'material bucket paid 788760 BDT for 4695 GBP');
SELECT ok(true, 'freight bucket paid 340429.48 for 2050.78 GBP');
SELECT ok(true, 'landed fx inputs kg_basis and freight_bdt_per_kg');
SELECT ok(true, 'goods_bdt pool 788760');
SELECT ok(true, 'stamped unit landed 293.9652 and 867.4999');
SELECT ok(true, 'line landed sum within 0.05 of AP books');
SELECT ok(true, 'material and freight bills due 0');
SELECT ok(true, 'golden S54 end-to-end');

SELECT * FROM finish();
ROLLBACK;
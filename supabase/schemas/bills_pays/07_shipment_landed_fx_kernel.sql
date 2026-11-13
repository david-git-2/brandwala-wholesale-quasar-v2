-- Landed FX: capitalizable totals from kernel shipment AP bill lines (Option A).

CREATE OR REPLACE FUNCTION public._global_shipment_landed_fx_inputs(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_mat jsonb;
  v_fre jsonb;
  v_prod_rate numeric := 1;
  v_cargo_fx numeric := 1;
  v_product_foreign numeric := 0;
  v_cargo_foreign numeric := 0;
  v_goods_bdt numeric := 0;
  v_freight_bdt numeric := 0;
  v_blended numeric := 1;
  v_kg numeric := 0;
  v_cargo_per_kg numeric := 0;
  v_mat_count integer := 0;
  v_fre_count integer := 0;
  v_entry_material numeric := 0;
  v_entry_freight numeric := 0;
BEGIN
  v_mat := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'material');
  v_fre := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'freight');

  v_mat_count := coalesce((v_mat ->> 'payment_count')::integer, 0);
  v_fre_count := coalesce((v_fre ->> 'payment_count')::integer, 0);

  IF v_mat_count > 0 THEN
    v_prod_rate := coalesce((v_mat ->> 'conversion_rate')::numeric, 1);
  END IF;
  IF v_fre_count > 0 THEN
    v_cargo_fx := coalesce((v_fre ->> 'conversion_rate')::numeric, 1);
  END IF;

  v_entry_material := public._shipment_kernel_capitalizable_bucket_total(p_shipment_id, 'material');
  v_entry_freight := public._shipment_kernel_capitalizable_bucket_total(p_shipment_id, 'freight');

  IF v_entry_material <= 0 AND to_regclass('public.global_shipment_cost_entries') IS NOT NULL THEN
    SELECT coalesce(sum(gce.amount) filter (where gce.is_capitalizable and gce.cost_bucket = 'material'), 0)
      INTO v_entry_material
      FROM public.global_shipment_cost_entries gce
     WHERE gce.shipment_id = p_shipment_id;
  END IF;

  IF v_entry_freight <= 0 AND to_regclass('public.global_shipment_cost_entries') IS NOT NULL THEN
    SELECT coalesce(sum(gce.amount) filter (where gce.is_capitalizable and gce.cost_bucket = 'freight'), 0)
      INTO v_entry_freight
      FROM public.global_shipment_cost_entries gce
     WHERE gce.shipment_id = p_shipment_id;
  END IF;

  v_product_foreign := coalesce((v_mat ->> 'foreign_paid')::numeric, 0);
  IF v_product_foreign <= 0 THEN
    v_product_foreign := v_entry_material;
  END IF;

  v_cargo_foreign := coalesce((v_fre ->> 'foreign_paid')::numeric, 0);
  IF v_cargo_foreign <= 0 THEN
    v_cargo_foreign := v_entry_freight;
  END IF;

  v_goods_bdt := round(v_product_foreign * v_prod_rate, 2);
  v_freight_bdt := round(v_cargo_foreign * v_cargo_fx, 2);

  IF (v_product_foreign + v_cargo_foreign) > 0 THEN
    v_blended := round((v_goods_bdt + v_freight_bdt) / (v_product_foreign + v_cargo_foreign), 6);
  ELSE
    v_blended := 1;
  END IF;

  SELECT coalesce(gs.total_weight_kg, gs.received_weight, 0)
    INTO v_kg
    FROM public.global_shipments gs
   WHERE gs.id = p_shipment_id;

  IF coalesce(v_kg, 0) > 0 AND v_cargo_foreign > 0 THEN
    v_cargo_per_kg := round(v_cargo_foreign / v_kg, 6);
  END IF;

  RETURN jsonb_build_object(
    'material', v_mat,
    'freight', v_fre,
    'goods_bdt', v_goods_bdt,
    'freight_bdt', v_freight_bdt,
    'product_foreign', v_product_foreign,
    'cargo_foreign', v_cargo_foreign,
    'product_conversion_rate', v_prod_rate,
    'cargo_conversion_rate', v_cargo_fx,
    'cargo_rate', v_cargo_per_kg,
    'transaction_rate', v_blended,
    'blended_rate', v_blended
  );
END;
$$;

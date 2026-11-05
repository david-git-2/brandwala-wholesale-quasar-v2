CREATE FUNCTION public._global_shipment_landed_fx_inputs (
  p_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_mat jsonb;
  v_fre jsonb;
  v_prod_rate numeric := 1;
  v_cargo_fx numeric := 1;
  v_product_foreign numeric := 0;
  v_cargo_foreign numeric := 0;
  v_entry_material numeric := 0;
  v_entry_freight numeric := 0;
  v_goods_bdt numeric := 0;
  v_freight_bdt numeric := 0;
  v_blended numeric := 1;
  v_kg numeric := 0;
  v_cargo_per_kg numeric := 0;
  v_mat_count integer := 0;
  v_fre_count integer := 0;
begin
  v_mat := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'material');
  v_fre := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'freight');

  v_mat_count := coalesce((v_mat ->> 'payment_count')::integer, 0);
  v_fre_count := coalesce((v_fre ->> 'payment_count')::integer, 0);

  if v_mat_count > 0 then
    v_prod_rate := coalesce((v_mat ->> 'conversion_rate')::numeric, 1);
  end if;
  if v_fre_count > 0 then
    v_cargo_fx := coalesce((v_fre ->> 'conversion_rate')::numeric, 1);
  end if;

  select
    coalesce(sum(gce.amount) filter (where gce.is_capitalizable and gce.cost_bucket = 'material'), 0),
    coalesce(sum(gce.amount) filter (where gce.is_capitalizable and gce.cost_bucket = 'freight'), 0)
  into v_entry_material, v_entry_freight
  from public.global_shipment_cost_entries gce
  where gce.shipment_id = p_shipment_id;

  v_product_foreign := coalesce((v_mat ->> 'foreign_paid')::numeric, 0);
  if v_product_foreign <= 0 then
    v_product_foreign := v_entry_material;
  end if;

  v_cargo_foreign := coalesce((v_fre ->> 'foreign_paid')::numeric, 0);
  if v_cargo_foreign <= 0 then
    v_cargo_foreign := v_entry_freight;
  end if;

  v_goods_bdt := round(v_product_foreign * v_prod_rate, 2);
  v_freight_bdt := round(v_cargo_foreign * v_cargo_fx, 2);

  if (v_product_foreign + v_cargo_foreign) > 0 then
    v_blended := round((v_goods_bdt + v_freight_bdt) / (v_product_foreign + v_cargo_foreign), 6);
  else
    v_blended := 1;
  end if;

  select coalesce(gs.total_weight_kg, gs.received_weight, 0)
  into v_kg
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if coalesce(v_kg, 0) > 0 and v_cargo_foreign > 0 then
    v_cargo_per_kg := round(v_cargo_foreign / v_kg, 6);
  end if;

  return jsonb_build_object(
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
end;
$function$;

GRANT ALL ON FUNCTION public._global_shipment_landed_fx_inputs(bigint) TO anon;

GRANT ALL ON FUNCTION public._global_shipment_landed_fx_inputs(bigint) TO authenticated;

GRANT ALL ON FUNCTION public._global_shipment_landed_fx_inputs(bigint) TO service_role;
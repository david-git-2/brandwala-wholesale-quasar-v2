-- Landed stamp called gs.product_conversion_rate after header rate columns were dropped (20270814000030).

CREATE OR REPLACE FUNCTION "public"."refresh_global_shipment_fx_from_ap_payments"("p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_mat jsonb;
  v_fre jsonb;
  v_prod_rate numeric;
  v_cargo_rate numeric;
  v_blended numeric;
  v_bdt numeric;
  v_foreign numeric;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  v_mat := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'material');
  v_fre := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'freight');

  v_prod_rate := coalesce((v_mat ->> 'conversion_rate')::numeric, 1);
  v_cargo_rate := coalesce((v_fre ->> 'conversion_rate')::numeric, 1);

  v_bdt := coalesce((v_mat ->> 'bdt_paid')::numeric, 0) + coalesce((v_fre ->> 'bdt_paid')::numeric, 0);
  v_foreign := coalesce((v_mat ->> 'foreign_paid')::numeric, 0) + coalesce((v_fre ->> 'foreign_paid')::numeric, 0);

  if v_foreign > 0 then
    v_blended := round(v_bdt / v_foreign, 6);
  else
    v_blended := 1;
  end if;

  if not exists (select 1 from public.global_shipments gs where gs.id = p_shipment_id) then
    raise exception 'shipment not found';
  end if;

  return jsonb_build_object(
    'material', v_mat,
    'freight', v_fre,
    'product_conversion_rate', v_prod_rate,
    'cargo_conversion_rate', v_cargo_rate,
    'transaction_rate', v_blended
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."_global_shipment_landed_fx_inputs"("p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_mat jsonb;
  v_fre jsonb;
  v_goods_bdt numeric := 0;
  v_freight_bdt numeric := 0;
  v_prod_rate numeric := 1;
  v_cargo_rate numeric := 1;
  v_tx_rate numeric;
  v_product_foreign numeric := 0;
  v_cargo_foreign numeric := 0;
  v_blended numeric := 1;
  v_bdt_paid numeric := 0;
  v_foreign_paid numeric := 0;
begin
  v_mat := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'material');
  v_fre := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'freight');

  v_prod_rate := coalesce((v_mat ->> 'conversion_rate')::numeric, 1);
  v_cargo_rate := coalesce((v_fre ->> 'conversion_rate')::numeric, 1);

  v_bdt_paid := coalesce((v_mat ->> 'bdt_paid')::numeric, 0) + coalesce((v_fre ->> 'bdt_paid')::numeric, 0);
  v_foreign_paid := coalesce((v_mat ->> 'foreign_paid')::numeric, 0) + coalesce((v_fre ->> 'foreign_paid')::numeric, 0);

  if v_foreign_paid > 0 then
    v_tx_rate := round(v_bdt_paid / v_foreign_paid, 6);
  else
    v_tx_rate := null;
  end if;

  select
    coalesce(sum(gce.amount) filter (where gce.is_capitalizable and gce.cost_bucket = 'material'), 0),
    coalesce(sum(gce.amount) filter (where gce.is_capitalizable and gce.cost_bucket = 'freight'), 0)
  into v_goods_bdt, v_freight_bdt
  from public.global_shipment_cost_entries gce
  where gce.shipment_id = p_shipment_id;

  if coalesce(v_prod_rate, 0) > 0 then
    v_product_foreign := v_goods_bdt / v_prod_rate;
  else
    v_product_foreign := v_goods_bdt;
  end if;

  if coalesce(v_cargo_rate, 0) > 0 then
    v_cargo_foreign := v_freight_bdt / v_cargo_rate;
  else
    v_cargo_foreign := v_freight_bdt;
  end if;

  if v_tx_rate is not null and v_tx_rate > 0 then
    v_blended := v_tx_rate;
  elsif (v_product_foreign + v_cargo_foreign) > 0 then
    v_blended := (v_goods_bdt + v_freight_bdt) / (v_product_foreign + v_cargo_foreign);
  else
    v_blended := 1;
  end if;

  return jsonb_build_object(
    'goods_bdt', v_goods_bdt,
    'freight_bdt', v_freight_bdt,
    'product_foreign', v_product_foreign,
    'cargo_foreign', v_cargo_foreign,
    'blended_rate', v_blended
  );
end;
$$;

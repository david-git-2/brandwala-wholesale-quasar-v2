-- Transaction rate fallback: money-weighted legs only — no arithmetic mean of bucket rates.

CREATE OR REPLACE FUNCTION "public"."recalculate_shipment_transaction_rate"("p_shipment_id" bigint) RETURNS numeric
    LANGUAGE "plpgsql"
    AS $$
declare
  v_product_conv numeric;
  v_cargo_conv numeric;
  v_cargo_rate numeric;
  v_received_weight numeric;
  v_shipment_type text;
  v_goods_cost_gbp numeric;
  v_cargo_cost_gbp numeric;
  v_goods_cost_bdt numeric;
  v_cargo_cost_bdt numeric;
  v_total_cost_gbp numeric;
  v_total_cost_bdt numeric;
  v_cargo_weight numeric;
  v_transaction_rate numeric;
begin
  select
    product_conversion_rate,
    cargo_conversion_rate,
    cargo_rate,
    received_weight,
    shipment_type
  into
    v_product_conv,
    v_cargo_conv,
    v_cargo_rate,
    v_received_weight,
    v_shipment_type
  from public.shipments
  where id = p_shipment_id;

  if coalesce(v_shipment_type, 'international') <> 'international' then
    update public.shipments
    set transaction_rate = null
    where id = p_shipment_id;
    return null;
  end if;

  select coalesce(sum(price_gbp * quantity), 0)
  into v_goods_cost_gbp
  from public.shipment_items
  where shipment_id = p_shipment_id;

  v_goods_cost_bdt := coalesce(v_product_conv, 0) * v_goods_cost_gbp;
  v_cargo_weight := coalesce(v_received_weight, 0);
  v_cargo_cost_gbp := v_cargo_weight * coalesce(v_cargo_rate, 0);
  v_cargo_cost_bdt := v_cargo_cost_gbp * coalesce(v_cargo_conv, 0);
  v_total_cost_gbp := v_goods_cost_gbp + v_cargo_cost_gbp;
  v_total_cost_bdt := v_goods_cost_bdt + v_cargo_cost_bdt;

  if v_total_cost_gbp > 0 then
    v_transaction_rate := v_total_cost_bdt / v_total_cost_gbp;
  elsif v_goods_cost_gbp > 0 then
    v_transaction_rate := coalesce(v_product_conv, 1);
  elsif v_cargo_cost_gbp > 0 then
    v_transaction_rate := coalesce(v_cargo_conv, 1);
  else
    v_transaction_rate := coalesce(nullif(v_product_conv, 0), nullif(v_cargo_conv, 0), 1);
  end if;

  update public.shipments
  set transaction_rate = round(coalesce(v_transaction_rate, 1.0), 2)
  where id = p_shipment_id;

  return v_transaction_rate;
end;
$$;

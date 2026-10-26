-- Migration: Remove weight column from shipments table and update triggers
begin;

-- 1. Drop trigger first to avoid conflicts
drop trigger if exists trg_shipments_recalc_transaction_rate on public.shipments;

-- 2. Drop weight column
alter table public.shipments drop column if exists weight cascade;

-- 3. Redefine recalculation function to round to 2 decimals and exclude weight column selection
create or replace function public.recalculate_shipment_transaction_rate(p_shipment_id bigint)
returns numeric
language plpgsql
security definer
as $$
declare
  v_product_conv numeric;
  v_cargo_conv numeric;
  v_cargo_rate numeric;
  v_received_weight numeric;
  v_is_gbp boolean;
  v_goods_cost_gbp numeric := 0;
  v_goods_cost_bdt numeric := 0;
  v_cargo_weight numeric := 0;
  v_cargo_cost_gbp numeric := 0;
  v_cargo_cost_bdt numeric := 0;
  v_total_cost_gbp numeric := 0;
  v_total_cost_bdt numeric := 0;
  v_transaction_rate numeric;
begin
  select 
    product_conversion_rate,
    cargo_conversion_rate,
    cargo_rate,
    received_weight,
    is_gbp
  into 
    v_product_conv,
    v_cargo_conv,
    v_cargo_rate,
    v_received_weight,
    v_is_gbp
  from public.shipments
  where id = p_shipment_id;

  if v_is_gbp is not true then
    update public.shipments
    set transaction_rate = null
    where id = p_shipment_id;
    return null;
  end if;

  -- Sum Goods Cost in GBP
  select coalesce(sum(price_gbp * quantity), 0)
  into v_goods_cost_gbp
  from public.shipment_items
  where shipment_id = p_shipment_id;

  -- Goods Cost in BDT
  v_goods_cost_bdt := coalesce(v_product_conv, 0) * v_goods_cost_gbp;

  -- Cargo weight is received_weight directly, falling back to 0 if null
  v_cargo_weight := coalesce(v_received_weight, 0);

  -- Cargo Cost in GBP = Weight in KG * Cargo rate
  v_cargo_cost_gbp := v_cargo_weight * coalesce(v_cargo_rate, 0);

  -- Cargo Cost in BDT = Cargo Cost in GBP * Cargo conversion rate
  v_cargo_cost_bdt := v_cargo_cost_gbp * coalesce(v_cargo_conv, 0);

  v_total_cost_gbp := v_goods_cost_gbp + v_cargo_cost_gbp;
  v_total_cost_bdt := v_goods_cost_bdt + v_cargo_cost_bdt;

  if v_total_cost_gbp > 0 then
    v_transaction_rate := v_total_cost_bdt / v_total_cost_gbp;
  else
    v_transaction_rate := (coalesce(v_product_conv, 0) + coalesce(v_cargo_conv, 0)) / 2.0;
  end if;

  update public.shipments
  set transaction_rate = round(coalesce(v_transaction_rate, 1.0), 2)
  where id = p_shipment_id;

  return v_transaction_rate;
end;
$$;

-- 4. Recreate trigger without weight column
create trigger trg_shipments_recalc_transaction_rate
after update of product_conversion_rate, cargo_conversion_rate, cargo_rate, received_weight, is_gbp
on public.shipments
for each row
execute function public.trg_shipments_recalc_transaction_rate();

-- 5. Run recalculation for all shipments
do $$
declare
  v_shipment record;
begin
  for v_shipment in select id from public.shipments loop
    perform public.recalculate_shipment_transaction_rate(v_shipment.id);
  end loop;
end;
$$;

commit;

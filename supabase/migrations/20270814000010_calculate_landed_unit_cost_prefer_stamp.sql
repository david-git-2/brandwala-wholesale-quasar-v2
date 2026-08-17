-- Phase 4: sale / report cost authority = living stamp on shipment_items.landed_cost_bdt
-- Prefer stamp in calculate_landed_unit_cost (invoice post, P&L, wallet hooks).
-- Fallback to legacy header-rate formula only when stamp is null (draft / unfinalized).

begin;

create or replace function public.calculate_landed_unit_cost(p_shipment_item_id bigint)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_stamp numeric;
  v_shipment_id bigint;
  v_shipment_type public.global_shipment_type;
  v_product_conversion_rate numeric;
  v_cargo_conversion_rate numeric;
  v_cargo_rate numeric;
  v_received_weight numeric;
  v_transaction_rate numeric;

  v_purchase_price numeric;
  v_product_weight numeric;
  v_package_weight numeric;
  v_qty numeric;

  v_total_packaging_weight_kg numeric := 0;
  v_cargo_weight_kg numeric;
  v_cargo_purchase_total numeric;
  v_line_gross_weight_kg numeric;
  v_line_cargo_share numeric := 0;
  v_line_purchase_base numeric;
  v_raw_tx_rate numeric;
  v_effective_rate numeric;
  v_landed_cost numeric;
  v_total_qty numeric;
begin
  select
    shipment_id,
    purchase_price,
    product_weight,
    package_weight,
    ordered_quantity,
    landed_cost_bdt
  into
    v_shipment_id,
    v_purchase_price,
    v_product_weight,
    v_package_weight,
    v_qty,
    v_stamp
  from public.global_shipment_items
  where id = p_shipment_item_id;

  if v_shipment_id is null then
    return 0.00;
  end if;

  -- Authoritative after finalize / revise
  if v_stamp is not null then
    return round(v_stamp::numeric, 4);
  end if;

  select type, product_conversion_rate, cargo_conversion_rate, cargo_rate, received_weight, transaction_rate
  into v_shipment_type, v_product_conversion_rate, v_cargo_conversion_rate, v_cargo_rate, v_received_weight, v_transaction_rate
  from public.global_shipments
  where id = v_shipment_id;

  select coalesce(sum(((product_weight + package_weight) * ordered_quantity) / 1000.0), 0)
  into v_total_packaging_weight_kg
  from public.global_shipment_items
  where shipment_id = v_shipment_id;

  if v_received_weight is not null and v_received_weight > 0 then
    v_cargo_weight_kg := round(v_received_weight::numeric, 2);
  else
    v_cargo_weight_kg := v_total_packaging_weight_kg;
  end if;

  v_cargo_purchase_total := v_cargo_weight_kg * coalesce(v_cargo_rate, 0);
  v_line_gross_weight_kg := ((v_product_weight + v_package_weight) * v_qty) / 1000.0;

  if v_qty > 0 and v_cargo_purchase_total > 0 then
    if v_total_packaging_weight_kg > 0 then
      v_line_cargo_share := ((v_line_gross_weight_kg / v_total_packaging_weight_kg) * v_cargo_purchase_total) / v_qty;
    else
      select coalesce(sum(ordered_quantity), 0) into v_total_qty
      from public.global_shipment_items
      where shipment_id = v_shipment_id;
      if v_total_qty > 0 then
        v_line_cargo_share := ((v_qty / v_total_qty) * v_cargo_purchase_total) / v_qty;
      end if;
    end if;
  end if;

  v_line_purchase_base := coalesce(v_purchase_price, 0) + coalesce(v_line_cargo_share, 0);

  if v_shipment_type = 'local' then
    return round(v_line_purchase_base::numeric, 4);
  end if;

  -- Live blended rate (unstamped draft only)
  declare
    v_goods_purchase numeric;
    v_cargo_purchase numeric;
    v_goods_bdt numeric;
    v_cargo_bdt numeric;
    v_denom numeric;
  begin
    select coalesce(sum(purchase_price * ordered_quantity), 0)
    into v_goods_purchase
    from public.global_shipment_items
    where shipment_id = v_shipment_id;

    v_cargo_purchase := v_cargo_purchase_total;
    v_goods_bdt := v_goods_purchase * coalesce(v_product_conversion_rate, 1);
    v_cargo_bdt := v_cargo_purchase * coalesce(v_cargo_conversion_rate, 1);
    v_denom := v_goods_purchase + v_cargo_purchase;

    if v_denom > 0 then
      v_raw_tx_rate := (v_goods_bdt + v_cargo_bdt) / v_denom;
    else
      v_raw_tx_rate := (coalesce(v_product_conversion_rate, 1) + coalesce(v_cargo_conversion_rate, 1)) / 2;
    end if;
  end;

  v_effective_rate := case
    when v_raw_tx_rate is not null and v_raw_tx_rate > 0 then v_raw_tx_rate
    when v_transaction_rate is not null and v_transaction_rate > 0 then v_transaction_rate
    else (coalesce(v_product_conversion_rate, 1) + coalesce(v_cargo_conversion_rate, 1)) / 2
  end;

  v_landed_cost := v_line_purchase_base * v_effective_rate;
  return round(v_landed_cost::numeric, 4);
end;
$$;

comment on function public.calculate_landed_unit_cost(bigint) is
  'Unit cost: prefer global_shipment_items.landed_cost_bdt stamp; else legacy header-rate formula for drafts.';

commit;

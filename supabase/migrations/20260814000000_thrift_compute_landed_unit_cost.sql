-- Thrift P2 cost engine landed cost database function
begin;

create or replace function public.compute_thrift_landed_unit_cost(p_stock_id bigint)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_stock public.thrift_stocks%rowtype;
  v_shipment public.thrift_shipments%rowtype;
  v_settings public.thrift_settings%rowtype;
  v_sum_qty bigint;
  v_u numeric;
  v_product_unit_cost numeric;
  v_shipment_cargo_cost numeric;
  v_shipment_ops_cost numeric;
  v_cargo_share_per_unit numeric;
  v_ops_share_per_unit numeric;
  v_landed_unit_cost numeric;
begin
  -- 1) Load stock row
  select * into v_stock
  from public.thrift_stocks
  where id = p_stock_id;

  if not found then
    return 0;
  end if;

  -- 2) Load shipment row
  select * into v_shipment
  from public.thrift_shipments
  where id = v_stock.shipment_id;

  -- 3) Load settings row
  select * into v_settings
  from public.thrift_settings
  where tenant_id = v_stock.tenant_id;

  -- 4) Compute U
  select coalesce(sum(quantity), 0) into v_sum_qty
  from public.thrift_stocks
  where shipment_id = v_stock.shipment_id;

  v_u := greatest(v_sum_qty::numeric, 1.0);

  -- 5) Calculate components
  v_product_unit_cost := (coalesce(v_stock.origin_unit_price, 0.0) + coalesce(v_stock.extra_origin_unit_price, 0.0)) * coalesce(v_shipment.product_conversion_rate, 1.0);

  v_shipment_cargo_cost := coalesce(v_shipment.total_cargo_weight_kg, 0.0) * coalesce(v_shipment.cargo_rate, 0.0) * coalesce(v_shipment.cargo_conversion_rate, 0.0);

  v_shipment_ops_cost := (coalesce(v_settings.hand_tag_unit_cost, 0.0) * v_u) + (coalesce(v_settings.sticker_unit_cost, 0.0) * v_u) + coalesce(v_shipment.labor_total_cost, 0.0) + coalesce(v_shipment.transportation_total_cost, 0.0);

  v_cargo_share_per_unit := v_shipment_cargo_cost / v_u;
  v_ops_share_per_unit := v_shipment_ops_cost / v_u;

  v_landed_unit_cost := v_product_unit_cost + v_cargo_share_per_unit + v_ops_share_per_unit + coalesce(v_stock.additional_charges_cost, 0.0);

  return coalesce(v_landed_unit_cost, 0.0);
end;
$$;

grant execute on function public.compute_thrift_landed_unit_cost(bigint) to authenticated;

commit;

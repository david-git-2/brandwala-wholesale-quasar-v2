-- Thrift: washing_total_cost on shipments + weight-proportional cargo in landed cost SQL
begin;

alter table public.thrift_shipments
  add column if not exists washing_total_cost numeric null;

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
  v_total_weight_kg numeric;
  v_line_weight_kg numeric;
  v_product_unit_cost numeric;
  v_shipment_cargo_cost numeric;
  v_shipment_ops_cost numeric;
  v_cargo_share_per_unit numeric;
  v_ops_share_per_unit numeric;
  v_landed_unit_cost numeric;
begin
  select * into v_stock
  from public.thrift_stocks
  where id = p_stock_id;

  if not found then
    return 0;
  end if;

  select * into v_shipment
  from public.thrift_shipments
  where id = v_stock.shipment_id;

  select * into v_settings
  from public.thrift_settings
  where tenant_id = v_stock.tenant_id;

  select coalesce(sum(quantity), 0) into v_sum_qty
  from public.thrift_stocks
  where shipment_id = v_stock.shipment_id;

  v_u := greatest(v_sum_qty::numeric, 1.0);

  select coalesce(
    sum(
      (coalesce(product_weight, 0.0) + coalesce(extra_weight, 0.0))
      / 1000.0
      * coalesce(quantity, 0)
    ),
    0.0
  ) into v_total_weight_kg
  from public.thrift_stocks
  where shipment_id = v_stock.shipment_id;

  v_line_weight_kg :=
    (coalesce(v_stock.product_weight, 0.0) + coalesce(v_stock.extra_weight, 0.0))
    / 1000.0
    * coalesce(v_stock.quantity, 0);

  v_product_unit_cost :=
    (coalesce(v_stock.origin_unit_price, 0.0) + coalesce(v_stock.extra_origin_unit_price, 0.0))
    * coalesce(v_shipment.product_conversion_rate, 1.0);

  v_shipment_cargo_cost :=
    coalesce(v_shipment.total_cargo_weight_kg, 0.0)
    * coalesce(v_shipment.cargo_rate, 0.0)
    * coalesce(v_shipment.cargo_conversion_rate, 0.0);

  v_shipment_ops_cost :=
    (coalesce(v_settings.hand_tag_unit_cost, 0.0) * v_u)
    + (coalesce(v_settings.sticker_unit_cost, 0.0) * v_u)
    + coalesce(v_shipment.labor_total_cost, 0.0)
    + coalesce(v_shipment.transportation_total_cost, 0.0)
    + coalesce(v_shipment.washing_total_cost, 0.0);

  if v_total_weight_kg > 0 and coalesce(v_stock.quantity, 0) > 0 then
    v_cargo_share_per_unit :=
      ((v_line_weight_kg / v_total_weight_kg) * v_shipment_cargo_cost)
      / v_stock.quantity;
  else
    v_cargo_share_per_unit := v_shipment_cargo_cost / v_u;
  end if;

  v_ops_share_per_unit := v_shipment_ops_cost / v_u;

  v_landed_unit_cost :=
    v_product_unit_cost
    + v_cargo_share_per_unit
    + v_ops_share_per_unit
    + coalesce(v_stock.additional_charges_cost, 0.0);

  return coalesce(v_landed_unit_cost, 0.0);
end;
$$;

commit;

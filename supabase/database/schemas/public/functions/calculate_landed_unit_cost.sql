CREATE FUNCTION public.calculate_landed_unit_cost (
  p_shipment_item_id bigint
)
  RETURNS numeric
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_stamp numeric;
  v_shipment_id bigint;
  v_shipment_type public.global_shipment_type;

  v_purchase_price numeric;
  v_product_weight numeric;
  v_package_weight numeric;
  v_qty numeric;

  v_total_packaging_weight_kg numeric := 0;
  v_line_gross_weight_kg numeric;
  v_line_cargo_share numeric := 0;
  v_line_purchase_base numeric;
  v_prod_rate numeric := 1;
  v_cargo_fx numeric := 1;
  v_landed_cost numeric;
  v_total_qty numeric;
  v_cargo_foreign numeric := 0;
  v_fx jsonb;
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

  if v_stamp is not null then
    return round(v_stamp::numeric, 4);
  end if;

  select type
  into v_shipment_type
  from public.global_shipments
  where id = v_shipment_id;

  v_fx := public._global_shipment_landed_fx_inputs(v_shipment_id);
  v_cargo_foreign := coalesce((v_fx ->> 'cargo_foreign')::numeric, 0);
  v_prod_rate := coalesce((v_fx ->> 'product_conversion_rate')::numeric, 1);
  v_cargo_fx := coalesce((v_fx ->> 'cargo_conversion_rate')::numeric, 1);

  select coalesce(sum(((product_weight + package_weight) * ordered_quantity) / 1000.0), 0)
  into v_total_packaging_weight_kg
  from public.global_shipment_items
  where shipment_id = v_shipment_id;

  v_line_gross_weight_kg := ((coalesce(v_product_weight, 0) + coalesce(v_package_weight, 0)) * coalesce(v_qty, 0)) / 1000.0;

  if v_qty > 0 and v_cargo_foreign > 0 then
    if v_total_packaging_weight_kg > 0 then
      v_line_cargo_share := ((v_line_gross_weight_kg / v_total_packaging_weight_kg) * v_cargo_foreign) / v_qty;
    else
      select coalesce(sum(ordered_quantity), 0) into v_total_qty
      from public.global_shipment_items
      where shipment_id = v_shipment_id;
      if v_total_qty > 0 then
        v_line_cargo_share := ((v_qty / v_total_qty) * v_cargo_foreign) / v_qty;
      end if;
    end if;
  end if;

  v_line_purchase_base := coalesce(v_purchase_price, 0) + coalesce(v_line_cargo_share, 0);

  if v_shipment_type::text in ('local', 'domestic') then
    return round(v_line_purchase_base::numeric, 4);
  end if;

  v_landed_cost := (coalesce(v_purchase_price, 0) * v_prod_rate)
    + (coalesce(v_line_cargo_share, 0) * v_cargo_fx);
  return round(v_landed_cost::numeric, 4);
end;
$function$;

COMMENT ON FUNCTION public.calculate_landed_unit_cost(bigint) IS 'Unit cost: prefer global_shipment_items.landed_cost_bdt stamp; else draft formula using capitalizable material/freight BDT and header FX from AP pays.';

GRANT ALL ON FUNCTION public.calculate_landed_unit_cost(bigint) TO anon;

GRANT ALL ON FUNCTION public.calculate_landed_unit_cost(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.calculate_landed_unit_cost(bigint) TO service_role;
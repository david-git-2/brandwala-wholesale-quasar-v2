CREATE FUNCTION public.stamp_global_shipment_landed_costs (
  p_shipment_id bigint
)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_cargo_foreign numeric := 0;
  v_prod_rate numeric := 1;
  v_cargo_fx numeric := 1;
  v_fx jsonb;
  v_pack_kg numeric := 0;
  v_updated integer := 0;
  r record;
  v_line_gross numeric;
  v_line_cargo_share numeric;
  v_unit_product numeric;
  v_unit_cargo numeric;
  v_landed numeric;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  v_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_cargo_foreign := coalesce((v_fx ->> 'cargo_foreign')::numeric, 0);
  v_prod_rate := coalesce((v_fx ->> 'product_conversion_rate')::numeric, 1);
  v_cargo_fx := coalesce((v_fx ->> 'cargo_conversion_rate')::numeric, 1);

  select coalesce(sum(
    ((coalesce(gsi.product_weight, 0) + coalesce(gsi.package_weight, 0)) * gsi.ordered_quantity) / 1000.0
  ), 0)
  into v_pack_kg
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  perform set_config('app.allow_landed_cost_stamp', '1', true);

  for r in
    select *
    from public.global_shipment_items
    where shipment_id = p_shipment_id
  loop
    v_line_gross := (
      (coalesce(r.product_weight, 0) + coalesce(r.package_weight, 0)) * r.ordered_quantity
    ) / 1000.0;

    if v_pack_kg > 0 then
      v_line_cargo_share := (v_line_gross / v_pack_kg) * v_cargo_foreign;
    elsif (select coalesce(sum(ordered_quantity), 0) from public.global_shipment_items where shipment_id = p_shipment_id) > 0 then
      v_line_cargo_share := (r.ordered_quantity::numeric
        / (select sum(ordered_quantity) from public.global_shipment_items where shipment_id = p_shipment_id)
      ) * v_cargo_foreign;
    else
      v_line_cargo_share := 0;
    end if;

    if r.ordered_quantity > 0 then
      v_unit_product := coalesce(r.purchase_price, 0);
      v_unit_cargo := v_line_cargo_share / r.ordered_quantity;
    else
      v_unit_product := coalesce(r.purchase_price, 0);
      v_unit_cargo := 0;
    end if;

    if v_ship.type::text in ('local', 'domestic') then
      v_landed := v_unit_product + v_unit_cargo;
    else
      v_landed := (v_unit_product * v_prod_rate) + (v_unit_cargo * v_cargo_fx);
    end if;

    update public.global_shipment_items
    set landed_cost_bdt = round(v_landed::numeric, 4)
    where id = r.id;

    v_updated := v_updated + 1;
  end loop;

  perform public._stamp_global_shipment_outcome_costs(p_shipment_id);

  return v_updated;
end;
$function$;

GRANT ALL ON FUNCTION public.stamp_global_shipment_landed_costs(bigint) TO anon;

GRANT ALL ON FUNCTION public.stamp_global_shipment_landed_costs(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.stamp_global_shipment_landed_costs(bigint) TO service_role;
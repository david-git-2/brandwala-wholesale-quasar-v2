CREATE FUNCTION public._stamp_global_shipment_outcome_costs (
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
  v_blended numeric := 1;
  v_fx jsonb;
  v_pack_kg numeric := 0;
  v_updated integer := 0;
  r_out record;
  r_line record;
  v_line_gross numeric;
  v_line_cargo_share numeric;
  v_unit_base numeric;
  v_landed numeric;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if not found then
    return 0;
  end if;

  v_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_cargo_foreign := coalesce((v_fx ->> 'cargo_foreign')::numeric, 0);
  v_blended := coalesce((v_fx ->> 'blended_rate')::numeric, 1);

  select coalesce(sum(
    ((coalesce(gsi.product_weight, 0) + coalesce(gsi.package_weight, 0)) * gsi.ordered_quantity) / 1000.0
  ), 0)
  into v_pack_kg
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  for r_out in
    select o.*
    from public.global_shipment_item_outcomes o
    inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
    where gsi.shipment_id = p_shipment_id
      and o.reason <> 'ordered'::public.global_shipment_outcome_reason
  loop
    select * into r_line from public.global_shipment_items where id = r_out.shipment_item_id;

    v_line_gross := (
      (coalesce(r_line.product_weight, 0) + coalesce(r_line.package_weight, 0)) * r_line.ordered_quantity
    ) / 1000.0;

    if v_pack_kg > 0 then
      v_line_cargo_share := (v_line_gross / v_pack_kg) * v_cargo_foreign;
    elsif (select coalesce(sum(ordered_quantity), 0) from public.global_shipment_items where shipment_id = p_shipment_id) > 0 then
      v_line_cargo_share := (r_line.ordered_quantity::numeric
        / (select sum(ordered_quantity) from public.global_shipment_items where shipment_id = p_shipment_id)
      ) * v_cargo_foreign;
    else
      v_line_cargo_share := 0;
    end if;

    if r_line.ordered_quantity > 0 then
      v_unit_base := coalesce(r_out.purchase_price, 0) + (v_line_cargo_share / r_line.ordered_quantity);
    else
      v_unit_base := coalesce(r_out.purchase_price, 0);
    end if;

    if v_ship.type::text in ('local', 'domestic') then
      v_landed := v_unit_base;
    else
      v_landed := v_unit_base * v_blended;
    end if;

    update public.global_shipment_item_outcomes
    set cost = round(v_landed::numeric, 4)
    where id = r_out.id;

    v_updated := v_updated + 1;
  end loop;

  return v_updated;
end;
$function$;

GRANT ALL ON FUNCTION public._stamp_global_shipment_outcome_costs(bigint) TO anon;

GRANT ALL ON FUNCTION public._stamp_global_shipment_outcome_costs(bigint) TO authenticated;

GRANT ALL ON FUNCTION public._stamp_global_shipment_outcome_costs(bigint) TO service_role;
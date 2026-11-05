CREATE FUNCTION public.apply_global_shipment_weight_balance (
  p_shipment_id      bigint,
  p_adjustments      jsonb,
  p_transaction_rate numeric DEFAULT NULL::numeric
)
  RETURNS jsonb
  LANGUAGE plpgsql
  AS $function$
declare
  v_shipment public.global_shipments%rowtype;
  v_adjustment_count int;
  v_valid_count int;
  v_estimated_kg numeric;
  v_actual_kg numeric;
begin
  if p_adjustments is null or jsonb_typeof(p_adjustments) <> 'array' or jsonb_array_length(p_adjustments) = 0 then
    raise exception 'At least one package weight adjustment is required.';
  end if;

  select *
  into v_shipment
  from public.global_shipments
  where id = p_shipment_id;

  if not found then
    raise exception 'Shipment not found.';
  end if;

  v_actual_kg := round(coalesce(v_shipment.received_weight, 0), 2);

  if v_actual_kg <= 0 then
    raise exception 'Cargo Invoice Weight must be saved before applying weight balance.';
  end if;

  select count(*)
  into v_adjustment_count
  from jsonb_to_recordset(p_adjustments) as a(item_id bigint, package_weight numeric);

  select count(*)
  into v_valid_count
  from jsonb_to_recordset(p_adjustments) as a(item_id bigint, package_weight numeric)
  inner join public.global_shipment_items gsi
    on gsi.id = a.item_id
   and gsi.shipment_id = p_shipment_id;

  if v_adjustment_count <> v_valid_count then
    raise exception 'One or more adjustment rows do not belong to this shipment.';
  end if;

  if public.global_shipment_costs_are_locked(v_shipment) then
    raise exception 'shipment costs are locked';
  end if;

  perform set_config('app.skip_item_landed_restamp', '1', true);

  update public.global_shipment_items gsi
  set
    package_weight = adj.package_weight,
    updated_at = now()
  from jsonb_to_recordset(p_adjustments) as adj(item_id bigint, package_weight numeric)
  where gsi.id = adj.item_id
    and gsi.shipment_id = p_shipment_id;

  perform set_config('app.skip_item_landed_restamp', '0', true);

  perform public.stamp_global_shipment_landed_costs(p_shipment_id);

  update public.global_shipments
  set updated_at = now()
  where id = p_shipment_id;

  select coalesce(
    sum((coalesce(gsi.product_weight, 0) + coalesce(gsi.package_weight, 0)) * gsi.ordered_quantity),
    0
  ) / 1000.0
  into v_estimated_kg
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  return jsonb_build_object(
    'estimated_kg', v_estimated_kg,
    'actual_kg', v_actual_kg,
    'delta_kg', v_actual_kg - v_estimated_kg
  );
end;
$function$;

GRANT ALL ON FUNCTION public.apply_global_shipment_weight_balance(bigint, jsonb, numeric) TO anon;

GRANT ALL ON FUNCTION public.apply_global_shipment_weight_balance(bigint, jsonb, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.apply_global_shipment_weight_balance(bigint, jsonb, numeric) TO service_role;
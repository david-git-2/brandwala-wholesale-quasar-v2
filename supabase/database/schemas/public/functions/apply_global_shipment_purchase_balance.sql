CREATE FUNCTION public.apply_global_shipment_purchase_balance (
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
  v_estimated_total numeric;
  v_actual_total numeric;
begin
  if p_adjustments is null or jsonb_typeof(p_adjustments) <> 'array' or jsonb_array_length(p_adjustments) = 0 then
    raise exception 'At least one purchase price adjustment is required.';
  end if;

  select *
  into v_shipment
  from public.global_shipments
  where id = p_shipment_id;

  if not found then
    raise exception 'Shipment not found.';
  end if;

  select coalesce(sum(e.amount), 0)
  into v_actual_total
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_bucket = 'material'::public.global_shipment_cost_bucket;

  if v_actual_total <= 0 then
    raise exception 'Product cost entry amount must be saved before applying purchase price balance.';
  end if;

  select count(*)
  into v_adjustment_count
  from jsonb_to_recordset(p_adjustments) as a(item_id bigint, purchase_price numeric);

  select count(*)
  into v_valid_count
  from jsonb_to_recordset(p_adjustments) as a(item_id bigint, purchase_price numeric)
  inner join public.global_shipment_items gsi
    on gsi.id = a.item_id
   and gsi.shipment_id = p_shipment_id;

  if v_adjustment_count <> v_valid_count then
    raise exception 'One or more adjustment rows do not belong to this shipment.';
  end if;

  update public.global_shipment_items gsi
  set
    purchase_price = adj.purchase_price,
    updated_at = now()
  from jsonb_to_recordset(p_adjustments) as adj(item_id bigint, purchase_price numeric)
  where gsi.id = adj.item_id
    and gsi.shipment_id = p_shipment_id;

  update public.global_shipments
  set updated_at = now()
  where id = p_shipment_id;

  select coalesce(
    sum(gsi.purchase_price * gsi.ordered_quantity),
    0
  )
  into v_estimated_total
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  return jsonb_build_object(
    'estimated_total', v_estimated_total,
    'actual_total', v_actual_total,
    'delta_total', v_actual_total - v_estimated_total
  );
end;
$function$;

GRANT ALL ON FUNCTION public.apply_global_shipment_purchase_balance(bigint, jsonb, numeric) TO anon;

GRANT ALL ON FUNCTION public.apply_global_shipment_purchase_balance(bigint, jsonb, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.apply_global_shipment_purchase_balance(bigint, jsonb, numeric) TO service_role;
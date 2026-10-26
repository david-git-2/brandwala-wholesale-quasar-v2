-- Balance RPCs: lines only; purchase target from product cost entries; no transaction_rate write.
-- v2: doc/procurement_stock/shipment/schema.md §2 · Match invoices alignment

begin;

create or replace function public.apply_global_shipment_weight_balance(
  p_shipment_id bigint,
  p_adjustments jsonb,
  p_transaction_rate numeric default null
) returns jsonb
language plpgsql
security invoker
as $$
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

  update public.global_shipment_items gsi
  set
    package_weight = adj.package_weight,
    updated_at = now()
  from jsonb_to_recordset(p_adjustments) as adj(item_id bigint, package_weight numeric)
  where gsi.id = adj.item_id
    and gsi.shipment_id = p_shipment_id;

  update public.products p
  set
    package_weight = adj.package_weight,
    updated_at = now()
  from jsonb_to_recordset(p_adjustments) as adj(item_id bigint, package_weight numeric)
  inner join public.global_shipment_items gsi
    on gsi.id = adj.item_id
   and gsi.shipment_id = p_shipment_id
  where p.id = gsi.product_id
    and gsi.product_id is not null;

  -- Touch shipment updated_at only — do not write transaction_rate (p_transaction_rate ignored)
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
$$;

create or replace function public.apply_global_shipment_purchase_balance(
  p_shipment_id bigint,
  p_adjustments jsonb,
  p_transaction_rate numeric default null
) returns jsonb
language plpgsql
security invoker
as $$
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

  -- Invoice target = Σ product cost-entry amounts (v2); not header purchase_invoice_total
  select coalesce(sum(e.amount), 0)
  into v_actual_total
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_type = 'product';

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

  -- Touch shipment updated_at only — do not write transaction_rate (p_transaction_rate ignored)
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
$$;

grant execute on function public.apply_global_shipment_weight_balance(bigint, jsonb, numeric) to authenticated;
grant execute on function public.apply_global_shipment_purchase_balance(bigint, jsonb, numeric) to authenticated;

notify pgrst, 'reload schema';

commit;

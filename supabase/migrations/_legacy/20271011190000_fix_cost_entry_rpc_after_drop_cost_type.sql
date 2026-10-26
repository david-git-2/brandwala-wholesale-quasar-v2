-- After 20271010210000 dropped global_shipment_cost_entries.cost_type, these RPCs still referenced it.

CREATE OR REPLACE FUNCTION "public"."list_global_shipment_cost_entries"("p_shipment_id" bigint) RETURNS SETOF "public"."global_shipment_cost_entries"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent bigint;
begin
  select parent_tenant_id into v_parent
  from public.global_shipments
  where id = p_shipment_id;

  if v_parent is null then
    raise exception 'shipment not found';
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_parent
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  return query
  select e.*
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
  order by e.cost_bucket, e.cost_component, e.id;
end;
$$;


CREATE OR REPLACE FUNCTION "public"."apply_global_shipment_purchase_balance"("p_shipment_id" bigint, "p_adjustments" "jsonb", "p_transaction_rate" numeric DEFAULT NULL::numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
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
$$;


CREATE OR REPLACE FUNCTION "public"."return_shipment_to_vendor"("p_shipment_id" bigint, "p_items_qty" "jsonb", "p_outcome" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_item jsonb;
  v_stock_id bigint;
  v_shipment_item_id bigint;
  v_qty numeric;
  v_mov_id bigint;
  v_amount numeric := 0;
  v_ledger jsonb;
  v_vendor_id bigint;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if v_ship.status is distinct from 'received' then
    raise exception 'shipment must be received before return';
  end if;

  if p_outcome not in ('cash_refund', 'store_credit') then
    raise exception 'outcome must be cash_refund or store_credit';
  end if;

  if not public.has_active_tenant_membership(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  v_vendor_id := v_ship.vendor_id;

  insert into public.stock_movements (
    tenant_id, movement_no, movement_type, reference_type, reference_id, notes, created_by_email
  ) values (
    v_ship.parent_tenant_id,
    'VR-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('stock_movements_id_seq')::text, 6, '0'),
    'return_inbound',
    'shipment_return',
    p_shipment_id::text,
    'Vendor return outcome: ' || p_outcome,
    public.current_user_email()
  )
  returning id into v_mov_id;

  for v_item in select value from jsonb_array_elements(coalesce(p_items_qty, '[]'::jsonb))
  loop
    v_stock_id := (v_item->>'global_stock_id')::bigint;
    v_shipment_item_id := (v_item->>'shipment_item_id')::bigint;
    v_qty := coalesce((v_item->>'quantity')::numeric, 0);

    if v_stock_id is null and v_shipment_item_id is not null then
      select gs.id into v_stock_id
      from public.global_stocks gs
      join public.global_stock_types gst on gst.id = gs.stock_type_id
      where gs.shipment_item_id = v_shipment_item_id
        and gs.parent_tenant_id = v_ship.parent_tenant_id
        and gst.is_sellable = true
        and gs.availability = 'sellable'::public.stock_availability
      order by gs.quantity desc, gs.id
      limit 1;
    end if;

    if v_stock_id is null or v_qty <= 0 then
      continue;
    end if;

    insert into public.stock_movement_lines (
      movement_id, stock_id, quantity, from_availability, to_availability
    ) values (
      v_mov_id, v_stock_id, v_qty, 'sellable'::public.stock_availability, 'held'::public.stock_availability
    );

    v_amount := v_amount + (v_qty * coalesce(
      (select gsi.landed_cost_bdt from public.global_stocks gs
       join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
       where gs.id = v_stock_id),
      0
    ));
  end loop;

  perform public.post_stock_movement(v_mov_id);

  if v_amount <= 0 then
    v_amount := coalesce((
      select sum(coalesce(e.amount, 0))
      from public.global_shipment_cost_entries e
      where e.shipment_id = p_shipment_id and e.cost_bucket = 'material'::public.global_shipment_cost_bucket
    ), 0);
  end if;

  if p_outcome = 'cash_refund' then
    v_ledger := public.record_ledger_transaction(
      p_parent_tenant_id => v_ship.parent_tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => v_ship.parent_tenant_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_source_type => 'shipment_return',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object('outcome', 'cash_refund', 'movement_id', v_mov_id)
    );
    if v_vendor_id is not null then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_ship.parent_tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id),
        p_entity_type => 'vendor',
        p_entity_id => v_vendor_id,
        p_type => 'debit',
        p_amount => v_amount,
        p_currency_code => 'BDT',
        p_source_type => 'shipment_return',
        p_source_id => p_shipment_id::text,
        p_metadata => jsonb_build_object('outcome', 'cash_refund', 'movement_id', v_mov_id)
      );
    end if;
  else
    v_ledger := public.record_ledger_transaction(
      p_parent_tenant_id => v_ship.parent_tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id),
      p_entity_type => 'vendor',
      p_entity_id => v_vendor_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_source_type => 'shipment_return',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object('outcome', 'store_credit', 'movement_id', v_mov_id)
    );
  end if;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'outcome', p_outcome,
    'movement_id', v_mov_id,
    'return_processed', true,
    'wallet_posted', true,
    'amount_bdt', v_amount
  );
end;
$$;

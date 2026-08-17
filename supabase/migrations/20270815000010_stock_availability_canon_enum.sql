begin;

-- 1. New enum
create type public.stock_availability_new as enum ('sellable', 'held', 'unsellable');

-- 2. Migrate global_stocks.availability
alter table public.global_stocks
  alter column availability drop default;

alter table public.global_stocks
  alter column availability type public.stock_availability_new
  using (
    case availability::text
      when 'sellable' then 'sellable'
      when 'damaged' then 'unsellable'
      when 'hold' then 'held'
      when 'reserved' then 'held'
      when 'returned' then 'held'
      else 'sellable'
    end
  )::public.stock_availability_new;

alter table public.global_stocks
  alter column availability set default 'sellable'::public.stock_availability_new;

-- 3. Migrate stock_movement_lines (nullable columns)
alter table public.stock_movement_lines
  alter column from_availability type public.stock_availability_new
  using (
    case from_availability::text
      when 'sellable' then 'sellable'
      when 'damaged' then 'unsellable'
      when 'hold' then 'held'
      when 'reserved' then 'held'
      when 'returned' then 'held'
      else null
    end
  )::public.stock_availability_new;

alter table public.stock_movement_lines
  alter column to_availability type public.stock_availability_new
  using (
    case to_availability::text
      when 'sellable' then 'sellable'
      when 'damaged' then 'unsellable'
      when 'hold' then 'held'
      when 'reserved' then 'held'
      when 'returned' then 'held'
      else null
    end
  )::public.stock_availability_new;

-- 4. Swap enum names (cascade drops functions referencing old enum in signature)
drop type public.stock_availability cascade;
alter type public.stock_availability_new rename to stock_availability;

-- 4b. Recreate add_stock_movement_line with updated type signature
create or replace function public.add_stock_movement_line(
  p_movement_id bigint,
  p_stock_id bigint,
  p_quantity numeric,
  p_from_location_id bigint default null,
  p_to_location_id bigint default null,
  p_from_availability public.stock_availability default null,
  p_to_availability public.stock_availability default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mov public.stock_movements%rowtype;
  v_line public.stock_movement_lines%rowtype;
begin
  select * into v_mov from public.stock_movements where id = p_movement_id for update;
  if not found then
    raise exception 'movement not found';
  end if;
  if v_mov.is_posted then
    raise exception 'movement already posted';
  end if;
  if not public.has_active_tenant_membership(v_mov.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;
  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be positive';
  end if;

  insert into public.stock_movement_lines (
    movement_id, stock_id, from_location_id, to_location_id,
    from_availability, to_availability, quantity
  ) values (
    p_movement_id, p_stock_id, p_from_location_id, p_to_location_id,
    p_from_availability, p_to_availability, p_quantity
  )
  returning * into v_line;

  return jsonb_build_object('line', to_jsonb(v_line));
end;
$$;

grant execute on function public.add_stock_movement_line(bigint, bigint, numeric, bigint, bigint, public.stock_availability, public.stock_availability) to authenticated;

-- 5. Patch return_shipment_to_vendor: 'returned' → 'held'
create or replace function public.return_shipment_to_vendor(
  p_shipment_id bigint,
  p_items_qty jsonb,
  p_outcome text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
      select sum(coalesce(e.amount, 0) * coalesce(e.exchange_rate, 1))
      from public.global_shipment_cost_entries e
      where e.shipment_id = p_shipment_id and e.cost_type = 'product'
    ), 0);
  end if;

  if p_outcome = 'cash_refund' then
    v_ledger := public.record_ledger_transaction(
      p_tenant_id => v_ship.parent_tenant_id,
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
        p_tenant_id => v_ship.parent_tenant_id,
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
      p_tenant_id => v_ship.parent_tenant_id,
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

grant execute on function public.return_shipment_to_vendor(bigint, jsonb, text) to authenticated;

commit;

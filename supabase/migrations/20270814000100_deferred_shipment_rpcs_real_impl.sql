-- Forward fix: replace stub RPC bodies already applied in earlier 20270814* migrations

begin;

create or replace function public.global_stock_hold_qty(p_global_stock_id bigint)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce((
      select sum(gii.quantity - coalesce(gii.return_quantity, 0))
      from public.global_invoice_items gii
      join public.global_invoices gi on gi.id = gii.invoice_id
      where gii.global_stock_id = p_global_stock_id
        and gi.invoice_status = 'draft'::public.global_invoice_status
    ), 0)
    + coalesce((
      select sum(sci.quantity)
      from public.shop_cart_items sci
      where sci.global_stock_id = p_global_stock_id
    ), 0);
$$;

grant execute on function public.global_stock_hold_qty(bigint) to authenticated;

create or replace function public.global_stock_atp_qty(p_global_stock_id bigint)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select greatest(
    coalesce((
      select sum(gs.quantity)
      from public.global_stocks gs
      join public.global_stock_types gst on gst.id = gs.stock_type_id
      left join public.stock_locations sl on sl.id = gs.location_id
      where gs.id = p_global_stock_id
        and gst.is_sellable = true
        and gs.availability = 'sellable'::public.stock_availability
        and (gs.location_id is null or sl.is_pickable = true)
    ), 0) - public.global_stock_hold_qty(p_global_stock_id),
    0
  );
$$;

grant execute on function public.global_stock_atp_qty(bigint) to authenticated;

create or replace function public.list_child_stock_atp(
  p_child_tenant_id bigint,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_total_count bigint;
  v_data jsonb;
begin
  if not public.has_active_tenant_membership(p_child_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  select count(distinct s.id)
  into v_total_count
  from public.global_shipments s
  where s.assigned_child_tenant_id = p_child_tenant_id
    and s.status = 'received'
    and (
      p_search is null or p_search = '' or (
        s.name ilike '%' || p_search || '%'
        or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
      )
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      s.id as sort_id,
      jsonb_build_object(
        'shipment_id', s.id,
        'shipment_name', s.name,
        'tenant_shipment_id', s.tenant_shipment_id,
        'parent_tenant_id', s.parent_tenant_id,
        'status', s.status,
        'received_date', s.received_date,
        'total_ordered_qty', coalesce(sum(gsi.ordered_quantity), 0),
        'total_sellable_qty', coalesce(sum(gs.quantity) filter (
          where gst.is_sellable = true
            and gs.availability = 'sellable'::public.stock_availability
            and (gs.location_id is null or sl.is_pickable = true)
        ), 0),
        'atp_qty', coalesce(sum(public.global_stock_atp_qty(gs.id)), 0)
      ) as row_json
    from public.global_shipments s
    left join public.global_shipment_items gsi on gsi.shipment_id = s.id
    left join public.global_stocks gs on gs.shipment_item_id = gsi.id
    left join public.global_stock_types gst on gst.id = gs.stock_type_id
    left join public.stock_locations sl on sl.id = gs.location_id
    where s.assigned_child_tenant_id = p_child_tenant_id
      and s.status = 'received'
      and (
        p_search is null or p_search = '' or (
          s.name ilike '%' || p_search || '%'
          or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
        )
      )
    group by s.id, s.name, s.tenant_shipment_id, s.parent_tenant_id, s.status, s.received_date
    order by s.id desc
    limit p_limit
    offset p_offset
  ) q;

  return jsonb_build_object(
    'data', v_data,
    'total', v_total_count
  );
end;
$$;

grant execute on function public.list_child_stock_atp(bigint, text, integer, integer) to authenticated;

commit;

begin;

create or replace function public.post_stock_movement(p_movement_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mov public.stock_movements%rowtype;
  v_line public.stock_movement_lines%rowtype;
  v_stock public.global_stocks%rowtype;
  v_new_qty numeric;
begin
  select * into v_mov
  from public.stock_movements
  where id = p_movement_id
  for update;

  if not found then
    raise exception 'stock movement not found';
  end if;

  if v_mov.is_posted then
    raise exception 'stock movement already posted';
  end if;

  if not public.has_active_tenant_membership(v_mov.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  for v_line in
    select * from public.stock_movement_lines where movement_id = p_movement_id
  loop
    if v_line.stock_id is null then
      continue;
    end if;

    select * into v_stock
    from public.global_stocks
    where id = v_line.stock_id
    for update;

    if not found then
      raise exception 'stock % not found for movement line', v_line.stock_id;
    end if;

    case v_mov.movement_type
      when 'adjustment' then
        if v_line.to_availability is not null and v_line.from_availability is null then
          v_new_qty := v_stock.quantity + v_line.quantity;
        else
          v_new_qty := v_stock.quantity - v_line.quantity;
        end if;
        if v_new_qty < 0 then
          raise exception 'adjustment would make stock % negative', v_line.stock_id;
        end if;
        update public.global_stocks
        set
          quantity = v_new_qty,
          location_id = coalesce(v_line.to_location_id, location_id),
          availability = coalesce(v_line.to_availability, availability),
          updated_at = now()
        where id = v_line.stock_id;

      when 'location_transfer', 'availability_transfer', 'receive_putaway' then
        update public.global_stocks
        set
          location_id = coalesce(v_line.to_location_id, location_id),
          availability = coalesce(v_line.to_availability, availability),
          updated_at = now()
        where id = v_line.stock_id;

      when 'return_inbound', 'receive_rollback' then
        v_new_qty := v_stock.quantity - v_line.quantity;
        if v_new_qty < 0 then
          raise exception 'return would make stock % negative', v_line.stock_id;
        end if;
        update public.global_stocks
        set quantity = v_new_qty, updated_at = now()
        where id = v_line.stock_id;

      else
        raise exception 'unsupported movement type %', v_mov.movement_type;
    end case;
  end loop;

  update public.stock_movements
  set is_posted = true, posted_at = now(), updated_at = now()
  where id = p_movement_id;

  return jsonb_build_object(
    'movement_id', p_movement_id,
    'is_posted', true,
    'posted_at', now()
  );
end;
$$;

create or replace function public.create_stock_movement(
  p_tenant_id bigint,
  p_movement_type public.stock_movement_type,
  p_notes text default null,
  p_reference_type text default null,
  p_reference_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mov public.stock_movements%rowtype;
  v_no text;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  v_no := 'SM-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('stock_movements_id_seq')::text, 6, '0');

  insert into public.stock_movements (
    tenant_id, movement_no, movement_type, reference_type, reference_id, notes, created_by_email
  ) values (
    p_tenant_id,
    v_no,
    p_movement_type,
    p_reference_type,
    p_reference_id,
    p_notes,
    public.current_user_email()
  )
  returning * into v_mov;

  return jsonb_build_object('movement', to_jsonb(v_mov));
end;
$$;

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

create or replace function public.list_stock_movements(
  p_tenant_id bigint,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_data jsonb;
  v_total bigint;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  select count(*) into v_total
  from public.stock_movements m
  where m.tenant_id = p_tenant_id;

  select coalesce(jsonb_agg(to_jsonb(m) order by m.id desc), '[]'::jsonb)
  into v_data
  from (
    select * from public.stock_movements
    where tenant_id = p_tenant_id
    order by id desc
    limit p_limit offset p_offset
  ) m;

  return jsonb_build_object('data', v_data, 'total', v_total);
end;
$$;

grant execute on function public.post_stock_movement(bigint) to authenticated;
grant execute on function public.create_stock_movement(bigint, public.stock_movement_type, text, text, text) to authenticated;
grant execute on function public.add_stock_movement_line(bigint, bigint, numeric, bigint, bigint, public.stock_availability, public.stock_availability) to authenticated;
grant execute on function public.list_stock_movements(bigint, integer, integer) to authenticated;

commit;

begin;

create or replace function public.pay_settle_shipment_costs(
  p_shipment_id bigint,
  p_cost_entry_ids bigint[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_entry public.global_shipment_cost_entries%rowtype;
  v_amount numeric;
  v_settled_count integer := 0;
  v_wallet_posted boolean := false;
  v_ledger jsonb;
  v_wallet_entity_type text;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if v_ship.status is distinct from 'received' then
    raise exception 'shipment must be received before settlement';
  end if;

  if not public.has_active_tenant_membership(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  for v_entry in
    select *
    from public.global_shipment_cost_entries
    where shipment_id = p_shipment_id
      and (p_cost_entry_ids is null or id = any(p_cost_entry_ids))
      and payment_source is not null
      and entity_type is not null
      and entity_id is not null
      and settled_at is null
  loop
    if v_entry.entity_type = 'shipment' then
      raise exception 'cost entry % cannot settle shipment entity', v_entry.id;
    end if;

    v_amount := round(coalesce(v_entry.amount, 0) * coalesce(v_entry.exchange_rate, 1), 4);
    if v_amount <= 0 then
      continue;
    end if;

    v_wallet_entity_type := case
      when v_entry.entity_type = 'cargo_company' then 'cargo_company'
      else v_entry.entity_type
    end;

    if v_entry.payment_source in ('cash', 'wallet') then
      v_ledger := public.record_ledger_transaction(
        p_tenant_id => v_ship.parent_tenant_id,
        p_entity_type => v_wallet_entity_type,
        p_entity_id => v_entry.entity_id,
        p_type => 'debit',
        p_amount => v_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'shipment',
        p_source_id => p_shipment_id::text,
        p_metadata => jsonb_build_object(
          'cost_entry_id', v_entry.id,
          'payment_source', v_entry.payment_source,
          'purpose', 'shipment_cost_settle_payee'
        ),
        p_target_bucket => 'available'
      );

      v_ledger := public.record_ledger_transaction(
        p_tenant_id => v_ship.parent_tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => v_ship.parent_tenant_id,
        p_type => 'debit',
        p_amount => v_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'shipment',
        p_source_id => p_shipment_id::text,
        p_metadata => jsonb_build_object(
          'cost_entry_id', v_entry.id,
          'payment_source', v_entry.payment_source,
          'purpose', 'shipment_cost_settle_tenant_cash'
        ),
        p_target_bucket => 'available'
      );
      v_wallet_posted := true;

    elsif v_entry.payment_source = 'credit' then
      v_ledger := public.record_ledger_transaction(
        p_tenant_id => v_ship.parent_tenant_id,
        p_entity_type => v_wallet_entity_type,
        p_entity_id => v_entry.entity_id,
        p_type => 'credit',
        p_amount => v_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'shipment',
        p_source_id => p_shipment_id::text,
        p_metadata => jsonb_build_object(
          'cost_entry_id', v_entry.id,
          'payment_source', 'credit',
          'purpose', 'shipment_cost_credit_payable'
        ),
        p_target_bucket => 'pending'
      );
      v_wallet_posted := true;
    else
      raise exception 'unsupported payment_source % on entry %', v_entry.payment_source, v_entry.id;
    end if;

    update public.global_shipment_cost_entries
    set
      settled_at = now(),
      settlement_ledger_id = coalesce((v_ledger->>'id')::uuid, settlement_ledger_id),
      updated_at = now()
    where id = v_entry.id;

    v_settled_count := v_settled_count + 1;
  end loop;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'settled_entries_count', v_settled_count,
    'wallet_posted', v_wallet_posted and v_settled_count > 0
  );
end;
$$;

grant execute on function public.pay_settle_shipment_costs(bigint, bigint[]) to authenticated;

commit;

begin;

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
    v_qty := coalesce((v_item->>'quantity')::numeric, 0);
    if v_stock_id is null or v_qty <= 0 then
      continue;
    end if;

    insert into public.stock_movement_lines (
      movement_id, stock_id, quantity, from_availability, to_availability
    ) values (
      v_mov_id, v_stock_id, v_qty, 'sellable'::public.stock_availability, 'returned'::public.stock_availability
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

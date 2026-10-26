-- Phase W6: Receive checklist + received_quantity persistence
begin;

-- 1. Add received_quantity column to global_shipment_items
alter table public.global_shipment_items
  add column if not exists received_quantity int null
  constraint global_shipment_items_received_quantity_check check (received_quantity is null or received_quantity >= 0);

-- 2. Update finalize_global_shipment to persist received_quantity per line from p_stock_rows
create or replace function public.finalize_global_shipment(
  p_shipment_id bigint,
  p_stock_rows jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_stamped integer;
  v_stock_count integer := 0;
  v_row jsonb;
  v_parent bigint;
  v_loc bigint;
  v_avail public.stock_availability;
  v_stock_id bigint;
  v_mov_id bigint;
  v_mov_no text;
  v_qty int;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  v_parent := v_ship.parent_tenant_id;

  if not public.user_can_manage_parent_tenant(v_parent) then
    raise exception 'not allowed';
  end if;

  if v_ship.stock_ready = true or v_ship.status = 'received' then
    raise exception 'shipment already finalized; use revise_global_shipment_costs';
  end if;

  if not exists (
    select 1 from public.global_shipment_items where shipment_id = p_shipment_id
  ) then
    raise exception 'shipment has no items';
  end if;

  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  if not exists (
    select 1 from public.global_shipment_cost_entries where shipment_id = p_shipment_id
  ) then
    raise exception 'shipment has no cost entries';
  end if;

  v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);

  if p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
    v_mov_no := 'RP-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.stock_movements_id_seq')::text, 6, '0');

    insert into public.stock_movements (
      tenant_id,
      movement_no,
      movement_type,
      reference_type,
      reference_id,
      notes,
      created_by_email,
      is_posted,
      posted_at
    ) values (
      v_parent,
      v_mov_no,
      'receive_putaway',
      'global_shipment',
      p_shipment_id::text,
      'Receive put-away audit for shipment ' || p_shipment_id::text,
      public.current_user_email(),
      true,
      now()
    )
    returning id into v_mov_id;

    for v_row in select value from jsonb_array_elements(p_stock_rows)
    loop
      v_qty := coalesce((v_row->>'quantity')::int, 0);
      if v_qty <= 0 then
        continue;
      end if;

      if (v_row->>'shipment_item_id')::bigint is null then
        raise exception 'stock row requires shipment_item_id';
      end if;

      if not exists (
        select 1
        from public.global_shipment_items gsi
        where gsi.id = (v_row->>'shipment_item_id')::bigint
          and gsi.shipment_id = p_shipment_id
      ) then
        raise exception 'stock row shipment_item_id % not on shipment', v_row->>'shipment_item_id';
      end if;

      v_loc := coalesce((v_row->>'location_id')::bigint, public.default_putaway_stock_location_id(v_parent));

      if v_loc is null then
        raise exception 'no put-away location configured';
      end if;

      if not exists (
        select 1
        from public.stock_locations sl
        where sl.id = v_loc
          and sl.parent_tenant_id = v_parent
          and sl.is_active = true
          and public._stock_location_is_leaf(v_loc)
      ) then
        raise exception 'invalid put-away location';
      end if;

      v_avail := coalesce((v_row->>'availability')::public.stock_availability, 'sellable'::public.stock_availability);

      insert into public.global_stocks (
        parent_tenant_id,
        shipment_item_id,
        stock_type_id,
        quantity,
        is_usable,
        availability,
        location_id
      ) values (
        v_parent,
        (v_row->>'shipment_item_id')::bigint,
        (v_row->>'stock_type_id')::bigint,
        v_qty,
        coalesce((v_row->>'is_usable')::boolean, v_avail = 'sellable'::public.stock_availability),
        v_avail,
        v_loc
      )
      on conflict (shipment_item_id, availability, location_id)
      do update set
        quantity = excluded.quantity,
        updated_at = now()
      returning id into v_stock_id;

      insert into public.stock_movement_lines (
        movement_id,
        stock_id,
        quantity,
        to_location_id,
        to_availability
      ) values (
        v_mov_id,
        v_stock_id,
        v_qty,
        v_loc,
        v_avail
      );

      v_stock_count := v_stock_count + 1;
    end loop;

    if v_stock_count = 0 then
      raise exception 'p_stock_rows provided but no quantities to post';
    end if;

    -- Update received_quantity on global_shipment_items per line from p_stock_rows
    update public.global_shipment_items gsi
    set
      received_quantity = coalesce(agg.total_qty, 0),
      updated_at = now()
    from (
      select (r->>'shipment_item_id')::bigint as item_id, sum(coalesce((r->>'quantity')::int, 0)) as total_qty
      from jsonb_array_elements(p_stock_rows) r
      where (r->>'shipment_item_id')::bigint is not null
      group by (r->>'shipment_item_id')::bigint
    ) agg
    where gsi.id = agg.item_id and gsi.shipment_id = p_shipment_id;

    update public.global_shipments
    set
      status = 'received',
      stock_ready = true,
      inventory_added = true,
      updated_at = now()
    where id = p_shipment_id;
  end if;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'items_stamped', v_stamped,
    'stock_rows_posted', v_stock_count,
    'stock_ready', (select stock_ready from public.global_shipments where id = p_shipment_id),
    'wallet_posted', false,
    'movement_id', v_mov_id
  );
end;
$$;

revoke all on function public.finalize_global_shipment(bigint, jsonb) from public;
grant execute on function public.finalize_global_shipment(bigint, jsonb) to authenticated;

commit;

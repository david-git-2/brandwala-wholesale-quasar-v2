-- Phase 10A: finalize put-away (availability + default pickable location)

begin;

create or replace function public.default_pickable_stock_location_id(p_tenant_id bigint)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select sl.id
  from public.stock_locations sl
  where sl.parent_tenant_id = p_tenant_id
    and sl.is_active = true
    and sl.is_pickable = true
  order by sl.id
  limit 1;
$$;

grant execute on function public.default_pickable_stock_location_id(bigint) to authenticated;

-- Backfill existing stock rows
update public.global_stocks gs
set
  availability = coalesce(gs.availability, 'sellable'::public.stock_availability),
  location_id = coalesce(gs.location_id, public.default_pickable_stock_location_id(gs.parent_tenant_id)),
  updated_at = now()
where gs.availability is distinct from 'sellable'::public.stock_availability
   or gs.location_id is null;

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
  v_default_location bigint;
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
  v_default_location := public.default_pickable_stock_location_id(v_parent);

  if p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
    for v_row in select value from jsonb_array_elements(p_stock_rows)
    loop
      if coalesce((v_row->>'quantity')::int, 0) <= 0 then
        continue;
      end if;

      if (v_row->>'shipment_item_id')::bigint is null
         or (v_row->>'stock_type_id')::bigint is null then
        raise exception 'stock row requires shipment_item_id and stock_type_id';
      end if;

      if not exists (
        select 1
        from public.global_shipment_items gsi
        where gsi.id = (v_row->>'shipment_item_id')::bigint
          and gsi.shipment_id = p_shipment_id
      ) then
        raise exception 'stock row shipment_item_id % not on shipment', v_row->>'shipment_item_id';
      end if;

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
        (v_row->>'quantity')::int,
        coalesce((v_row->>'is_usable')::boolean, true),
        'sellable'::public.stock_availability,
        v_default_location
      )
      on conflict (shipment_item_id, stock_type_id, is_usable)
      do update set
        quantity = excluded.quantity,
        availability = excluded.availability,
        location_id = coalesce(excluded.location_id, global_stocks.location_id),
        updated_at = now();

      v_stock_count := v_stock_count + 1;
    end loop;

    if v_stock_count = 0 then
      raise exception 'p_stock_rows provided but no quantities to post';
    end if;

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
    'wallet_posted', false
  );
end;
$$;

revoke all on function public.finalize_global_shipment(bigint, jsonb) from public;
grant execute on function public.finalize_global_shipment(bigint, jsonb) to authenticated;

commit;

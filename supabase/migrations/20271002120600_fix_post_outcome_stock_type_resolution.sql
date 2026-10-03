-- post_shipment_outcome_stock referenced non-existent gsi.stock_type_id

create or replace function public.default_sellable_global_stock_type_id(p_tenant_id bigint)
returns bigint
language sql
stable
security definer
set search_path to public
as $$
  select gst.id
  from public.global_stock_types gst
  where (gst.parent_tenant_id is null or gst.parent_tenant_id = p_tenant_id)
    and gst.is_sellable = true
    and (
      lower(trim(gst.description)) = 'standard sellable'
      or gst.description ilike '%Standard%Sellable%'
      or gst.description ilike 'Standard%'
    )
  order by gst.parent_tenant_id nulls first, gst.sort_order, gst.id
  limit 1;
$$;

grant execute on function public.default_sellable_global_stock_type_id(bigint) to authenticated;
grant execute on function public.default_sellable_global_stock_type_id(bigint) to service_role;

create or replace function public.post_shipment_outcome_stock(
  p_shipment_id bigint,
  p_stock_rows jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path to public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_stamped integer;
  v_stock_count integer := 0;
  v_parent bigint;
  v_loc bigint;
  v_grade_tag bigint;
  v_avail public.stock_availability;
  v_stock_id bigint;
  v_mov_id bigint;
  v_mov_no text;
  v_posted int;
  v_delta int;
  r_out record;
  v_stock_type bigint;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  v_parent := v_ship.parent_tenant_id;

  if not public.user_can_manage_parent_tenant(v_parent) then
    raise exception 'not allowed';
  end if;

  if v_ship.status = 'cancelled' then
    raise exception 'shipment is cancelled';
  end if;

  if coalesce(v_ship.is_closed, false) then
    raise exception 'shipment is closed';
  end if;

  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  if not exists (
    select 1 from public.global_shipment_cost_entries where shipment_id = p_shipment_id
  ) then
    raise exception 'shipment has no cost entries';
  end if;

  v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);
  perform public._stamp_global_shipment_outcome_costs(p_shipment_id);

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
    'Outcome receive put-away for shipment ' || p_shipment_id::text,
    public.current_user_email(),
    true,
    now()
  )
  returning id into v_mov_id;

  for r_out in
    select o.*
    from public.global_shipment_item_outcomes o
    inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
    where gsi.shipment_id = p_shipment_id
      and o.reason <> 'ordered'::public.global_shipment_outcome_reason
    order by o.id
  loop
    if r_out.kind = 'unsellable'::public.global_shipment_outcome_kind then
      continue;
    end if;

    select coalesce(sum(gs.quantity), 0)::int into v_posted
    from public.global_stocks gs where gs.outcome_id = r_out.id;

    v_delta := r_out.quantity - v_posted;
    if v_delta <= 0 then
      continue;
    end if;

    v_loc := null;
    if p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
      select (elem->>'location_id')::bigint into v_loc
      from jsonb_array_elements(p_stock_rows) elem
      where (elem->>'outcome_id')::bigint = r_out.id
      limit 1;
    end if;

    if v_loc is null and p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
      select (elem->>'location_id')::bigint into v_loc
      from jsonb_array_elements(p_stock_rows) elem
      where (elem->>'shipment_item_id')::bigint = r_out.shipment_item_id
      limit 1;
    end if;

    v_loc := coalesce(v_loc, public.default_putaway_stock_location_id(v_parent));

    if v_loc is null then
      raise exception 'no put-away location configured';
    end if;

    if not exists (
      select 1 from public.stock_locations sl
      where sl.id = v_loc and sl.parent_tenant_id = v_parent and sl.is_active = true
        and public._stock_location_is_leaf(v_loc)
    ) then
      raise exception 'invalid put-away location';
    end if;

    v_avail := 'sellable'::public.stock_availability;
    v_grade_tag := public.default_stock_grade_tag_id();

    v_stock_type := null;
    if p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
      select (elem->>'stock_type_id')::bigint into v_stock_type
      from jsonb_array_elements(p_stock_rows) elem
      where (elem->>'outcome_id')::bigint = r_out.id
        and nullif(elem->>'stock_type_id', '') is not null
      limit 1;
    end if;

    if v_stock_type is null and p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
      select (elem->>'stock_type_id')::bigint into v_stock_type
      from jsonb_array_elements(p_stock_rows) elem
      where (elem->>'shipment_item_id')::bigint = r_out.shipment_item_id
        and nullif(elem->>'stock_type_id', '') is not null
      limit 1;
    end if;

    if v_stock_type is null then
      select gs.stock_type_id into v_stock_type
      from public.global_stocks gs
      where gs.shipment_item_id = r_out.shipment_item_id
        and gs.stock_type_id is not null
      order by gs.quantity desc, gs.id
      limit 1;
    end if;

    if v_stock_type is null then
      v_stock_type := public.default_sellable_global_stock_type_id(v_parent);
    end if;

    if v_stock_type is null then
      raise exception 'no sellable stock type configured';
    end if;

    insert into public.global_stocks (
      parent_tenant_id, shipment_item_id, outcome_id, stock_type_id, quantity,
      is_usable, availability, location_id, grade_tag_id
    ) values (
      v_parent, r_out.shipment_item_id, r_out.id, v_stock_type, v_delta,
      true, v_avail, v_loc, v_grade_tag
    )
    on conflict (outcome_id, availability, location_id, grade_tag_id)
    do update set quantity = public.global_stocks.quantity + excluded.quantity, updated_at = now()
    returning id into v_stock_id;

    insert into public.stock_movement_lines (
      movement_id, stock_id, quantity, to_location_id, to_availability
    ) values (v_mov_id, v_stock_id, v_delta, v_loc, v_avail);

    v_stock_count := v_stock_count + 1;
  end loop;

  update public.global_shipment_items gsi
  set received_quantity = coalesce(extra_totals.total_qty, 0), updated_at = now()
  from (
    select o.shipment_item_id as item_id, sum(o.quantity)::int as total_qty
    from public.global_shipment_item_outcomes o
    inner join public.global_shipment_items gsi2 on gsi2.id = o.shipment_item_id
    where gsi2.shipment_id = p_shipment_id
      and o.reason <> 'ordered'::public.global_shipment_outcome_reason
    group by o.shipment_item_id
  ) extra_totals
  where gsi.id = extra_totals.item_id and gsi.shipment_id = p_shipment_id;

  if v_stock_count > 0 then
    update public.global_shipments
    set status = 'received',
        stock_ready = true, inventory_added = true, updated_at = now()
    where id = p_shipment_id;
  end if;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'items_stamped', v_stamped,
    'stock_rows_posted', v_stock_count,
    'stock_ready', (select stock_ready from public.global_shipments where id = p_shipment_id),
    'movement_id', v_mov_id
  );
end;
$$;

grant execute on function public.post_shipment_outcome_stock(bigint, jsonb) to authenticated;

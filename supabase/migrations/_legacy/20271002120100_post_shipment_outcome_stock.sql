-- Outcome-driven receive post + on-hand restamp; stamp extras; finalize uses outcomes.

create or replace function public._stamp_global_shipment_outcome_costs(p_shipment_id bigint)
returns integer
language plpgsql
security definer
set search_path to public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_product_amount numeric := 0;
  v_cargo_amount numeric := 0;
  v_goods_bdt numeric := 0;
  v_cargo_bdt numeric := 0;
  v_blended numeric := 1;
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

  select
    coalesce(sum(amount) filter (where cost_type = 'product'), 0),
    coalesce(sum(amount * exchange_rate) filter (where cost_type = 'product'), 0),
    coalesce(sum(amount) filter (where cost_type != 'product'), 0),
    coalesce(sum(amount * exchange_rate) filter (where cost_type != 'product'), 0)
  into v_product_amount, v_goods_bdt, v_cargo_amount, v_cargo_bdt
  from public.global_shipment_cost_entries
  where shipment_id = p_shipment_id;

  if (v_product_amount + v_cargo_amount) > 0 then
    v_blended := (v_goods_bdt + v_cargo_bdt) / (v_product_amount + v_cargo_amount);
  else
    v_blended := 1;
  end if;

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
    select * into r_line
    from public.global_shipment_items
    where id = r_out.shipment_item_id;

    v_line_gross := (
      (coalesce(r_line.product_weight, 0) + coalesce(r_line.package_weight, 0)) * r_line.ordered_quantity
    ) / 1000.0;

    if v_pack_kg > 0 then
      v_line_cargo_share := (v_line_gross / v_pack_kg) * v_cargo_amount;
    elsif (select coalesce(sum(ordered_quantity), 0) from public.global_shipment_items where shipment_id = p_shipment_id) > 0 then
      v_line_cargo_share := (r_line.ordered_quantity::numeric
        / (select sum(ordered_quantity) from public.global_shipment_items where shipment_id = p_shipment_id)
      ) * v_cargo_amount;
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
$$;

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
  v_row jsonb;
  v_parent bigint;
  v_loc bigint;
  v_grade_tag bigint;
  v_avail public.stock_availability;
  v_stock_id bigint;
  v_mov_id bigint;
  v_mov_no text;
  v_qty int;
  v_posted int;
  v_delta int;
  r_out record;
  v_item_id bigint;
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
    select o.*, gsi.stock_type_id as line_stock_type_id
    from public.global_shipment_item_outcomes o
    inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
    where gsi.shipment_id = p_shipment_id
      and o.reason <> 'ordered'::public.global_shipment_outcome_reason
    order by o.id
  loop
    if r_out.kind = 'unsellable'::public.global_shipment_outcome_kind then
      continue;
    end if;

    select coalesce(sum(gs.quantity), 0)::int
    into v_posted
    from public.global_stocks gs
    where gs.outcome_id = r_out.id;

    v_delta := r_out.quantity - v_posted;
    if v_delta <= 0 then
      continue;
    end if;

    v_loc := null;
    if p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
      select (elem->>'location_id')::bigint
      into v_loc
      from jsonb_array_elements(p_stock_rows) elem
      where (elem->>'outcome_id')::bigint = r_out.id
      limit 1;
    end if;

    if v_loc is null and p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
      select (elem->>'location_id')::bigint
      into v_loc
      from jsonb_array_elements(p_stock_rows) elem
      where (elem->>'shipment_item_id')::bigint = r_out.shipment_item_id
      limit 1;
    end if;

    v_loc := coalesce(v_loc, public.default_putaway_stock_location_id(v_parent));

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

    v_avail := 'sellable'::public.stock_availability;
    v_grade_tag := public.default_stock_grade_tag_id();
    v_stock_type := r_out.line_stock_type_id;

    insert into public.global_stocks (
      parent_tenant_id,
      shipment_item_id,
      outcome_id,
      stock_type_id,
      quantity,
      is_usable,
      availability,
      location_id,
      grade_tag_id
    ) values (
      v_parent,
      r_out.shipment_item_id,
      r_out.id,
      v_stock_type,
      v_delta,
      true,
      v_avail,
      v_loc,
      v_grade_tag
    )
    on conflict (outcome_id, availability, location_id, grade_tag_id)
    do update set
      quantity = public.global_stocks.quantity + excluded.quantity,
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
      v_delta,
      v_loc,
      v_avail
    );

    v_stock_count := v_stock_count + 1;
  end loop;

  update public.global_shipment_items gsi
  set
    received_quantity = coalesce(extra_totals.total_qty, 0),
    updated_at = now()
  from (
    select
      o.shipment_item_id as item_id,
      sum(o.quantity)::int as total_qty
    from public.global_shipment_item_outcomes o
    where o.reason <> 'ordered'::public.global_shipment_outcome_reason
    group by o.shipment_item_id
  ) extra_totals
  where gsi.id = extra_totals.item_id
    and gsi.shipment_id = p_shipment_id;

  if v_stock_count > 0 then
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
    'movement_id', v_mov_id
  );
end;
$$;

create or replace function public.restamp_global_shipment_on_hand(
  p_shipment_id bigint default null,
  p_outcome_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path to public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_parent bigint;
  v_on_hand int;
  r_out record;
  v_updated int := 0;
begin
  if p_outcome_id is not null then
    select gsi.shipment_id into p_shipment_id
    from public.global_shipment_item_outcomes o
    inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
    where o.id = p_outcome_id;
  end if;

  if p_shipment_id is null then
    raise exception 'shipment_id or outcome_id required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  v_parent := v_ship.parent_tenant_id;
  if not public.user_can_manage_parent_tenant(v_parent) then
    raise exception 'not allowed';
  end if;

  if coalesce(v_ship.is_closed, false) then
    raise exception 'shipment is closed';
  end if;

  perform public.stamp_global_shipment_landed_costs(p_shipment_id);
  perform public._stamp_global_shipment_outcome_costs(p_shipment_id);

  for r_out in
    select o.*
    from public.global_shipment_item_outcomes o
    inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
    where gsi.shipment_id = p_shipment_id
      and o.reason <> 'ordered'::public.global_shipment_outcome_reason
      and (p_outcome_id is null or o.id = p_outcome_id)
  loop
    select coalesce(sum(gs.quantity), 0)::int
    into v_on_hand
    from public.global_stocks gs
    where gs.outcome_id = r_out.id;

    if v_on_hand > r_out.quantity then
      raise exception 'outcome qty % below on-hand % for outcome %', r_out.quantity, v_on_hand, r_out.id;
    end if;

    v_updated := v_updated + 1;
  end loop;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'outcomes_checked', v_updated
  );
end;
$$;

grant execute on function public.post_shipment_outcome_stock(bigint, jsonb) to authenticated;
grant execute on function public.restamp_global_shipment_on_hand(bigint, bigint) to authenticated;
grant execute on function public._stamp_global_shipment_outcome_costs(bigint) to authenticated;

-- finalize delegates to outcome post (legacy p_stock_rows maps shipment_item_id → location)
create or replace function public.finalize_global_shipment(p_shipment_id bigint, p_stock_rows jsonb default null)
returns jsonb
language plpgsql
security definer
set search_path to public
as $$
begin
  return public.post_shipment_outcome_stock(p_shipment_id, p_stock_rows);
end;
$$;

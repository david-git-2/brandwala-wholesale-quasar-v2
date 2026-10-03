-- Vendor discount: price-only (Case C) or peel to new vendor_discount outcome (Case E)

create or replace function public.apply_shipment_outcome_vendor_discount(
  p_shipment_id bigint,
  p_source_outcome_id bigint,
  p_quantity integer,
  p_new_purchase_price numeric
) returns jsonb
language plpgsql
security definer
set search_path to public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_src public.global_shipment_item_outcomes%rowtype;
  v_parent bigint;
  v_on_hand int;
  v_new_outcome_id bigint;
  v_mov_id bigint;
  v_mov_no text;
  v_remaining int;
  v_take int;
  r_stock record;
  v_target_stock_id bigint;
begin
  if p_quantity is null or p_quantity < 1 then
    raise exception 'quantity must be at least 1';
  end if;

  if p_new_purchase_price is null or p_new_purchase_price < 0 then
    raise exception 'purchase price must be >= 0';
  end if;

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

  select o.* into v_src
  from public.global_shipment_item_outcomes o
  inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
  where o.id = p_source_outcome_id
    and gsi.shipment_id = p_shipment_id
  for update of o;

  if not found then
    raise exception 'outcome not found on shipment';
  end if;

  if v_src.reason = 'ordered'::public.global_shipment_outcome_reason then
    raise exception 'cannot discount ordered row';
  end if;

  if v_src.kind <> 'sellable'::public.global_shipment_outcome_kind then
    raise exception 'outcome must be sellable';
  end if;

  select coalesce(sum(gs.quantity), 0)::int into v_on_hand
  from public.global_stocks gs
  where gs.outcome_id = v_src.id;

  if p_quantity > v_on_hand then
    raise exception 'quantity % exceeds on-hand % for outcome %', p_quantity, v_on_hand, v_src.id;
  end if;

  if p_quantity = v_src.quantity and v_on_hand = v_src.quantity then
    update public.global_shipment_item_outcomes
    set
      purchase_price = p_new_purchase_price,
      reason = case
        when reason = 'general'::public.global_shipment_outcome_reason
          then 'vendor_discount'::public.global_shipment_outcome_reason
        else reason
      end,
      updated_at = now()
    where id = v_src.id;

    perform public._stamp_global_shipment_outcome_costs(p_shipment_id);
    perform public.restamp_global_shipment_on_hand(p_shipment_id, v_src.id);

    return jsonb_build_object(
      'mode', 'price_only',
      'shipment_id', p_shipment_id,
      'outcome_id', v_src.id,
      'quantity', p_quantity,
      'new_purchase_price', p_new_purchase_price
    );
  end if;

  if v_src.quantity - p_quantity < 0 then
    raise exception 'cannot peel % from outcome qty %', p_quantity, v_src.quantity;
  end if;

  if (v_src.quantity - p_quantity) < (v_on_hand - p_quantity) then
    raise exception 'outcome qty would fall below on-hand after peel';
  end if;

  v_mov_no := 'VD-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.stock_movements_id_seq')::text, 6, '0');

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
    'adjustment'::public.stock_movement_type,
    'global_shipment',
    p_shipment_id::text,
    'Vendor discount peel outcome ' || v_src.id::text,
    public.current_user_email(),
    true,
    now()
  )
  returning id into v_mov_id;

  update public.global_shipment_item_outcomes
  set quantity = quantity - p_quantity, updated_at = now()
  where id = v_src.id;

  insert into public.global_shipment_item_outcomes (
    parent_tenant_id,
    shipment_item_id,
    quantity,
    kind,
    reason,
    purchase_price
  ) values (
    v_src.parent_tenant_id,
    v_src.shipment_item_id,
    p_quantity,
    'sellable'::public.global_shipment_outcome_kind,
    'vendor_discount'::public.global_shipment_outcome_reason,
    p_new_purchase_price
  )
  returning id into v_new_outcome_id;

  v_remaining := p_quantity;

  for r_stock in
    select gs.*
    from public.global_stocks gs
    where gs.outcome_id = v_src.id
      and gs.quantity > 0
    order by gs.location_id nulls last, gs.id
    for update
  loop
    exit when v_remaining <= 0;
    v_take := least(v_remaining, r_stock.quantity);

    update public.global_stocks
    set quantity = quantity - v_take, updated_at = now()
    where id = r_stock.id;

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
      r_stock.parent_tenant_id,
      r_stock.shipment_item_id,
      v_new_outcome_id,
      r_stock.stock_type_id,
      v_take,
      r_stock.is_usable,
      r_stock.availability,
      r_stock.location_id,
      r_stock.grade_tag_id
    )
    on conflict (outcome_id, availability, location_id, grade_tag_id)
    do update set
      quantity = public.global_stocks.quantity + excluded.quantity,
      updated_at = now()
    returning id into v_target_stock_id;

    insert into public.stock_movement_lines (
      movement_id,
      stock_id,
      from_location_id,
      to_location_id,
      from_availability,
      to_availability,
      from_grade_tag_id,
      to_grade_tag_id,
      quantity
    ) values (
      v_mov_id,
      r_stock.id,
      r_stock.location_id,
      r_stock.location_id,
      r_stock.availability,
      r_stock.availability,
      r_stock.grade_tag_id,
      r_stock.grade_tag_id,
      v_take
    );

    v_remaining := v_remaining - v_take;
  end loop;

  if v_remaining > 0 then
    raise exception 'could not move % units from stock lots', p_quantity;
  end if;

  perform public._stamp_global_shipment_outcome_costs(p_shipment_id);
  perform public.restamp_global_shipment_on_hand(p_shipment_id, v_src.id);
  perform public.restamp_global_shipment_on_hand(p_shipment_id, v_new_outcome_id);

  return jsonb_build_object(
    'mode', 'peel',
    'shipment_id', p_shipment_id,
    'source_outcome_id', v_src.id,
    'new_outcome_id', v_new_outcome_id,
    'quantity', p_quantity,
    'new_purchase_price', p_new_purchase_price,
    'movement_id', v_mov_id
  );
end;
$$;

grant execute on function public.apply_shipment_outcome_vendor_discount(bigint, bigint, integer, numeric) to authenticated;

-- Phase 3: finalize (stamp + optional stock post, no wallet) + cost revision

begin;

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
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  v_parent := v_ship.parent_tenant_id;

  if not public.user_can_manage_parent_tenant(v_parent) then
    raise exception 'not allowed';
  end if;

  if v_ship.stock_ready = true or v_ship.status = 'Ready Stock' then
    raise exception 'shipment already finalized; use revise_global_shipment_costs';
  end if;

  if not exists (
    select 1 from public.global_shipment_items where shipment_id = p_shipment_id
  ) then
    raise exception 'shipment has no items';
  end if;

  -- Ensure day-one entries exist (header rates during dual period)
  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  if not exists (
    select 1 from public.global_shipment_cost_entries where shipment_id = p_shipment_id
  ) then
    raise exception 'shipment has no cost entries';
  end if;

  -- Authoritative stamp (wallet stub-skip — no ledger posts)
  v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);

  -- Optional stock post (same shape as ReceiveShipmentDialog client upsert)
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
        is_usable
      ) values (
        v_parent,
        (v_row->>'shipment_item_id')::bigint,
        (v_row->>'stock_type_id')::bigint,
        (v_row->>'quantity')::int,
        coalesce((v_row->>'is_usable')::boolean, true)
      )
      on conflict (shipment_item_id, stock_type_id, is_usable)
      do update set
        quantity = excluded.quantity,
        updated_at = now();

      v_stock_count := v_stock_count + 1;
    end loop;

    if v_stock_count = 0 then
      raise exception 'p_stock_rows provided but no quantities to post';
    end if;

    update public.global_shipments
    set
      status = 'Ready Stock',
      stock_ready = true,
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

-- ---------------------------------------------------------------------------

create or replace function public.revise_global_shipment_costs(
  p_shipment_id bigint,
  p_entries jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_entry jsonb;
  v_stamped integer;
  v_old_costs jsonb;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if not (v_ship.stock_ready = true or v_ship.status = 'Ready Stock') then
    raise exception 'shipment not finalized; use upsert_global_shipment_cost_entry';
  end if;

  if p_entries is null or jsonb_typeof(p_entries) <> 'array' or jsonb_array_length(p_entries) = 0 then
    raise exception 'p_entries must be a non-empty array';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', e.id,
    'cost_type', e.cost_type,
    'amount', e.amount,
    'exchange_rate', e.exchange_rate,
    'landed_snapshot', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'item_id', i.id,
        'landed_cost_bdt', i.landed_cost_bdt
      )), '[]'::jsonb)
      from public.global_shipment_items i
      where i.shipment_id = p_shipment_id
    )
  )), '[]'::jsonb)
  into v_old_costs
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id;

  -- Replace all entries for this shipment with the provided set
  delete from public.global_shipment_cost_entries where shipment_id = p_shipment_id;

  for v_entry in select value from jsonb_array_elements(p_entries)
  loop
    insert into public.global_shipment_cost_entries (
      parent_tenant_id,
      shipment_id,
      cost_type,
      amount,
      currency_id,
      exchange_rate,
      payment_source,
      entity_type,
      entity_id,
      allocation,
      metadata
    ) values (
      v_ship.parent_tenant_id,
      p_shipment_id,
      (v_entry->>'cost_type')::public.global_shipment_cost_type,
      (v_entry->>'amount')::numeric,
      nullif(v_entry->>'currency_id', '')::bigint,
      coalesce(nullif(v_entry->>'exchange_rate', '')::numeric, 1.0),
      nullif(v_entry->>'payment_source', ''),
      nullif(v_entry->>'entity_type', ''),
      nullif(v_entry->>'entity_id', '')::bigint,
      nullif(v_entry->>'allocation', ''),
      coalesce(v_entry->'metadata', '{}'::jsonb)
    );
  end loop;

  -- Re-stamp only — no wallet delta, no invoice line rewrite
  v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'items_stamped', v_stamped,
    'prior_entries', v_old_costs,
    'wallet_posted', false
  );
end;
$$;

revoke all on function public.revise_global_shipment_costs(bigint, jsonb) from public;
grant execute on function public.revise_global_shipment_costs(bigint, jsonb) to authenticated;

commit;

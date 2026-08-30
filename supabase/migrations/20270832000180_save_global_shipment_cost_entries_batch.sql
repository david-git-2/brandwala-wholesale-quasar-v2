-- Batch save cost entries + optional header weight in one transaction; single landed-cost stamp.

CREATE OR REPLACE FUNCTION public._restamp_global_shipment_on_weight_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
begin
  if coalesce(current_setting('app.skip_shipment_landed_restamp', true), '') = '1' then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and not public.global_shipment_costs_are_locked(new)
     and (
       new.received_weight is distinct from old.received_weight
       or new.total_weight_kg is distinct from old.total_weight_kg
     )
     and exists (select 1 from public.global_shipment_items where shipment_id = new.id) then
    perform public.stamp_global_shipment_landed_costs(new.id);
  end if;

  return new;
end;
$$;

CREATE OR REPLACE FUNCTION public.save_global_shipment_cost_entries(
  p_shipment_id bigint,
  p_entries jsonb,
  p_delete_ids bigint[] DEFAULT '{}'::bigint[],
  p_received_weight numeric DEFAULT NULL,
  p_total_weight_kg numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_entry jsonb;
  v_row public.global_shipment_cost_entries%rowtype;
  v_id bigint;
  v_amount numeric;
  v_rate numeric;
  v_stamped integer := 0;
  v_cost_entries jsonb;
  v_items jsonb;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are locked';
  end if;

  perform set_config('app.skip_shipment_landed_restamp', '1', true);

  if p_received_weight is not null or p_total_weight_kg is not null then
    update public.global_shipments
    set
      received_weight = coalesce(p_received_weight, received_weight),
      total_weight_kg = coalesce(p_total_weight_kg, total_weight_kg),
      updated_at = now()
    where id = p_shipment_id
    returning * into v_ship;
  end if;

  if p_delete_ids is not null and cardinality(p_delete_ids) > 0 then
    delete from public.global_shipment_cost_entries e
    where e.shipment_id = p_shipment_id
      and e.id = any(p_delete_ids);
  end if;

  if p_entries is not null and jsonb_typeof(p_entries) = 'array' then
    for v_entry in select value from jsonb_array_elements(p_entries)
    loop
      v_amount := nullif(v_entry->>'amount', '')::numeric;
      v_rate := coalesce(nullif(v_entry->>'exchange_rate', '')::numeric, 1.0);
      v_id := nullif(v_entry->>'id', '')::bigint;

      if v_amount is null or v_amount < 0 then
        raise exception 'amount must be >= 0';
      end if;

      if v_rate is null or v_rate <= 0 then
        raise exception 'exchange_rate must be > 0';
      end if;

      if v_id is not null then
        update public.global_shipment_cost_entries e
        set
          cost_type = (v_entry->>'cost_type')::public.global_shipment_cost_type,
          amount = v_amount,
          exchange_rate = v_rate,
          currency_id = nullif(v_entry->>'currency_id', '')::bigint,
          payment_source = nullif(v_entry->>'payment_source', ''),
          entity_type = nullif(v_entry->>'entity_type', ''),
          entity_id = nullif(v_entry->>'entity_id', '')::bigint,
          allocation = nullif(v_entry->>'allocation', ''),
          metadata = coalesce(v_entry->'metadata', '{}'::jsonb),
          updated_at = now()
        where e.id = v_id
          and e.shipment_id = p_shipment_id
        returning * into v_row;

        if not found then
          raise exception 'cost entry % not found on shipment %', v_id, p_shipment_id;
        end if;
      else
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
          v_amount,
          nullif(v_entry->>'currency_id', '')::bigint,
          v_rate,
          nullif(v_entry->>'payment_source', ''),
          nullif(v_entry->>'entity_type', ''),
          nullif(v_entry->>'entity_id', '')::bigint,
          nullif(v_entry->>'allocation', ''),
          coalesce(v_entry->'metadata', '{}'::jsonb)
        )
        returning * into v_row;
      end if;
    end loop;
  end if;

  perform set_config('app.skip_shipment_landed_restamp', '0', true);

  if exists (select 1 from public.global_shipment_items where shipment_id = p_shipment_id) then
    v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);
  end if;

  select coalesce(jsonb_agg(to_jsonb(e) order by e.id), '[]'::jsonb)
  into v_cost_entries
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id;

  select coalesce(jsonb_agg(to_jsonb(i) order by i.sort_order, i.id), '[]'::jsonb)
  into v_items
  from public.global_shipment_items i
  where i.shipment_id = p_shipment_id;

  return jsonb_build_object(
    'cost_entries', v_cost_entries,
    'items', v_items,
    'items_stamped', v_stamped,
    'shipment', jsonb_build_object(
      'id', v_ship.id,
      'received_weight', v_ship.received_weight,
      'total_weight_kg', v_ship.total_weight_kg,
      'updated_at', v_ship.updated_at
    )
  );
end;
$$;

REVOKE ALL ON FUNCTION public.save_global_shipment_cost_entries(
  bigint, jsonb, bigint[], numeric, numeric
) FROM PUBLIC;
GRANT ALL ON FUNCTION public.save_global_shipment_cost_entries(
  bigint, jsonb, bigint[], numeric, numeric
) TO authenticated;

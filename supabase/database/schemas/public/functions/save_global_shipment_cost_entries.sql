CREATE FUNCTION public.save_global_shipment_cost_entries (
  p_shipment_id     bigint,
  p_entries         jsonb,
  p_delete_ids      bigint[] DEFAULT '{}'::bigint[],
  p_received_weight numeric  DEFAULT NULL::numeric,
  p_total_weight_kg numeric  DEFAULT NULL::numeric
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_entry jsonb;
  v_row public.global_shipment_cost_entries%rowtype;
  v_id bigint;
  v_amount numeric;
  v_stamped integer := 0;
  v_cost_entries jsonb;
  v_items jsonb;
  v_cost_bucket public.global_shipment_cost_bucket;
  v_cost_component public.global_shipment_cost_component;
  v_is_capitalizable boolean;
  v_description text;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
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
      v_id := nullif(v_entry->>'id', '')::bigint;

      if v_amount is null or v_amount < 0 then
        raise exception 'amount must be >= 0';
      end if;

      v_cost_bucket := nullif(v_entry->>'cost_bucket', '')::public.global_shipment_cost_bucket;
      v_cost_component := nullif(v_entry->>'cost_component', '')::public.global_shipment_cost_component;
      if v_cost_bucket is null or v_cost_component is null then
        raise exception 'cost_bucket and cost_component are required';
      end if;

      v_is_capitalizable := case
        when v_entry ? 'is_capitalizable' then (v_entry->>'is_capitalizable')::boolean
        else null
      end;
      v_description := nullif(trim(v_entry->>'description'), '');

      if v_id is not null then
        update public.global_shipment_cost_entries e
        set
          cost_bucket = v_cost_bucket,
          cost_component = v_cost_component,
          is_capitalizable = coalesce(v_is_capitalizable, e.is_capitalizable),
          description = coalesce(v_description, e.description),
          amount = v_amount,
          currency_id = nullif(v_entry->>'currency_id', '')::bigint,
          metadata = coalesce(v_entry->'metadata', '{}'::jsonb),
          section_id = nullif(v_entry->>'section_id', '')::bigint,
          updated_at = now()
        where e.id = v_id
          and e.shipment_id = p_shipment_id
        returning * into v_row;

        if not found then
          raise exception 'cost entry % not found on shipment %', v_id, p_shipment_id;
        end if;
      else
        insert into public.global_shipment_cost_entries (
          tenant_id,
          shipment_id,
          cost_bucket,
          cost_component,
          is_capitalizable,
          description,
          amount,
          currency_id,
          metadata,
          section_id
        ) values (
          v_ship.tenant_id,
          p_shipment_id,
          v_cost_bucket,
          v_cost_component,
          coalesce(v_is_capitalizable, true),
          v_description,
          v_amount,
          nullif(v_entry->>'currency_id', '')::bigint,
          coalesce(v_entry->'metadata', '{}'::jsonb),
          nullif(v_entry->>'section_id', '')::bigint
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
$function$;

GRANT ALL ON FUNCTION public.save_global_shipment_cost_entries(bigint, jsonb, bigint[], numeric, numeric) TO anon;

GRANT ALL ON FUNCTION public.save_global_shipment_cost_entries(bigint, jsonb, bigint[], numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.save_global_shipment_cost_entries(bigint, jsonb, bigint[], numeric, numeric) TO service_role;
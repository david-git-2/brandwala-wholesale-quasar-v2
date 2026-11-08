CREATE FUNCTION public.revise_global_shipment_costs (
  p_shipment_id bigint,
  p_entries     jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if not public.global_shipment_stock_is_posted(v_ship) then
    raise exception 'shipment not finalized; use upsert_global_shipment_cost_entry';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are locked';
  end if;

  if p_entries is null or jsonb_typeof(p_entries) <> 'array' or jsonb_array_length(p_entries) = 0 then
    raise exception 'p_entries must be a non-empty array';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', e.id,
    'cost_bucket', e.cost_bucket,
    'cost_component', e.cost_component,
    'amount', e.amount,
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
      tenant_id,
      shipment_id,
      cost_bucket,
      cost_component,
      is_capitalizable,
      amount,
      currency_id,
      metadata
    ) values (
      v_ship.tenant_id,
      p_shipment_id,
      (v_entry->>'cost_bucket')::public.global_shipment_cost_bucket,
      (v_entry->>'cost_component')::public.global_shipment_cost_component,
      coalesce((v_entry->>'is_capitalizable')::boolean, true),
      (v_entry->>'amount')::numeric,
      nullif(v_entry->>'currency_id', '')::bigint,
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
$function$;

GRANT ALL ON FUNCTION public.revise_global_shipment_costs(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.revise_global_shipment_costs(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.revise_global_shipment_costs(bigint, jsonb) TO service_role;
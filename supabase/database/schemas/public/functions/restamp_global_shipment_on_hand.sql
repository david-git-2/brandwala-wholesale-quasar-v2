CREATE FUNCTION public.restamp_global_shipment_on_hand (
  p_shipment_id bigint DEFAULT NULL::bigint,
  p_outcome_id  bigint DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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

  v_parent := v_ship.tenant_id;
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
$function$;

GRANT ALL ON FUNCTION public.restamp_global_shipment_on_hand(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.restamp_global_shipment_on_hand(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.restamp_global_shipment_on_hand(bigint, bigint) TO service_role;
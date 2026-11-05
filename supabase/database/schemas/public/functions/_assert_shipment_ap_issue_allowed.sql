CREATE FUNCTION public._assert_shipment_ap_issue_allowed (
  p_shipment_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if v_ship.status not in ('in_transit', 'received') then
    raise exception 'Shipment % must be in transit or received before issuing AP bills', p_shipment_id;
  end if;

  if not coalesce(v_ship.costs_locked, false) then
    raise exception 'Shipment % costs are not locked; use Lock costs on the shipment first', p_shipment_id;
  end if;

  if current_setting('app.shipment_ap_issue', true) is distinct from '1'
     and coalesce(auth.role(), '') is distinct from 'service_role' then
    raise exception 'Issue shipment AP only via lock_global_shipment_costs on the shipment';
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public._assert_shipment_ap_issue_allowed(bigint) TO anon;

GRANT ALL ON FUNCTION public._assert_shipment_ap_issue_allowed(bigint) TO authenticated;

GRANT ALL ON FUNCTION public._assert_shipment_ap_issue_allowed(bigint) TO service_role;
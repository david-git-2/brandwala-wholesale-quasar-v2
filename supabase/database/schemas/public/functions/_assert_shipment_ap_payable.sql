CREATE FUNCTION public._assert_shipment_ap_payable (
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

  if v_ship.status in ('draft', 'cancelled') then
    raise exception 'Shipment % must be in transit or received before AP payout', p_shipment_id;
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public._assert_shipment_ap_payable(bigint) TO anon;

GRANT ALL ON FUNCTION public._assert_shipment_ap_payable(bigint) TO authenticated;

GRANT ALL ON FUNCTION public._assert_shipment_ap_payable(bigint) TO service_role;
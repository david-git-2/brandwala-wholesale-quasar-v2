CREATE FUNCTION public._shipment_money_advisory_lock (
  p_shipment_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;
  perform pg_advisory_xact_lock(hashtext('shipment_money:' || p_shipment_id::text));
end;
$function$;

GRANT ALL ON FUNCTION public._shipment_money_advisory_lock(bigint) TO anon;

GRANT ALL ON FUNCTION public._shipment_money_advisory_lock(bigint) TO authenticated;

GRANT ALL ON FUNCTION public._shipment_money_advisory_lock(bigint) TO service_role;
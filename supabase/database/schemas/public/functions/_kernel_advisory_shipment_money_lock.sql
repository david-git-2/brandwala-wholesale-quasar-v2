CREATE FUNCTION public._kernel_advisory_shipment_money_lock (
  p_shipment_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  AS $function$
begin
  if p_shipment_id is not null then
    perform pg_advisory_xact_lock(hashtext('shipment_money:' || p_shipment_id::text));
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_advisory_shipment_money_lock(bigint) TO anon;

GRANT ALL ON FUNCTION public._kernel_advisory_shipment_money_lock(bigint) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_advisory_shipment_money_lock(bigint) TO service_role;
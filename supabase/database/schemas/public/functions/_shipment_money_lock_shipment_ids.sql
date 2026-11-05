CREATE FUNCTION public._shipment_money_lock_shipment_ids (
  p_shipment_ids bigint[]
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_id bigint;
begin
  if p_shipment_ids is null or coalesce(array_length(p_shipment_ids, 1), 0) = 0 then
    return;
  end if;
  for v_id in
    select distinct x.id
    from unnest(p_shipment_ids) as x(id)
    where x.id is not null
    order by x.id asc
  loop
    perform public._shipment_money_advisory_lock(v_id);
  end loop;
end;
$function$;

GRANT ALL ON FUNCTION public._shipment_money_lock_shipment_ids(bigint[]) TO anon;

GRANT ALL ON FUNCTION public._shipment_money_lock_shipment_ids(bigint[]) TO authenticated;

GRANT ALL ON FUNCTION public._shipment_money_lock_shipment_ids(bigint[]) TO service_role;
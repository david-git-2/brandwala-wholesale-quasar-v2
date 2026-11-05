CREATE FUNCTION public.delete_shipment_order (
  p_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_shipment_id bigint;
begin
  select shipment_id into v_shipment_id
  from public.shipment_orders
  where id = p_id;

  if v_shipment_id is null then
    raise exception 'shipment_order not found';
  end if;

  if not public.can_manage_shipment_by_id(v_shipment_id) then
    raise exception 'not allowed';
  end if;

  delete from public.shipment_orders where id = p_id;
end;
$function$;

GRANT ALL ON FUNCTION public.delete_shipment_order(bigint) TO anon;

GRANT ALL ON FUNCTION public.delete_shipment_order(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delete_shipment_order(bigint) TO service_role;
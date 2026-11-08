CREATE FUNCTION public.archive_shipment (
  p_id bigint
)
  RETURNS public.global_shipments
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  update public.global_shipments
  set is_archived = true,
      archived_at = now(),
      updated_at = now()
  where id = p_id
  returning * into v_ship;

  perform public._set_global_stocks_archived_for_shipment(p_id, true);

  return v_ship;
end;
$function$;

GRANT ALL ON FUNCTION public.archive_shipment(bigint) TO anon;

GRANT ALL ON FUNCTION public.archive_shipment(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.archive_shipment(bigint) TO service_role;
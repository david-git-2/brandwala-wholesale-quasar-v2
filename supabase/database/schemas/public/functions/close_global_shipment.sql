CREATE FUNCTION public.close_global_shipment (
  p_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if v_ship.id is null then
    return jsonb_build_object('success', false, 'error', 'shipment not found');
  end if;
  if not public.is_tenant_staff(v_ship.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;
  if coalesce(v_ship.is_closed, false) then
    return jsonb_build_object('success', true, 'message', 'already closed');
  end if;
  update public.global_shipments
  set is_closed = true, updated_at = now()
  where id = p_shipment_id;
  return jsonb_build_object('success', true, 'is_closed', true);
end;
$function$;

GRANT ALL ON FUNCTION public.close_global_shipment(bigint) TO anon;

GRANT ALL ON FUNCTION public.close_global_shipment(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.close_global_shipment(bigint) TO service_role;
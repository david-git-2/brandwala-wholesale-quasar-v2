CREATE FUNCTION public.revoke_shipment_tracking_token (
  p_shipment_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.has_active_tenant_membership(v_ship.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  update public.global_shipments
  set public_tracking_token = null, updated_at = now()
  where id = p_shipment_id;
end;
$function$;

GRANT ALL ON FUNCTION public.revoke_shipment_tracking_token(bigint) TO anon;

GRANT ALL ON FUNCTION public.revoke_shipment_tracking_token(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.revoke_shipment_tracking_token(bigint) TO service_role;
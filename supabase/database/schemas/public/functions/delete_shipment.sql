CREATE FUNCTION public.delete_shipment (
  p_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.shipments
  where id = p_id;

  if v_tenant_id is null then
    raise exception 'shipment not found';
  end if;

  if not public.can_manage_shipment(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  delete from public.shipments where id = p_id;
end;
$function$;

GRANT ALL ON FUNCTION public.delete_shipment(bigint) TO anon;

GRANT ALL ON FUNCTION public.delete_shipment(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delete_shipment(bigint) TO service_role;
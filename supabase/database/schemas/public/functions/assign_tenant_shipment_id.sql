CREATE FUNCTION public.assign_tenant_shipment_id()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if new.tenant_id is null then
    raise exception 'tenant_id is required for shipments';
  end if;

  if tg_op = 'UPDATE' and new.tenant_id <> old.tenant_id then
    raise exception 'changing shipment tenant_id is not allowed';
  end if;

  if new.tenant_shipment_id is null then
    new.tenant_shipment_id := public.next_tenant_scoped_counter(new.tenant_id, 'shipment');
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.assign_tenant_shipment_id() TO anon;

GRANT ALL ON FUNCTION public.assign_tenant_shipment_id() TO authenticated;

GRANT ALL ON FUNCTION public.assign_tenant_shipment_id() TO service_role;
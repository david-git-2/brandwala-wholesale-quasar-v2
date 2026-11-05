CREATE FUNCTION public.create_shipment (
  p_name          text,
  p_tenant_id     bigint,
  p_shipment_type text   DEFAULT 'international'::text
)
  RETURNS public.shipments
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.shipments;
  v_type text;
begin
  if not public.can_manage_shipment(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_type := lower(trim(coalesce(p_shipment_type, 'international')));
  if v_type not in ('local', 'international') then
    raise exception 'invalid shipment_type: %', p_shipment_type;
  end if;

  insert into public.shipments (name, tenant_id, shipment_type)
  values (trim(p_name), p_tenant_id, v_type)
  returning * into v_row;

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.create_shipment(text, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.create_shipment(text, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.create_shipment(text, bigint, text) TO service_role;
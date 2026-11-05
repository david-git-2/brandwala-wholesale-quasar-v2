CREATE FUNCTION public.can_manage_shipment_by_id (
  p_shipment_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.shipments s
    where s.id = p_shipment_id
      and public.can_manage_shipment(s.tenant_id)
  )
$function$;

GRANT ALL ON FUNCTION public.can_manage_shipment_by_id(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_manage_shipment_by_id(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_manage_shipment_by_id(bigint) TO service_role;
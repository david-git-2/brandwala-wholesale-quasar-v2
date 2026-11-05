CREATE FUNCTION public.refresh_global_shipment_fx_from_ap_payments (
  p_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_fx jsonb;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  if not exists (select 1 from public.global_shipments gs where gs.id = p_shipment_id) then
    raise exception 'shipment not found';
  end if;

  v_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  return v_fx;
end;
$function$;

GRANT ALL ON FUNCTION public.refresh_global_shipment_fx_from_ap_payments(bigint) TO anon;

GRANT ALL ON FUNCTION public.refresh_global_shipment_fx_from_ap_payments(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.refresh_global_shipment_fx_from_ap_payments(bigint) TO service_role;
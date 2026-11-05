CREATE FUNCTION public.set_default_shipment_progress_flow (
  p_flow_id bigint
)
  RETURNS public.shipment_progress_flows
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_flow public.shipment_progress_flows;
begin
  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id
  for update;

  if not found then
    raise exception 'flow not found';
  end if;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  update public.shipment_progress_flows
  set is_default = false
  where tenant_id = v_flow.tenant_id;

  update public.shipment_progress_flows
  set is_default = true, is_active = true
  where id = p_flow_id
  returning * into v_flow;

  return v_flow;
end;
$function$;

GRANT ALL ON FUNCTION public.set_default_shipment_progress_flow(bigint) TO anon;

GRANT ALL ON FUNCTION public.set_default_shipment_progress_flow(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.set_default_shipment_progress_flow(bigint) TO service_role;
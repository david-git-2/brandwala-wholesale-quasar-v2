CREATE FUNCTION public.archive_shipment_progress_flow (
  p_flow_id bigint,
  p_archive boolean DEFAULT true
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

  if p_archive = true and exists (
    select 1 from public.global_shipments gs
    where gs.progress_flow_id = p_flow_id
  ) then
    raise exception 'flow is in use by one or more shipments and cannot be archived';
  end if;

  update public.shipment_progress_flows
  set
    is_active = not p_archive,
    is_default = case when p_archive then false else is_default end
  where id = p_flow_id
  returning * into v_flow;

  return v_flow;
end;
$function$;

GRANT ALL ON FUNCTION public.archive_shipment_progress_flow(bigint, boolean) TO anon;

GRANT ALL ON FUNCTION public.archive_shipment_progress_flow(bigint, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.archive_shipment_progress_flow(bigint, boolean) TO service_role;
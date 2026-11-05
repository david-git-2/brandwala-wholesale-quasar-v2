CREATE FUNCTION public.update_shipment_progress_flow (
  p_flow_id bigint,
  p_name    text   DEFAULT NULL::text
)
  RETURNS public.shipment_progress_flows
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_flow public.shipment_progress_flows;
  v_slug text;
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

  if p_name is null or trim(p_name) = '' then
    return v_flow;
  end if;

  v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));

  update public.shipment_progress_flows
  set
    name = trim(p_name),
    slug = v_slug
  where id = p_flow_id
  returning * into v_flow;

  return v_flow;
end;
$function$;

GRANT ALL ON FUNCTION public.update_shipment_progress_flow(bigint, text) TO anon;

GRANT ALL ON FUNCTION public.update_shipment_progress_flow(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.update_shipment_progress_flow(bigint, text) TO service_role;
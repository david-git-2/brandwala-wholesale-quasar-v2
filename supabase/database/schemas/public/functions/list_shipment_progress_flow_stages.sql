CREATE FUNCTION public.list_shipment_progress_flow_stages (
  p_flow_id          bigint,
  p_include_archived boolean DEFAULT true
)
  RETURNS TABLE (
    flow_stage_id bigint,
    flow_id       bigint,
    tag_id        bigint,
    sort_order    integer,
    name          text,
    slug          text,
    color         text,
    is_active     boolean
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_flow public.shipment_progress_flows;
begin
  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id;

  if not found then
    raise exception 'flow not found';
  end if;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  return query
  select
    s.id as flow_stage_id,
    s.flow_id,
    t.id as tag_id,
    s.sort_order,
    t.name,
    t.slug,
    t.color,
    t.is_active
  from public.shipment_progress_flow_stages s
  join public.tags t on t.id = s.tag_id
  where s.flow_id = p_flow_id
    and (p_include_archived or t.is_active = true)
  order by s.sort_order asc, t.name asc;
end;
$function$;

GRANT ALL ON FUNCTION public.list_shipment_progress_flow_stages(bigint, boolean) TO anon;

GRANT ALL ON FUNCTION public.list_shipment_progress_flow_stages(bigint, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.list_shipment_progress_flow_stages(bigint, boolean) TO service_role;
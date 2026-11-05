CREATE FUNCTION public.archive_shipment_progress_flow_stage (
  p_flow_stage_id bigint,
  p_archive       boolean DEFAULT true
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
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_stage public.shipment_progress_flow_stages;
  v_flow public.shipment_progress_flows;
  v_tag public.tags;
begin
  select * into v_stage
  from public.shipment_progress_flow_stages
  where id = p_flow_stage_id
  for update;

  if not found then
    raise exception 'flow stage not found';
  end if;

  select * into v_flow
  from public.shipment_progress_flows
  where id = v_stage.flow_id;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_archive = true and exists (
    select 1
    from public.global_shipments gs
    where gs.progress_tag_id = v_stage.tag_id
  ) then
    raise exception 'stage is in use by one or more shipments and cannot be archived';
  end if;

  update public.tags
  set is_active = not p_archive
  where id = v_stage.tag_id
  returning * into v_tag;

  return query
  select
    v_stage.id,
    v_stage.flow_id,
    v_stage.tag_id,
    v_stage.sort_order,
    v_tag.name,
    v_tag.slug,
    v_tag.color,
    v_tag.is_active;
end;
$function$;

GRANT ALL ON FUNCTION public.archive_shipment_progress_flow_stage(bigint, boolean) TO anon;

GRANT ALL ON FUNCTION public.archive_shipment_progress_flow_stage(bigint, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.archive_shipment_progress_flow_stage(bigint, boolean) TO service_role;
CREATE FUNCTION public.update_shipment_progress_flow_stage (
  p_flow_stage_id bigint,
  p_name          text   DEFAULT NULL::text,
  p_color         text   DEFAULT NULL::text
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
  v_slug text;
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

  select * into v_tag
  from public.tags
  where id = v_stage.tag_id
  for update;

  if p_name is not null and trim(p_name) <> '' then
    v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));
  else
    v_slug := v_tag.slug;
  end if;

  update public.tags
  set
    name = coalesce(nullif(trim(p_name), ''), name),
    slug = v_slug,
    color = coalesce(p_color, color)
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

GRANT ALL ON FUNCTION public.update_shipment_progress_flow_stage(bigint, text, text) TO anon;

GRANT ALL ON FUNCTION public.update_shipment_progress_flow_stage(bigint, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.update_shipment_progress_flow_stage(bigint, text, text) TO service_role;
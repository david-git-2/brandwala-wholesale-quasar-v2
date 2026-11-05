CREATE FUNCTION public.create_shipment_progress_flow_stage (
  p_flow_id    bigint,
  p_name       text,
  p_color      text    DEFAULT '#64748b'::text,
  p_sort_order integer DEFAULT NULL::integer
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
#variable_conflict use_column
declare
  v_flow public.shipment_progress_flows;
  v_slug text;
  v_tag public.tags;
  v_sort integer;
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
    raise exception 'name is required';
  end if;

  v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));

  -- RETURNS TABLE(sort_order ...) makes sort_order an OUT variable, so do not
  -- read a column of that name in SQL. Alias it, then skip any taken slot.
  v_sort := coalesce(p_sort_order, (
    select coalesce(max(x.stage_sort), 0) + 1
    from (
      select fs.sort_order as stage_sort
      from public.shipment_progress_flow_stages as fs
      where fs.flow_id = p_flow_id
    ) x
  ));

  while exists (
    select 1
    from public.shipment_progress_flow_stages as fs
    where fs.flow_id = p_flow_id
      and fs.sort_order = v_sort
  ) loop
    v_sort := v_sort + 1;
  end loop;

  insert into public.tags (
    tenant_id, name, slug, color, type, group_name, sort_order, is_active, is_system, created_by_email
  )
  values (
    v_flow.tenant_id,
    trim(p_name),
    v_slug,
    coalesce(p_color, '#64748b'),
    'shipment_progress',
    'shipment_progress',
    v_sort,
    true,
    false,
    'tenant-settings'
  )
  returning * into v_tag;

  return query
  with inserted as (
    insert into public.shipment_progress_flow_stages (flow_id, tag_id, sort_order)
    select p_flow_id, v_tag.id, v_sort
    returning
      shipment_progress_flow_stages.id,
      shipment_progress_flow_stages.flow_id,
      shipment_progress_flow_stages.tag_id,
      shipment_progress_flow_stages.sort_order as stage_sort
  )
  select
    i.id,
    i.flow_id,
    i.tag_id,
    i.stage_sort,
    v_tag.name,
    v_tag.slug,
    v_tag.color,
    v_tag.is_active
  from inserted i;
end;
$function$;

GRANT ALL ON FUNCTION public.create_shipment_progress_flow_stage(bigint, text, text, integer) TO anon;

GRANT ALL ON FUNCTION public.create_shipment_progress_flow_stage(bigint, text, text, integer) TO authenticated;

GRANT ALL ON FUNCTION public.create_shipment_progress_flow_stage(bigint, text, text, integer) TO service_role;
CREATE FUNCTION public.set_shipment_progress_flow (
  p_shipment_id bigint,
  p_flow_id     bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_flow public.shipment_progress_flows%rowtype;
  v_first_stage_tag_id bigint;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id;

  if not found then
    raise exception 'flow not found';
  end if;

  if v_flow.tenant_id <> v_ship.tenant_id then
    raise exception 'flow tenant mismatch';
  end if;

  if not public.has_active_tenant_membership(v_ship.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if v_ship.progress_tag_id is not null and not exists (
    select 1
    from public.shipment_progress_flow_stages s
    where s.flow_id = p_flow_id
      and s.tag_id = v_ship.progress_tag_id
  ) then
    select s.tag_id into v_first_stage_tag_id
    from public.shipment_progress_flow_stages s
    join public.tags t on t.id = s.tag_id
    where s.flow_id = p_flow_id
      and t.is_active = true
    order by s.sort_order asc
    limit 1;

    update public.global_shipments
    set
      progress_flow_id = p_flow_id,
      progress_tag_id = v_first_stage_tag_id,
      updated_at = now()
    where id = p_shipment_id;
  else
    update public.global_shipments
    set
      progress_flow_id = p_flow_id,
      updated_at = now()
    where id = p_shipment_id;
  end if;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'progress_flow_id', p_flow_id
  );
end;
$function$;

GRANT ALL ON FUNCTION public.set_shipment_progress_flow(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.set_shipment_progress_flow(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.set_shipment_progress_flow(bigint, bigint) TO service_role;
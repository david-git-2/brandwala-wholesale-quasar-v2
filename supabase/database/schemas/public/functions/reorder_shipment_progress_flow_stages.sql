CREATE FUNCTION public.reorder_shipment_progress_flow_stages (
  p_flow_id        bigint,
  p_flow_stage_ids bigint[]
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_flow public.shipment_progress_flows;
  v_idx integer;
  v_stage_id bigint;
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

  if p_flow_stage_ids is null or array_length(p_flow_stage_ids, 1) is null then
    return;
  end if;

  -- Unique (flow_id, sort_order) is checked per row; park first so swaps
  -- do not collide with a sort_order another stage still holds.
  update public.shipment_progress_flow_stages
  set sort_order = (-id)::integer
  where flow_id = p_flow_id
    and id = any(p_flow_stage_ids);

  for v_idx in 1..array_length(p_flow_stage_ids, 1) loop
    v_stage_id := p_flow_stage_ids[v_idx];

    update public.shipment_progress_flow_stages
    set sort_order = v_idx
    where id = v_stage_id
      and flow_id = p_flow_id;
  end loop;
end;
$function$;

GRANT ALL ON FUNCTION public.reorder_shipment_progress_flow_stages(bigint, bigint[]) TO anon;

GRANT ALL ON FUNCTION public.reorder_shipment_progress_flow_stages(bigint, bigint[]) TO authenticated;

GRANT ALL ON FUNCTION public.reorder_shipment_progress_flow_stages(bigint, bigint[]) TO service_role;
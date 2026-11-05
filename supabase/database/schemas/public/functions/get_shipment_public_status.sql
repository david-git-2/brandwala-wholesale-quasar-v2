CREATE FUNCTION public.get_shipment_public_status (
  p_token text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_progress_tag jsonb := null;
  v_progress_list jsonb := '[]'::jsonb;
  v_flow jsonb := null;
  v_tag public.tags%rowtype;
begin
  if p_token is null or trim(p_token) = '' then
    return null;
  end if;

  select * into v_ship
  from public.global_shipments
  where public_tracking_token = p_token
  limit 1;

  if not found then
    return null;
  end if;

  select jsonb_build_object(
    'id', f.id,
    'name', f.name,
    'slug', f.slug,
    'is_default', f.is_default
  )
  into v_flow
  from public.shipment_progress_flows f
  where f.id = v_ship.progress_flow_id;

  if v_ship.progress_tag_id is not null then
    select * into v_tag
    from public.tags
    where id = v_ship.progress_tag_id
      and is_active = true
    limit 1;

    if found then
      v_progress_tag := jsonb_build_object(
        'id', v_tag.id,
        'name', v_tag.name,
        'color', v_tag.color,
        'sort_order', v_tag.sort_order
      );
    end if;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', t.id,
        'name', t.name,
        'color', t.color,
        'sort_order', s.sort_order
      )
      order by s.sort_order asc
    ),
    '[]'::jsonb
  )
  into v_progress_list
  from public.shipment_progress_flow_stages s
  join public.tags t on t.id = s.tag_id
  where s.flow_id = v_ship.progress_flow_id
    and t.is_active = true;

  return jsonb_build_object(
    'id', v_ship.id,
    'name', v_ship.name,
    'status', v_ship.status,
    'progress_flow', v_flow,
    'progress_tag', v_progress_tag,
    'progress_tags', v_progress_list,
    'updated_at', v_ship.updated_at
  );
end;
$function$;

GRANT ALL ON FUNCTION public.get_shipment_public_status(text) TO anon;

GRANT ALL ON FUNCTION public.get_shipment_public_status(text) TO authenticated;

GRANT ALL ON FUNCTION public.get_shipment_public_status(text) TO service_role;
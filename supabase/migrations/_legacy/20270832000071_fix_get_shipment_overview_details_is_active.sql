-- Fix get_shipment_overview_details: is_active lives on tags, not shipment_progress_flow_stages
CREATE OR REPLACE FUNCTION "public"."get_shipment_overview_details"("p_shipment_id" bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_parent bigint;
  v_ship jsonb;
  v_sections jsonb;
  v_items jsonb;
  v_boxes jsonb;
  v_cost_entries jsonb;
  v_flow_stages jsonb;
  v_progress_flow_id bigint;
begin
  select parent_tenant_id, progress_flow_id, to_jsonb(s.*)
  into v_parent, v_progress_flow_id, v_ship
  from public.global_shipments s
  where s.id = p_shipment_id;

  if v_ship is null then
    raise exception 'shipment not found';
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_parent
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  select coalesce(
    jsonb_agg(
      to_jsonb(sec.*) || jsonb_build_object('vendor', to_jsonb(v.*))
      order by sec.sort_order asc, sec.id asc
    ),
    '[]'::jsonb
  )
  into v_sections
  from public.global_shipment_sections sec
  left join public.vendors v on v.id = sec.vendor_id
  where sec.shipment_id = p_shipment_id;

  select coalesce(
    jsonb_agg(
      to_jsonb(i.*)
      order by coalesce(i.sort_order, 0) asc, i.id asc
    ),
    '[]'::jsonb
  )
  into v_items
  from public.global_shipment_items i
  where i.shipment_id = p_shipment_id;

  select coalesce(
    jsonb_agg(
      to_jsonb(b.*)
      order by b.box_number asc, b.id asc
    ),
    '[]'::jsonb
  )
  into v_boxes
  from public.global_shipment_boxes b
  where b.shipment_id = p_shipment_id;

  select coalesce(
    jsonb_agg(
      to_jsonb(ce.*)
      order by ce.cost_type asc, ce.id asc
    ),
    '[]'::jsonb
  )
  into v_cost_entries
  from public.global_shipment_cost_entries ce
  where ce.shipment_id = p_shipment_id;

  if v_progress_flow_id is not null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'flow_stage_id', st.id,
          'flow_id', st.flow_id,
          'tag_id', st.tag_id,
          'sort_order', st.sort_order,
          'name', coalesce(t.name, ''),
          'slug', coalesce(t.slug, ''),
          'color', t.color,
          'is_active', coalesce(t.is_active, true)
        )
        order by st.sort_order asc
      ),
      '[]'::jsonb
    )
    into v_flow_stages
    from public.shipment_progress_flow_stages st
    join public.tags t on t.id = st.tag_id
    where st.flow_id = v_progress_flow_id and t.is_active = true;
  else
    v_flow_stages := '[]'::jsonb;
  end if;

  return jsonb_build_object(
    'shipment', v_ship,
    'sections', v_sections,
    'items', v_items,
    'boxes', v_boxes,
    'cost_entries', v_cost_entries,
    'flow_stages', v_flow_stages
  );
end;
$$;

ALTER FUNCTION "public"."get_shipment_overview_details"("p_shipment_id" bigint) OWNER TO "postgres";

REVOKE ALL ON FUNCTION "public"."get_shipment_overview_details"("p_shipment_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_shipment_overview_details"("p_shipment_id" bigint) TO "authenticated";

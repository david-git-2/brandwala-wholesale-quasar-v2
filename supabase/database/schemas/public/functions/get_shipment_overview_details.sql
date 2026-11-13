CREATE OR REPLACE FUNCTION public.get_shipment_overview_details (
  p_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent bigint;
  v_ship jsonb;
  v_sections jsonb;
  v_items jsonb;
  v_boxes jsonb;
  v_cost_entries jsonb;
  v_ap_bills jsonb;
  v_flow_stages jsonb;
  v_progress_flow_id bigint;
  v_ap_fx jsonb;
  v_item_outcomes jsonb;
  v_outcome_vendor_credits jsonb;
  v_batch_code_list jsonb;
  v_batch_code_items jsonb;
  v_batch_list_id bigint;
begin
  select tenant_id, progress_flow_id, to_jsonb(s.*)
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

  perform public.ensure_global_shipment_default_section(p_shipment_id);

  v_cost_entries := '[]'::jsonb;

  -- 1. Sections with vendor info
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

  -- 2. Items
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

  -- 3. Boxes
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

  v_ap_bills := public._list_shipment_cost_ap_bills_json(v_parent, p_shipment_id, false);

  -- 5. Flow stages if flow assigned
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

  v_ap_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_ap_fx := v_ap_fx - 'blended_rate';

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', o.id,
        'tenant_id', o.tenant_id,
        'shipment_item_id', o.shipment_item_id,
        'quantity', o.quantity,
        'kind', o.kind,
        'reason', o.reason,
        'purchase_price', o.purchase_price,
        'cost', o.cost,
        'description', o.description,
        'batch_label', o.batch_label
      )
      order by o.id asc
    ),
    '[]'::jsonb
  )
  into v_item_outcomes
  from public.global_shipment_item_outcomes o
  inner join public.global_shipment_items i on i.id = o.shipment_item_id
  where i.shipment_id = p_shipment_id;

  select coalesce(
    (
      select jsonb_agg(row_to_json(r) order by r.created_at desc)
      from (
        select
          c.id,
          c.shipment_id,
          c.shipment_item_id,
          c.outcome_id,
          c.quantity,
          c.previous_purchase_price,
          c.new_purchase_price,
          c.credit_amount,
          c.created_by_email,
          c.created_at,
          gsi.name as item_name
        from public.global_shipment_outcome_vendor_credits c
        inner join public.global_shipment_items gsi on gsi.id = c.shipment_item_id
        where c.shipment_id = p_shipment_id
      ) r
    ),
    '[]'::jsonb
  )
  into v_outcome_vendor_credits;

  v_batch_list_id := null;
  v_batch_code_list := null;
  v_batch_code_items := '[]'::jsonb;

  select to_jsonb(bcl.*), bcl.id
  into v_batch_code_list, v_batch_list_id
  from public.batch_code_lists bcl
  where bcl.shipment_id = p_shipment_id;

  if v_batch_list_id is not null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', bci.id,
          'list_id', bci.list_id,
          'barcode', bci.barcode,
          'product_code', bci.product_code,
          'batch_id', bci.batch_id,
          'manufacturing_date', bci.manufacturing_date,
          'expire_date', bci.expire_date,
          'is_arrived', bci.is_arrived
        )
        order by bci.id asc
      ),
      '[]'::jsonb
    )
    into v_batch_code_items
    from public.batch_code_items bci
    where bci.list_id = v_batch_list_id;
  end if;

  return jsonb_build_object(
    'shipment', v_ship,
    'sections', v_sections,
    'items', v_items,
    'boxes', v_boxes,
    'cost_entries', v_cost_entries,
    'flow_stages', v_flow_stages,
    'ap_fx', v_ap_fx,
    'ap_bills', v_ap_bills,
    'ap_issue_parties', public._resolve_shipment_cost_ap_kernel_parties(p_shipment_id),
    'item_outcomes', v_item_outcomes,
    'outcome_vendor_credits', v_outcome_vendor_credits,
    'batch_code_list', v_batch_code_list,
    'batch_code_items', v_batch_code_items
  );
end;
$function$;

GRANT ALL ON FUNCTION public.get_shipment_overview_details(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_shipment_overview_details(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_shipment_overview_details(bigint) TO service_role;
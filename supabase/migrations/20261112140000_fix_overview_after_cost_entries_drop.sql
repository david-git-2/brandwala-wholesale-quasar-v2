-- Fix RPCs after global_shipment_cost_entries drop (Option A)
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
CREATE OR REPLACE FUNCTION public._stock_spine_receive_shipment_outcomes (
  p_shipment_id bigint,
  p_stock_rows  jsonb  DEFAULT NULL::jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_ship public.global_shipments%rowtype;
  v_stamped integer;
  v_stock_count integer := 0;
  v_parent bigint;
  v_loc bigint;
  v_grade_tag bigint;
  v_avail public.stock_availability;
  v_stock_id bigint;
  v_mov_id bigint;
  v_mov_no text;
  v_posted int;
  v_delta int;
  r_out record;
  v_stock_type bigint;
BEGIN
  SELECT * INTO v_ship FROM public.global_shipments WHERE id = p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  v_parent := v_ship.tenant_id;

  IF v_ship.status = 'cancelled' THEN
    RAISE EXCEPTION 'shipment is cancelled';
  END IF;

  IF coalesce(v_ship.is_closed, false) THEN
    RAISE EXCEPTION 'shipment is closed';
  END IF;

  v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);
  PERFORM public._stamp_global_shipment_outcome_costs(p_shipment_id);

  v_mov_no := 'RP-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.stock_movements_id_seq')::text, 6, '0');

  INSERT INTO public.stock_movements (
    tenant_id,
    movement_no,
    movement_type,
    reference_type,
    reference_id,
    notes,
    created_by_email,
    is_posted,
    posted_at
  ) VALUES (
    v_parent,
    v_mov_no,
    'receive_putaway'::public.stock_movement_type,
    'global_shipment',
    p_shipment_id::text,
    'Outcome receive put-away for shipment ' || p_shipment_id::text,
    public.current_user_email(),
    false,
    NULL
  )
  RETURNING id INTO v_mov_id;

  FOR r_out IN
    SELECT o.*
    FROM public.global_shipment_item_outcomes o
    INNER JOIN public.global_shipment_items gsi ON gsi.id = o.shipment_item_id
    WHERE gsi.shipment_id = p_shipment_id
      AND o.reason <> 'ordered'::public.global_shipment_outcome_reason
    ORDER BY o.id
  LOOP
    IF r_out.kind = 'unsellable'::public.global_shipment_outcome_kind THEN
      CONTINUE;
    END IF;

    SELECT coalesce(sum(gs.quantity), 0)::int INTO v_posted
    FROM public.global_stocks gs WHERE gs.outcome_id = r_out.id;

    v_delta := r_out.quantity - v_posted;
    IF v_delta <= 0 THEN
      CONTINUE;
    END IF;

    v_loc := NULL;
    IF p_stock_rows IS NOT NULL AND jsonb_typeof(p_stock_rows) = 'array' THEN
      SELECT (elem->>'location_id')::bigint INTO v_loc
      FROM jsonb_array_elements(p_stock_rows) elem
      WHERE (elem->>'outcome_id')::bigint = r_out.id
      LIMIT 1;
    END IF;

    IF v_loc IS NULL AND p_stock_rows IS NOT NULL AND jsonb_typeof(p_stock_rows) = 'array' THEN
      SELECT (elem->>'location_id')::bigint INTO v_loc
      FROM jsonb_array_elements(p_stock_rows) elem
      WHERE (elem->>'shipment_item_id')::bigint = r_out.shipment_item_id
      LIMIT 1;
    END IF;

    v_loc := coalesce(v_loc, public.default_putaway_stock_location_id(v_parent));

    IF v_loc IS NULL THEN
      RAISE EXCEPTION 'no put-away location configured';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.stock_locations sl
      WHERE sl.id = v_loc AND sl.tenant_id = v_parent AND sl.is_active = true
        AND public._stock_location_is_leaf(v_loc)
    ) THEN
      RAISE EXCEPTION 'invalid put-away location';
    END IF;

    v_avail := 'sellable'::public.stock_availability;
    v_grade_tag := public.default_stock_grade_tag_id();

    v_stock_type := NULL;
    IF p_stock_rows IS NOT NULL AND jsonb_typeof(p_stock_rows) = 'array' THEN
      SELECT (elem->>'stock_type_id')::bigint INTO v_stock_type
      FROM jsonb_array_elements(p_stock_rows) elem
      WHERE (elem->>'outcome_id')::bigint = r_out.id
        AND nullif(elem->>'stock_type_id', '') IS NOT NULL
      LIMIT 1;
    END IF;

    IF v_stock_type IS NULL AND p_stock_rows IS NOT NULL AND jsonb_typeof(p_stock_rows) = 'array' THEN
      SELECT (elem->>'stock_type_id')::bigint INTO v_stock_type
      FROM jsonb_array_elements(p_stock_rows) elem
      WHERE (elem->>'shipment_item_id')::bigint = r_out.shipment_item_id
        AND nullif(elem->>'stock_type_id', '') IS NOT NULL
      LIMIT 1;
    END IF;

    IF v_stock_type IS NULL THEN
      SELECT gs.stock_type_id INTO v_stock_type
      FROM public.global_stocks gs
      WHERE gs.shipment_item_id = r_out.shipment_item_id
        AND gs.stock_type_id IS NOT NULL
      ORDER BY gs.quantity DESC, gs.id
      LIMIT 1;
    END IF;

    IF v_stock_type IS NULL THEN
      v_stock_type := public.default_sellable_global_stock_type_id(v_parent);
    END IF;

    IF v_stock_type IS NULL THEN
      RAISE EXCEPTION 'no sellable stock type configured';
    END IF;

    v_stock_id := public._stock_spine_upsert_receive_lot(
      v_parent,
      r_out.shipment_item_id,
      r_out.id,
      v_stock_type,
      v_delta,
      v_loc,
      v_avail,
      v_grade_tag
    );

    INSERT INTO public.stock_movement_lines (
      movement_id, stock_id, quantity, to_location_id, to_availability
    ) VALUES (v_mov_id, v_stock_id, v_delta, v_loc, v_avail);

    v_stock_count := v_stock_count + 1;
  END LOOP;

  IF v_stock_count > 0 THEN
    PERFORM public._stock_spine_finalize_inbound_movement(v_mov_id);
  ELSE
    DELETE FROM public.stock_movements WHERE id = v_mov_id;
    v_mov_id := NULL;
  END IF;

  UPDATE public.global_shipment_items gsi
  SET received_quantity = coalesce(extra_totals.total_qty, 0), updated_at = now()
  FROM (
    SELECT o.shipment_item_id AS item_id, sum(o.quantity)::int AS total_qty
    FROM public.global_shipment_item_outcomes o
    INNER JOIN public.global_shipment_items gsi2 ON gsi2.id = o.shipment_item_id
    WHERE gsi2.shipment_id = p_shipment_id
      AND o.reason <> 'ordered'::public.global_shipment_outcome_reason
    GROUP BY o.shipment_item_id
  ) extra_totals
  WHERE gsi.id = extra_totals.item_id AND gsi.shipment_id = p_shipment_id;

  IF v_stock_count > 0 THEN
    UPDATE public.global_shipments
    SET status = 'received',
        stock_ready = true,
        inventory_added = true,
        updated_at = now()
    WHERE id = p_shipment_id;
  END IF;

  RETURN jsonb_build_object(
    'shipment_id', p_shipment_id,
    'items_stamped', v_stamped,
    'stock_rows_posted', v_stock_count,
    'stock_ready', (SELECT stock_ready FROM public.global_shipments WHERE id = p_shipment_id),
    'movement_id', v_mov_id
  );
END;
$function$;

GRANT ALL ON FUNCTION public._stock_spine_receive_shipment_outcomes(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public._stock_spine_receive_shipment_outcomes(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public._stock_spine_receive_shipment_outcomes(bigint, jsonb) TO service_role;
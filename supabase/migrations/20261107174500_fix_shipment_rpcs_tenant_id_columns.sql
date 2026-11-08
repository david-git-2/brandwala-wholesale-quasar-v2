-- Redeploy shipment/stock RPCs after parent_tenant_id -> tenant_id column cutover (phase 8b/8c).

-- _stock_spine_receive_shipment_outcomes

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

  PERFORM public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  IF NOT EXISTS (
    SELECT 1 FROM public.global_shipment_cost_entries WHERE shipment_id = p_shipment_id
  ) THEN
    RAISE EXCEPTION 'shipment has no cost entries';
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

-- add_child_line_to_parent_shipment

CREATE OR REPLACE FUNCTION public.add_child_line_to_parent_shipment (
  p_parent_shipment_id bigint,
  p_source_type        text,
  p_source_id          bigint
)
  RETURNS public.global_shipment_items
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_shipment public.global_shipments;
  v_row public.global_shipment_items;
  v_source_type text;
  v_child_tenant_id bigint;
  v_prod record;
  v_vendor_id bigint;
begin
  v_source_type := lower(trim(coalesce(p_source_type, '')));

  if v_source_type not in ('order_item', 'costing_item', 'shop_order_item') then
    raise exception 'invalid source_type: %', p_source_type;
  end if;

  select * into v_shipment
  from public.global_shipments
  where id = p_parent_shipment_id;

  if v_shipment.id is null then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_shipment.tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_source_type = 'order_item' then
    -- Legacy Order Pull
    select o.tenant_id into v_child_tenant_id
    from public.order_items oi
    inner join public.orders o on o.id = oi.order_id
    where oi.id = p_source_id
      and o.parent_tenant_id = v_shipment.tenant_id
      and oi.shipment_id is null;

    if v_child_tenant_id is null then
      raise exception 'order item not available for procurement';
    end if;

    select barcode, product_code, product_weight, package_weight into v_prod
    from public.products
    where id = (select product_id from public.order_items where id = p_source_id);

    insert into public.global_shipment_items (
      shipment_id,
      product_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    select
      p_parent_shipment_id,
      oi.product_id,
      oi.name,
      greatest(coalesce(oi.ordered_quantity, 0), 0),
      oi.image_url,
      'order'::public.global_shipment_item_add_method,
      coalesce(oi.price_gbp, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      v_prod.barcode,
      v_prod.product_code,
      v_child_tenant_id,
      'order_item',
      oi.id
    from public.order_items oi
    where oi.id = p_source_id
    returning * into v_row;

    update public.order_items
    set shipment_id = p_parent_shipment_id
    where id = p_source_id;

  elsif v_source_type = 'costing_item' then
    -- Costing Pull
    select pcf.tenant_id into v_child_tenant_id
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files pcf on pcf.id = pci.product_based_costing_file_id
    inner join public.tenants t on t.id = pcf.tenant_id
    where pci.id = p_source_id
      and t.parent_id = v_shipment.tenant_id
      and pci.assigned_shipment_id is null;

    if v_child_tenant_id is null then
      raise exception 'costing item not available for procurement';
    end if;

    select product_weight, package_weight into v_prod
    from public.products
    where id = (select product_id from public.product_based_costing_items where id = p_source_id);

    insert into public.global_shipment_items (
      shipment_id,
      product_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    select
      p_parent_shipment_id,
      pci.product_id,
      pci.name,
      greatest(coalesce(pci.quantity, 0), 0),
      pci.image_url,
      'costing'::public.global_shipment_item_add_method,
      coalesce(pci.price_gbp, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      pci.barcode,
      pci.product_code,
      v_child_tenant_id,
      'costing_item',
      pci.id
    from public.product_based_costing_items pci
    where pci.id = p_source_id
    returning * into v_row;

    update public.product_based_costing_items
    set assigned_shipment_id = p_parent_shipment_id
    where id = p_source_id;

  elsif v_source_type = 'shop_order_item' then
    -- Shop Order Pull
    select o.tenant_id into v_child_tenant_id
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join public.tenants t on t.id = o.tenant_id
    where oi.id = p_source_id
      and t.parent_id = v_shipment.tenant_id
      and oi.procurement_pulled = false
      and o.status = 'placed';

    if v_child_tenant_id is null then
      raise exception 'shop order item not available for procurement';
    end if;

    select barcode, product_code, product_weight, package_weight into v_prod
    from public.products
    where id = (select product_id from public.shop_order_items where id = p_source_id);

    -- Try to match vendor by vendor_code of the shop
    select v.id into v_vendor_id
    from public.shop_order_items oi
    join public.shop_orders o on o.id = oi.order_id
    join public.shops s on s.id = o.shop_id
    join public.vendors v on v.code = s.vendor_code and v.parent_tenant_id = public.resolve_parent_tenant_id(o.tenant_id)
    where oi.id = p_source_id
    limit 1;

    insert into public.global_shipment_items (
      shipment_id,
      product_id,
      vendor_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    select
      p_parent_shipment_id,
      oi.product_id,
      v_vendor_id,
      oi.name,
      greatest(coalesce(oi.quantity, 0), 0),
      oi.image_url,
      'order'::public.global_shipment_item_add_method,
      coalesce(oi.final_price_amount, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      v_prod.barcode,
      v_prod.product_code,
      v_child_tenant_id,
      'shop_order_item',
      oi.id
    from public.shop_order_items oi
    where oi.id = p_source_id
    returning * into v_row;

    update public.shop_order_items
    set procurement_pulled = true
    where id = p_source_id;

  end if;

  return v_row;
end;
$function$;

-- add_global_shipment_item

CREATE OR REPLACE FUNCTION public.add_global_shipment_item (
  p_shipment_id bigint,
  p_item        jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent_tenant_id bigint;
  v_next_sort integer;
  v_section_id bigint;
  v_product_id bigint;
  v_row public.global_shipment_items;
  v_outcome public.global_shipment_item_outcomes;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  v_section_id := nullif((p_item->>'section_id'), '')::bigint;
  v_product_id := nullif((p_item->>'product_id'), '')::bigint;

  if public.global_shipment_item_conflicts_in_section(
    p_shipment_id,
    v_section_id,
    v_product_id,
    p_item->>'barcode',
    p_item->>'product_code',
    null
  ) then
    raise exception 'This product is already on this shipment section';
  end if;

  select s.tenant_id
  into v_parent_tenant_id
  from public.global_shipments s
  where s.id = p_shipment_id;

  if v_parent_tenant_id is null then
    raise exception 'Shipment not found';
  end if;

  select coalesce(max(sort_order), 0) + 10
  into v_next_sort
  from public.global_shipment_items
  where shipment_id = p_shipment_id;

  insert into public.global_shipment_items (
    shipment_id,
    section_id,
    product_id,
    vendor_id,
    name,
    ordered_quantity,
    image_url,
    add_method,
    purchase_price,
    product_weight,
    package_weight,
    barcode,
    product_code,
    source_child_tenant_id,
    source_type,
    source_id,
    sort_order
  )
  values (
    p_shipment_id,
    v_section_id,
    v_product_id,
    nullif((p_item->>'vendor_id'), '')::bigint,
    coalesce(p_item->>'name', 'Unnamed Item'),
    greatest(1, coalesce((p_item->>'ordered_quantity')::integer, 1)),
    p_item->>'image_url',
    coalesce((p_item->>'add_method')::public.global_shipment_item_add_method, 'manual'::public.global_shipment_item_add_method),
    greatest(0, coalesce((p_item->>'purchase_price')::numeric, 0)),
    greatest(0, coalesce((p_item->>'product_weight')::numeric, 0)),
    greatest(0, coalesce((p_item->>'package_weight')::numeric, 0)),
    p_item->>'barcode',
    p_item->>'product_code',
    nullif((p_item->>'source_child_tenant_id'), '')::bigint,
    p_item->>'source_type',
    nullif((p_item->>'source_id'), '')::bigint,
    coalesce((p_item->>'sort_order')::integer, v_next_sort)
  )
  returning * into v_row;

  insert into public.global_shipment_item_outcomes (
    tenant_id,
    shipment_item_id,
    quantity,
    kind,
    reason,
    purchase_price,
    cost
  )
  values (
    v_parent_tenant_id,
    v_row.id,
    v_row.ordered_quantity,
    'sellable'::public.global_shipment_outcome_kind,
    'ordered'::public.global_shipment_outcome_reason,
    greatest(0, coalesce(v_row.purchase_price, 0)),
    v_row.landed_cost_bdt
  )
  returning * into v_outcome;

  return jsonb_build_object(
    'item', to_jsonb(v_row),
    'ordered_outcome', to_jsonb(v_outcome)
  );
end;
$function$;

-- apply_shipment_outcome_vendor_discount

CREATE OR REPLACE FUNCTION public.apply_shipment_outcome_vendor_discount (
  p_shipment_id        bigint,
  p_source_outcome_id  bigint,
  p_quantity           integer,
  p_new_purchase_price numeric
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_src public.global_shipment_item_outcomes%rowtype;
  v_parent bigint;
  v_prev_price numeric;
  v_credit numeric;
  v_row_id bigint;
begin
  if p_quantity is null or p_quantity < 1 then
    raise exception 'quantity must be at least 1';
  end if;

  if p_new_purchase_price is null or p_new_purchase_price < 0 then
    raise exception 'purchase price must be >= 0';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  v_parent := v_ship.tenant_id;
  if not public.user_can_manage_parent_tenant(v_parent) then
    raise exception 'not allowed';
  end if;

  if v_ship.status = 'cancelled' then
    raise exception 'shipment is cancelled';
  end if;

  if coalesce(v_ship.is_closed, false) then
    raise exception 'shipment is closed';
  end if;

  if v_ship.status <> 'received' then
    raise exception 'shipment must be received to record vendor credit';
  end if;

  select o.* into v_src
  from public.global_shipment_item_outcomes o
  inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
  where o.id = p_source_outcome_id
    and gsi.shipment_id = p_shipment_id;

  if not found then
    raise exception 'outcome not found on shipment';
  end if;

  if v_src.reason = 'ordered'::public.global_shipment_outcome_reason then
    raise exception 'cannot credit ordered row';
  end if;

  if v_src.kind <> 'sellable'::public.global_shipment_outcome_kind then
    raise exception 'outcome must be sellable';
  end if;

  if p_quantity > v_src.quantity then
    raise exception 'quantity % exceeds split qty %', p_quantity, v_src.quantity;
  end if;

  v_prev_price := coalesce(v_src.purchase_price, 0);
  v_credit := round((v_prev_price - p_new_purchase_price) * p_quantity, 4);

  insert into public.global_shipment_outcome_vendor_credits (
    tenant_id,
    shipment_id,
    shipment_item_id,
    outcome_id,
    quantity,
    previous_purchase_price,
    new_purchase_price,
    credit_amount,
    created_by_email
  ) values (
    v_parent,
    p_shipment_id,
    v_src.shipment_item_id,
    v_src.id,
    p_quantity,
    v_prev_price,
    p_new_purchase_price,
    v_credit,
    public.current_user_email()
  )
  returning id into v_row_id;

  return jsonb_build_object(
    'mode', 'record',
    'id', v_row_id,
    'shipment_id', p_shipment_id,
    'outcome_id', v_src.id,
    'quantity', p_quantity,
    'previous_purchase_price', v_prev_price,
    'new_purchase_price', p_new_purchase_price,
    'credit_amount', v_credit
  );
end;
$function$;

-- archive_shipment

CREATE OR REPLACE FUNCTION public.archive_shipment (
  p_id bigint
)
  RETURNS public.global_shipments
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  update public.global_shipments
  set is_archived = true,
      archived_at = now(),
      updated_at = now()
  where id = p_id
  returning * into v_ship;

  perform public._set_global_stocks_archived_for_shipment(p_id, true);

  return v_ship;
end;
$function$;

-- assign_shipment_to_child

CREATE OR REPLACE FUNCTION public.assign_shipment_to_child (
  p_tenant_id       bigint,
  p_child_tenant_id bigint,
  p_shipment_id     bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_child_exists boolean;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
    and tenant_id = p_tenant_id
  for update;

  if not found then
    raise exception 'shipment not found or tenant mismatch';
  end if;

  if v_ship.status is distinct from 'received' then
    raise exception 'shipment must be received before assignment';
  end if;

  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_child_tenant_id is not null then
    select exists(
      select 1 from public.tenants t
      where t.id = p_child_tenant_id
        and (t.id = p_tenant_id or t.parent_id = p_tenant_id)
    ) into v_child_exists;

    if not v_child_exists then
      raise exception 'invalid child tenant for this parent';
    end if;
  end if;

  update public.global_shipments
  set assigned_child_tenant_id = p_child_tenant_id,
      updated_at = now()
  where id = p_shipment_id;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'assigned_child_tenant_id', p_child_tenant_id
  );
end;
$function$;

-- bulk_add_global_shipment_items

CREATE OR REPLACE FUNCTION public.bulk_add_global_shipment_items (
  p_shipment_id bigint,
  p_items       jsonb
)
  RETURNS SETOF public.global_shipment_items
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_item jsonb;
  v_next_sort integer;
  v_parent_tenant_id bigint;
  v_section_id bigint;
  v_product_id bigint;
  v_new_item public.global_shipment_items;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select s.tenant_id
  into v_parent_tenant_id
  from public.global_shipments s
  where s.id = p_shipment_id;

  if v_parent_tenant_id is null then
    raise exception 'Shipment not found';
  end if;

  select coalesce(max(sort_order), 0) + 10
  into v_next_sort
  from public.global_shipment_items
  where shipment_id = p_shipment_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_section_id := nullif((v_item->>'section_id'), '')::bigint;
    v_product_id := nullif((v_item->>'product_id'), '')::bigint;

    if public.global_shipment_item_conflicts_in_section(
      p_shipment_id,
      v_section_id,
      v_product_id,
      v_item->>'barcode',
      v_item->>'product_code',
      null
    ) then
      continue;
    end if;

    insert into public.global_shipment_items (
      shipment_id,
      section_id,
      product_id,
      vendor_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id,
      sort_order
    )
    values (
      p_shipment_id,
      v_section_id,
      v_product_id,
      nullif((v_item->>'vendor_id'), '')::bigint,
      coalesce(v_item->>'name', 'Unnamed Item'),
      greatest(1, coalesce((v_item->>'ordered_quantity')::integer, 1)),
      v_item->>'image_url',
      coalesce((v_item->>'add_method')::public.global_shipment_item_add_method, 'manual'::public.global_shipment_item_add_method),
      greatest(0, coalesce((v_item->>'purchase_price')::numeric, 0)),
      greatest(0, coalesce((v_item->>'product_weight')::numeric, 0)),
      greatest(0, coalesce((v_item->>'package_weight')::numeric, 0)),
      v_item->>'barcode',
      v_item->>'product_code',
      nullif((v_item->>'source_child_tenant_id'), '')::bigint,
      v_item->>'source_type',
      nullif((v_item->>'source_id'), '')::bigint,
      coalesce((v_item->>'sort_order')::integer, v_next_sort)
    )
    returning * into v_new_item;

    insert into public.global_shipment_item_outcomes (
      tenant_id,
      shipment_item_id,
      quantity,
      kind,
      reason,
      purchase_price,
      cost
    )
    values (
      v_parent_tenant_id,
      v_new_item.id,
      v_new_item.ordered_quantity,
      'sellable'::public.global_shipment_outcome_kind,
      'ordered'::public.global_shipment_outcome_reason,
      greatest(0, coalesce(v_new_item.purchase_price, 0)),
      v_new_item.landed_cost_bdt
    );

    v_next_sort := v_next_sort + 10;
  end loop;

  return query
  select *
  from public.global_shipment_items
  where shipment_id = p_shipment_id
  order by sort_order asc, id asc;
end;
$function$;

-- bulk_allocate_shipment_stock

CREATE OR REPLACE FUNCTION public.bulk_allocate_shipment_stock (
  p_tenant_id       bigint,
  p_shipment_id     bigint,
  p_child_tenant_id bigint
)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_rec record;
  v_updated_count integer := 0;
  v_other_allocated_sum integer;
  v_remaining_qty integer;
begin
  if not exists (
    select 1 from public.tenants
    where id = p_child_tenant_id and parent_id = p_tenant_id
  ) then
    raise exception 'Child tenant % does not belong to parent tenant %', p_child_tenant_id, p_tenant_id;
  end if;

  for v_rec in
    select
      gs.id as stock_id,
      gs.quantity as pool_qty
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    inner join public.global_stock_types gst on gst.id = gs.stock_type_id
    where gs.tenant_id = p_tenant_id
      and gship.id = p_shipment_id
      and gship.status = 'received'
      and gst.is_sellable = true
  loop
    select coalesce(sum(quantity), 0)::integer into v_other_allocated_sum
    from public.global_stock_allocations
    where stock_id = v_rec.stock_id
      and child_tenant_id <> p_child_tenant_id;

    v_remaining_qty := greatest(v_rec.pool_qty - v_other_allocated_sum, 0);

    if v_remaining_qty > 0 then
      insert into public.global_stock_allocations (tenant_id, child_tenant_id, stock_id, quantity)
      values (p_tenant_id, p_child_tenant_id, v_rec.stock_id, v_remaining_qty)
      on conflict (child_tenant_id, stock_id)
      do update set quantity = v_remaining_qty, updated_at = now();

      v_updated_count := v_updated_count + 1;
    end if;
  end loop;

  return v_updated_count;
end;
$function$;

-- bulk_delete_global_shipment_items

CREATE OR REPLACE FUNCTION public.bulk_delete_global_shipment_items (
  p_shipment_id bigint,
  p_item_ids    bigint[]
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent bigint;
  v_deleted_count bigint;
  v_ref_count bigint;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  if p_item_ids is null or array_length(p_item_ids, 1) is null or array_length(p_item_ids, 1) = 0 then
    return 0;
  end if;

  -- 1. Check parent tenant & permissions
  select tenant_id into v_parent
  from public.global_shipments
  where id = p_shipment_id;

  if v_parent is null then
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

  -- 2. Verify none of the items are referenced in warehouse stocks
  select count(*) into v_ref_count
  from public.global_stocks
  where shipment_item_id = any(p_item_ids);

  if v_ref_count > 0 then
    raise exception 'One or more selected items cannot be deleted because they are referenced in Warehouse Stock.';
  end if;

  -- 3. Delete items in bulk atomically
  with deleted as (
    delete from public.global_shipment_items
    where shipment_id = p_shipment_id
      and id = any(p_item_ids)
    returning id
  )
  select count(*) into v_deleted_count from deleted;

  return v_deleted_count;
end;
$function$;

-- bulk_update_global_shipment_items

CREATE OR REPLACE FUNCTION public.bulk_update_global_shipment_items (
  p_shipment_id bigint,
  p_updates     jsonb
)
  RETURNS SETOF public.global_shipment_items
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_update jsonb;
  v_id bigint;
  v_ship public.global_shipments%ROWTYPE;
BEGIN
  IF p_shipment_id IS NULL THEN
    RAISE EXCEPTION 'shipment_id is required';
  END IF;

  SELECT * INTO v_ship
  FROM public.global_shipments
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_parent_tenant(v_ship.tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  PERFORM set_config('app.skip_item_landed_restamp', '1', true);

  FOR v_update IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    v_id := (v_update->>'id')::bigint;
    IF v_id IS NOT NULL THEN
      UPDATE public.global_shipment_items
      SET
        section_id = CASE
          WHEN v_update ? 'section_id' THEN nullif((v_update->>'section_id'), '')::bigint
          ELSE section_id
        END,
        vendor_id = CASE
          WHEN v_update ? 'vendor_id' THEN nullif((v_update->>'vendor_id'), '')::bigint
          ELSE vendor_id
        END,
        ordered_quantity = CASE
          WHEN v_update ? 'ordered_quantity' AND (v_update->>'ordered_quantity') IS NOT NULL THEN greatest(1, (v_update->>'ordered_quantity')::integer)
          ELSE ordered_quantity
        END,
        purchase_price = CASE
          WHEN v_update ? 'purchase_price' AND (v_update->>'purchase_price') IS NOT NULL THEN greatest(0, (v_update->>'purchase_price')::numeric)
          ELSE purchase_price
        END,
        product_weight = CASE
          WHEN v_update ? 'product_weight' AND (v_update->>'product_weight') IS NOT NULL THEN greatest(0, (v_update->>'product_weight')::numeric)
          ELSE product_weight
        END,
        package_weight = CASE
          WHEN v_update ? 'package_weight' AND (v_update->>'package_weight') IS NOT NULL THEN greatest(0, (v_update->>'package_weight')::numeric)
          ELSE package_weight
        END,
        barcode = CASE
          WHEN v_update ? 'barcode' THEN v_update->>'barcode'
          ELSE barcode
        END,
        product_code = CASE
          WHEN v_update ? 'product_code' THEN v_update->>'product_code'
          ELSE product_code
        END,
        name = CASE
          WHEN v_update ? 'name' AND (v_update->>'name') IS NOT NULL THEN v_update->>'name'
          ELSE name
        END,
        updated_at = now()
      WHERE id = v_id AND shipment_id = p_shipment_id;
    END IF;
  END LOOP;

  PERFORM set_config('app.skip_item_landed_restamp', '0', true);

  IF EXISTS (SELECT 1 FROM public.global_shipment_items WHERE shipment_id = p_shipment_id) THEN
    PERFORM public.stamp_global_shipment_landed_costs(p_shipment_id);
  END IF;

  RETURN QUERY
  SELECT *
  FROM public.global_shipment_items
  WHERE shipment_id = p_shipment_id
  ORDER BY sort_order ASC, id ASC;
END;
$function$;

-- create_shipment_draft

CREATE OR REPLACE FUNCTION public.create_shipment_draft (
  p_tenant_id       bigint,
  p_name            text,
  p_type            public.global_shipment_type,
  p_vendor_id       bigint DEFAULT NULL::bigint,
  p_cargo_company_id bigint DEFAULT NULL::bigint
)
  RETURNS public.global_shipments
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_stock_parent bigint;
  v_vendor_id bigint;
  v_cargo_id bigint;
  v_row public.global_shipments%rowtype;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'name is required';
  end if;

  if p_type is null then
    raise exception 'type is required';
  end if;

  v_stock_parent := public.resolve_parent_tenant_id(p_tenant_id);

  if not public.user_can_manage_parent_tenant(v_stock_parent) then
    raise exception 'not allowed';
  end if;

  v_vendor_id := p_vendor_id;
  if v_vendor_id is null then
    v_vendor_id := public.ensure_default_vendor(v_stock_parent);
  else
    if not exists (
      select 1
      from public.vendors v
      where v.id = v_vendor_id
        and v.tenant_id = v_stock_parent
    ) then
      raise exception 'vendor % does not belong to parent tenant %', v_vendor_id, v_stock_parent;
    end if;
  end if;

  v_cargo_id := p_cargo_company_id;
  if v_cargo_id is null then
    v_cargo_id := public.ensure_default_cargo_company(v_stock_parent);
  else
    if not exists (
      select 1
      from public.cargo_companies c
      where c.id = v_cargo_id
        and c.tenant_id = v_stock_parent
    ) then
      raise exception 'cargo company % does not belong to parent tenant %', v_cargo_id, v_stock_parent;
    end if;
  end if;

  insert into public.global_shipments (
    tenant_id,
    name,
    type,
    vendor_id,
    cargo_company_id,
    status
  )
  values (
    v_stock_parent,
    trim(p_name),
    p_type,
    v_vendor_id,
    v_cargo_id,
    'draft'
  )
  returning * into v_row;

  perform public.ensure_global_shipment_default_section(v_row.id);

  return v_row;
end;
$function$;

-- delete_global_shipment_cost_entry

CREATE OR REPLACE FUNCTION public.delete_global_shipment_cost_entry (
  p_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_entry public.global_shipment_cost_entries%ROWTYPE;
  v_ship public.global_shipments%ROWTYPE;
BEGIN
  SELECT * INTO v_entry FROM public.global_shipment_cost_entries WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'cost entry not found';
  END IF;

  SELECT * INTO v_ship FROM public.global_shipments WHERE id = v_entry.shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_parent_tenant(v_ship.tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  DELETE FROM public.global_shipment_cost_entries WHERE id = p_id;

  IF EXISTS (SELECT 1 FROM public.global_shipment_items WHERE shipment_id = v_entry.shipment_id) THEN
    PERFORM public.stamp_global_shipment_landed_costs(v_entry.shipment_id);
  END IF;
END;
$function$;

-- delete_shipment_outcome_vendor_credit

CREATE OR REPLACE FUNCTION public.delete_shipment_outcome_vendor_credit (
  p_credit_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_credit public.global_shipment_outcome_vendor_credits%rowtype;
  v_ship public.global_shipments%rowtype;
begin
  if p_credit_id is null then
    raise exception 'credit id required';
  end if;

  select * into v_credit
  from public.global_shipment_outcome_vendor_credits
  where id = p_credit_id;

  if not found then
    raise exception 'vendor credit not found';
  end if;

  select * into v_ship
  from public.global_shipments
  where id = v_credit.shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.status = 'cancelled' then
    raise exception 'shipment is cancelled';
  end if;

  if coalesce(v_ship.is_closed, false) then
    raise exception 'shipment is closed';
  end if;

  if v_ship.status <> 'received' then
    raise exception 'shipment must be received to remove vendor credit';
  end if;

  delete from public.global_shipment_outcome_vendor_credits
  where id = p_credit_id;
end;
$function$;

-- ensure_global_shipment_cost_entries_from_header

CREATE OR REPLACE FUNCTION public.ensure_global_shipment_cost_entries_from_header (
  p_shipment_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_goods numeric;
  v_cargo_amt numeric;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if exists (
    select 1 from public.global_shipment_cost_entries e where e.shipment_id = p_shipment_id
  ) then
    return;
  end if;

  select coalesce(sum(gsi.purchase_price * gsi.ordered_quantity), 0)
  into v_goods
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  if v_ship.purchase_invoice_total is not null and v_ship.purchase_invoice_total > 0 then
    v_goods := v_ship.purchase_invoice_total;
  end if;

  v_cargo_amt := coalesce(v_ship.cargo_invoice_total, 0);

  insert into public.global_shipment_cost_entries (
    tenant_id,
    shipment_id,
    cost_bucket,
    cost_component,
    is_capitalizable,
    amount,
    currency_id,
    metadata
  ) values (
    v_ship.tenant_id,
    p_shipment_id,
    'material',
    'subtotal',
    true,
    greatest(v_goods, 0),
    v_ship.shipment_purchase_currency_id,
    jsonb_build_object('source', 'header_backfill')
  );

  if v_cargo_amt > 0 then
    insert into public.global_shipment_cost_entries (
      tenant_id,
      shipment_id,
      cost_bucket,
      cost_component,
      is_capitalizable,
      amount,
      currency_id,
      metadata
    ) values (
      v_ship.tenant_id,
      p_shipment_id,
      'freight',
      'subtotal',
      true,
      v_cargo_amt,
      v_ship.shipment_cost_currency_id,
      jsonb_build_object('source', 'header_backfill')
    );
  end if;
end;
$function$;

-- ensure_global_shipment_default_section

CREATE OR REPLACE FUNCTION public.ensure_global_shipment_default_section (
  p_shipment_id bigint
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_section_id bigint;
  v_vendor_id bigint;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if not found then
    raise exception 'shipment not found';
  end if;

  select s.id into v_section_id
  from public.global_shipment_sections s
  where s.shipment_id = p_shipment_id
  order by s.sort_order asc, s.id asc
  limit 1;

  if v_section_id is not null then
    return v_section_id;
  end if;

  v_vendor_id := v_ship.vendor_id;
  if v_vendor_id is null then
    v_vendor_id := public.ensure_default_vendor(v_ship.tenant_id);
  end if;

  insert into public.global_shipment_sections (
    tenant_id,
    shipment_id,
    vendor_id,
    title,
    sort_order,
    metadata
  )
  values (
    v_ship.tenant_id,
    p_shipment_id,
    v_vendor_id,
    'Section 1',
    0,
    '{}'::jsonb
  )
  returning id into v_section_id;

  return v_section_id;
end;
$function$;

-- generate_shipment_tracking_token

CREATE OR REPLACE FUNCTION public.generate_shipment_tracking_token (
  p_shipment_id bigint
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_token text;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.has_active_tenant_membership(v_ship.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  v_token := replace(gen_random_uuid()::text, '-', '');

  update public.global_shipments
  set public_tracking_token = v_token, updated_at = now()
  where id = p_shipment_id;

  return v_token;
end;
$function$;

-- get_procurement_dashboard_metrics

CREATE OR REPLACE FUNCTION public.get_procurement_dashboard_metrics (
  p_tenant_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_books_id bigint;
  v_sellable bigint := 0;
  v_held bigint := 0;
  v_unsellable bigint := 0;
  v_total bigint := 0;
  v_value numeric := 0;
  v_in_transit bigint := 0;
  v_draft bigint := 0;
  v_received bigint := 0;
  v_grades jsonb := '[]'::jsonb;
  v_pipeline jsonb := '[]'::jsonb;
  v_locations jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'global_stock', 'view') THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  SELECT
    coalesce(sum(gs.quantity) FILTER (WHERE gs.availability = 'sellable'::public.stock_availability), 0),
    coalesce(sum(gs.quantity) FILTER (WHERE gs.availability = 'held'::public.stock_availability), 0),
    coalesce(sum(gs.quantity) FILTER (WHERE gs.availability = 'unsellable'::public.stock_availability), 0),
    coalesce(sum(gs.quantity), 0),
    coalesce(
      sum(gs.quantity * coalesce(gsi.landed_cost_bdt, 0))
        FILTER (WHERE gs.availability = 'sellable'::public.stock_availability),
      0
    )
  INTO v_sellable, v_held, v_unsellable, v_total, v_value
  FROM public.global_stocks gs
  JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  WHERE gs.tenant_id = v_books_id
    AND gs.is_archived = false;

  SELECT
    coalesce(count(*) FILTER (WHERE s.status = 'in_transit'), 0),
    coalesce(count(*) FILTER (WHERE s.status = 'draft'), 0),
    coalesce(count(*) FILTER (WHERE s.status = 'received'), 0)
  INTO v_in_transit, v_draft, v_received
  FROM public.global_shipments s
  WHERE s.tenant_id = v_books_id
    AND s.is_archived = false;

  SELECT coalesce(jsonb_agg(row_to_json(g) ORDER BY g.qty DESC), '[]'::jsonb)
  INTO v_grades
  FROM (
    SELECT coalesce(t.name, 'Ungraded') AS name, sum(gs.quantity)::bigint AS qty
    FROM public.global_stocks gs
    LEFT JOIN public.tags t ON t.id = gs.grade_tag_id
    WHERE gs.tenant_id = v_books_id
      AND gs.is_archived = false
      AND gs.quantity > 0
    GROUP BY coalesce(t.name, 'Ungraded')
  ) g;

  SELECT coalesce(jsonb_agg(row_to_json(p) ORDER BY p.sort_key), '[]'::jsonb)
  INTO v_pipeline
  FROM (
    SELECT
      s.status,
      count(*)::bigint AS count,
      CASE s.status
        WHEN 'draft' THEN 1
        WHEN 'in_transit' THEN 2
        WHEN 'received' THEN 3
        ELSE 4
      END AS sort_key
    FROM public.global_shipments s
    WHERE s.tenant_id = v_books_id
      AND s.is_archived = false
      AND s.status <> 'cancelled'
    GROUP BY s.status
  ) p;

  SELECT coalesce(jsonb_agg(row_to_json(l) ORDER BY l.qty DESC), '[]'::jsonb)
  INTO v_locations
  FROM (
    SELECT
      coalesce(sl.name, 'Unlocated') AS name,
      sum(gs.quantity)::bigint AS qty
    FROM public.global_stocks gs
    LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
    WHERE gs.tenant_id = v_books_id
      AND gs.is_archived = false
      AND gs.quantity > 0
    GROUP BY coalesce(sl.name, 'Unlocated')
  ) l;

  RETURN jsonb_build_object(
    'tenant_id', v_books_id,
    'sellable_qty', v_sellable,
    'held_qty', v_held,
    'unsellable_qty', v_unsellable,
    'total_qty', v_total,
    'sellable_pct', CASE WHEN v_total > 0 THEN round((v_sellable::numeric / v_total) * 100, 1) ELSE 0 END,
    'sellable_value_bdt', round(v_value, 2),
    'in_transit_count', v_in_transit,
    'draft_count', v_draft,
    'received_count', v_received,
    'grades', v_grades,
    'pipeline', v_pipeline,
    'locations', v_locations
  );
END;
$function$;

-- get_shipment_overview_details

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

  -- Ensure cost entries from header are synced
  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  perform public.ensure_global_shipment_default_section(p_shipment_id);

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

  -- 4. Cost entries (narrow projection)
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ce.id,
        'shipment_id', ce.shipment_id,
        'cost_bucket', ce.cost_bucket,
        'cost_component', ce.cost_component,
        'is_capitalizable', ce.is_capitalizable,
        'description', ce.description,
        'amount', ce.amount,
        'currency_id', ce.currency_id,
        'metadata', ce.metadata,
        'section_id', ce.section_id
      )
      order by ce.cost_bucket asc, ce.cost_component asc, ce.id asc
    ),
    '[]'::jsonb
  )
  into v_cost_entries
  from public.global_shipment_cost_entries ce
  where ce.shipment_id = p_shipment_id;

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
    'item_outcomes', v_item_outcomes,
    'outcome_vendor_credits', v_outcome_vendor_credits,
    'batch_code_list', v_batch_code_list,
    'batch_code_items', v_batch_code_items
  );
end;
$function$;

-- get_shipment_pnl

CREATE OR REPLACE FUNCTION public.get_shipment_pnl (
  p_tenant_id   bigint,
  p_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_shipment jsonb;
  v_items jsonb;
  v_total_landed_cost numeric(12,2) := 0;
  v_total_sold_cost numeric(12,2) := 0;
  v_total_revenue numeric(12,2) := 0;
  v_total_gross_profit numeric(12,2) := 0;
  v_total_sellable_on_hand_value numeric(12,2) := 0;
  v_total_shrinkage_value numeric(12,2) := 0;
  v_total_stolen_value numeric(12,2) := 0;
  v_total_box_damage_value numeric(12,2) := 0;
  v_total_expired_value numeric(12,2) := 0;
  v_total_reconciliation_gap bigint := 0;
  v_disposition_available boolean := false;
begin
  -- Resolve parent tenant to enforce access
  if public.resolve_parent_tenant_id(p_tenant_id) <> (select tenant_id from public.global_shipments where id = p_shipment_id) then
    raise exception 'unauthorized tenant access to shipment';
  end if;

  -- 1. Get shipment header
  select row_to_json(s)::jsonb
  into v_shipment
  from public.global_shipments s
  where s.id = p_shipment_id;

  -- Check if disposition is available (i.e. global_stocks rows exist for shipment items)
  select exists (
    select 1
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gs.shipment_item_id = gsi.id
    where gsi.shipment_id = p_shipment_id
  ) into v_disposition_available;

  -- 2. Get shipment items details with on-the-fly margins and stock disposition
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_items
  from (
    select
      si.*,
      public.calculate_landed_unit_cost(si.id) as landed_unit_cost,
      coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_qty,
      coalesce(public.calculate_landed_unit_cost(si.id), 0) * coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_cost,
      coalesce(sum(
        ii.sell_price_amount * (ii.quantity - coalesce(ii.return_quantity, 0))
        - case
          when inv.invoice_type = 'dropship'::public.global_invoice_type then 0.00
          else (coalesce(inv.discount_amount, 0.00) + coalesce(inv.written_off_amount, 0.00))
            * (ii.line_total_amount / nullif(invagg.inv_line_subtotal, 0.00))
        end
      ), 0) as revenue,
      coalesce(disp.sellable_qty, 0) as sellable_qty,
      coalesce(disp.stolen_qty, 0) as stolen_qty,
      coalesce(disp.box_damage_qty, 0) as box_damage_qty,
      coalesce(disp.expired_qty, 0) as expired_qty,
      coalesce(disp.reserved_qty, 0) as reserved_qty,
      (coalesce(disp.sellable_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as sellable_value,
      ((coalesce(disp.stolen_qty, 0) + coalesce(disp.box_damage_qty, 0) + coalesce(disp.expired_qty, 0)) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as shrinkage_value,
      (coalesce(disp.stolen_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as stolen_value,
      (coalesce(disp.box_damage_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as box_damage_value,
      (coalesce(disp.expired_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as expired_value,
      (si.ordered_quantity - coalesce(sum(ii.quantity - ii.return_quantity), 0) - coalesce(disp.sellable_qty, 0) - coalesce(disp.stolen_qty, 0) - coalesce(disp.box_damage_qty, 0) - coalesce(disp.expired_qty, 0) - coalesce(disp.reserved_qty, 0)) as reconciliation_gap
    from public.global_shipment_items si
    left join public.global_invoice_items ii on ii.shipment_item_id = si.id
    left join public.bills inv on inv.id = ii.invoice_id and inv.invoice_status = 'issued'::public.global_invoice_status
    left join lateral (
      select coalesce(sum(x.line_total_amount), 0.00) as inv_line_subtotal
      from public.global_invoice_items x
      where x.invoice_id = ii.invoice_id
    ) invagg on true
    left join lateral (
      select
        coalesce(sum(gs.quantity) filter (where gst.is_sellable = true), 0) as sellable_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'stolen'), 0) as stolen_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'box damage'), 0) as box_damage_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'expired'), 0) as expired_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'reserved'), 0) as reserved_qty
      from public.global_stocks gs
      inner join public.global_stock_types gst on gst.id = gs.stock_type_id
      where gs.shipment_item_id = si.id
    ) disp on true
    where si.shipment_id = p_shipment_id
    group by si.id, disp.sellable_qty, disp.stolen_qty, disp.box_damage_qty, disp.expired_qty, disp.reserved_qty
  ) r;

  -- 3. Sum total metrics
  select
    coalesce(sum(landed_unit_cost * received_qty), 0),
    coalesce(sum(sold_cost), 0),
    coalesce(sum(revenue), 0),
    coalesce(sum(sellable_qty * landed_unit_cost), 0),
    coalesce(sum((stolen_qty + box_damage_qty + expired_qty) * landed_unit_cost), 0),
    coalesce(sum(stolen_qty * landed_unit_cost), 0),
    coalesce(sum(box_damage_qty * landed_unit_cost), 0),
    coalesce(sum(expired_qty * landed_unit_cost), 0),
    coalesce(sum(reconciliation_gap), 0)
  into
    v_total_landed_cost,
    v_total_sold_cost,
    v_total_revenue,
    v_total_sellable_on_hand_value,
    v_total_shrinkage_value,
    v_total_stolen_value,
    v_total_box_damage_value,
    v_total_expired_value,
    v_total_reconciliation_gap
  from (
    select
      public.calculate_landed_unit_cost(si.id) as landed_unit_cost,
      si.ordered_quantity as received_qty,
      coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_qty,
      coalesce(public.calculate_landed_unit_cost(si.id), 0) * coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_cost,
      coalesce(sum(
        ii.sell_price_amount * (ii.quantity - coalesce(ii.return_quantity, 0))
        - case
          when inv.invoice_type = 'dropship'::public.global_invoice_type then 0.00
          else (coalesce(inv.discount_amount, 0.00) + coalesce(inv.written_off_amount, 0.00))
            * (ii.line_total_amount / nullif(invagg.inv_line_subtotal, 0.00))
        end
      ), 0) as revenue,
      coalesce(disp.sellable_qty, 0) as sellable_qty,
      coalesce(disp.stolen_qty, 0) as stolen_qty,
      coalesce(disp.box_damage_qty, 0) as box_damage_qty,
      coalesce(disp.expired_qty, 0) as expired_qty,
      (si.ordered_quantity - coalesce(sum(ii.quantity - ii.return_quantity), 0) - coalesce(disp.sellable_qty, 0) - coalesce(disp.stolen_qty, 0) - coalesce(disp.box_damage_qty, 0) - coalesce(disp.expired_qty, 0) - coalesce(disp.reserved_qty, 0)) as reconciliation_gap
    from public.global_shipment_items si
    left join public.global_invoice_items ii on ii.shipment_item_id = si.id
    left join public.bills inv on inv.id = ii.invoice_id and inv.invoice_status = 'issued'::public.global_invoice_status
    left join lateral (
      select coalesce(sum(x.line_total_amount), 0.00) as inv_line_subtotal
      from public.global_invoice_items x
      where x.invoice_id = ii.invoice_id
    ) invagg on true
    left join lateral (
      select
        coalesce(sum(gs.quantity) filter (where gst.is_sellable = true), 0) as sellable_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'stolen'), 0) as stolen_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'box damage'), 0) as box_damage_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'expired'), 0) as expired_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'reserved'), 0) as reserved_qty
      from public.global_stocks gs
      inner join public.global_stock_types gst on gst.id = gs.stock_type_id
      where gs.shipment_item_id = si.id
    ) disp on true
    where si.shipment_id = p_shipment_id
    group by si.id, disp.sellable_qty, disp.stolen_qty, disp.box_damage_qty, disp.expired_qty, disp.reserved_qty
  ) rollup;

  v_total_gross_profit := v_total_revenue - v_total_sold_cost;

  return jsonb_build_object(
    'shipment', v_shipment,
    'items', v_items,
    'totals', jsonb_build_object(
      'landed_cost', v_total_landed_cost,
      'sold_cost', v_total_sold_cost,
      'revenue', v_total_revenue,
      'gross_profit', v_total_gross_profit,
      'sellable_on_hand_value', v_total_sellable_on_hand_value,
      'shrinkage_value', v_total_shrinkage_value,
      'stolen_value', v_total_stolen_value,
      'box_damage_value', v_total_box_damage_value,
      'expired_value', v_total_expired_value,
      'unsold_value', v_total_sellable_on_hand_value, -- alias for backward compat
      'disposition_available', v_disposition_available,
      'reconciliation_gap', v_total_reconciliation_gap
    )
  );
end;
$function$;

-- get_shipment_settings_finance_bundle

CREATE OR REPLACE FUNCTION public.get_shipment_settings_finance_bundle (
  p_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent bigint;
  v_cost_entries jsonb;
  v_ap_bills jsonb;
  v_ap_fx jsonb;
  v_sid text;
  v_elem jsonb;
  v_slim jsonb := '[]'::jsonb;
begin
  select gs.tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
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
  perform public.sync_shipment_ap_bills(p_shipment_id);

  v_sid := p_shipment_id::text;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ce.id,
        'shipment_id', ce.shipment_id,
        'cost_bucket', ce.cost_bucket,
        'cost_component', ce.cost_component,
        'is_capitalizable', ce.is_capitalizable,
        'description', ce.description,
        'amount', ce.amount,
        'currency_id', ce.currency_id,
        'metadata', ce.metadata,
        'section_id', ce.section_id
      )
      order by ce.cost_bucket, ce.cost_component, ce.id
    ),
    '[]'::jsonb
  )
  into v_cost_entries
  from public.global_shipment_cost_entries ce
  where ce.shipment_id = p_shipment_id;

  for v_elem in
    select value
    from jsonb_array_elements(
      public.list_bills_for_source(v_parent, 'shipment_cost', v_sid, null, false, true)
    )
  loop
    v_slim := v_slim || jsonb_build_array(
      jsonb_build_object(
        'id', v_elem->'id',
        'invoice_no', v_elem->'invoice_no',
        'ap_kind', v_elem->'ap_kind',
        'source_type', v_elem->'source_type',
        'source_id', v_elem->'source_id',
        'source_key', v_elem->'source_key',
        'invoice_status', v_elem->'invoice_status',
        'payment_status', v_elem->'payment_status',
        'total_amount', v_elem->'total_amount',
        'due_amount', coalesce(
          v_elem->'net_balances'->'open_books',
          v_elem->'due_amount'
        )
      )
    );
  end loop;
  v_ap_bills := v_slim;

  v_ap_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_ap_fx := v_ap_fx - 'blended_rate';

  return jsonb_build_object(
    'cost_entries', v_cost_entries,
    'ap_bills', v_ap_bills,
    'ap_fx', v_ap_fx
  );
end;
$function$;

-- get_tenant_shipment_profit_report

CREATE OR REPLACE FUNCTION public.get_tenant_shipment_profit_report (
  p_tenant_id   bigint,
  p_shipment_id bigint                   DEFAULT NULL::bigint,
  p_search      text                     DEFAULT NULL::text,
  p_start_date  timestamp with time zone DEFAULT NULL::timestamp WITH time zone,
  p_end_date    timestamp with time zone DEFAULT NULL::timestamp WITH time zone,
  p_page        integer                  DEFAULT 1,
  p_page_size   integer                  DEFAULT 20
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_books_id bigint;
  v_summary jsonb;
  v_rows jsonb;
  v_total_count integer := 0;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(coalesce(p_page_size, 20), 1);
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Tenant ID is required';
  END IF;

  SELECT coalesce(t.parent_id, t.id)
  INTO v_books_id
  FROM public.tenants t
  WHERE t.id = p_tenant_id;

  IF v_books_id IS NULL THEN
    RAISE EXCEPTION 'Tenant not found';
  END IF;

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'global_shipment', 'view')
    OR public.membership_has_module_action(v_books_id, 'global_shipment', 'view')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  WITH shipment_metrics AS (
    SELECT
      s.id AS shipment_id,
      s.name AS shipment_name,
      s.tenant_shipment_id::text AS shipment_code,
      s.status AS shipment_status,
      s.created_at,
      s.shipment_cost_currency_id AS currency_id,
      
      -- Inbound Quantities & Landed Cost (ordered manifest, not sold-only received)
      coalesce(sum(gsi.ordered_quantity), 0)::int AS inbound_quantity,
      coalesce(sum(gsi.ordered_quantity * coalesce(gsi.landed_cost_bdt, 0)), 0)::numeric(18,4) AS total_landed_cost,
      
      -- Sales & Returns from Issued Sales Invoices (invoice_status = 'issued')
      coalesce(sum(sales.sold_qty), 0)::int AS sold_quantity,
      coalesce(sum(sales.returned_qty), 0)::int AS returned_quantity,
      coalesce(sum(sales.net_sold_qty), 0)::int AS net_sold_quantity,
      coalesce(sum(sales.sold_revenue), 0)::numeric(18,4) AS gross_sold_revenue,
      coalesce(sum(sales.cogs), 0)::numeric(18,4) AS cogs_amount,
      coalesce(sum(sales.sold_revenue - sales.cogs), 0)::numeric(18,4) AS realized_gross_profit,
      
      -- Inventory Valuation & Damage
      coalesce(sum(inv.sellable_qty), 0)::int AS sellable_stock_qty,
      coalesce(sum(inv.held_qty), 0)::int AS held_stock_qty,
      coalesce(sum(inv.unsellable_qty), 0)::int AS damaged_stock_qty,
      coalesce(sum(
        greatest(gsi.ordered_quantity - coalesce(sales.net_sold_qty, 0), coalesce(inv.sellable_qty, 0))
        * coalesce(gsi.landed_cost_bdt, 0)
      ), 0)::numeric(18,4) AS unsold_stock_value,
      coalesce(sum(inv.unsellable_qty * coalesce(gsi.landed_cost_bdt, 0)), 0)::numeric(18,4) AS damage_loss_value,

      -- Item details array if single shipment requested
      CASE WHEN p_shipment_id IS NOT NULL THEN
        coalesce(
          jsonb_agg(
            jsonb_build_object(
              'item_id', gsi.id,
              'product_name', coalesce(gsi.name, 'Item #' || gsi.id),
              'barcode', gsi.barcode,
              'inbound_qty', gsi.ordered_quantity,
              'unit_cost_bdt', gsi.landed_cost_bdt,
              'total_cost_bdt', (gsi.ordered_quantity * coalesce(gsi.landed_cost_bdt, 0)),
              'sold_qty', coalesce(sales.net_sold_qty, 0),
              'sold_revenue', coalesce(sales.sold_revenue, 0),
              'cogs', coalesce(sales.cogs, 0),
              'gross_profit', coalesce(sales.sold_revenue - sales.cogs, 0),
              'sellable_qty', coalesce(inv.sellable_qty, 0),
              'unsold_stock_value', coalesce(
                greatest(gsi.ordered_quantity - coalesce(sales.net_sold_qty, 0), coalesce(inv.sellable_qty, 0))
                * coalesce(gsi.landed_cost_bdt, 0),
                0
              ),
              'damaged_qty', coalesce(inv.unsellable_qty, 0),
              'damage_loss_value', coalesce(inv.unsellable_qty * coalesce(gsi.landed_cost_bdt, 0), 0)
            )
          ) FILTER (WHERE gsi.id IS NOT NULL),
          '[]'::jsonb
        )
      ELSE NULL END AS items

    FROM public.global_shipments s
    LEFT JOIN public.global_shipment_items gsi ON gsi.shipment_id = s.id
    
    -- Subquery for aggregated sales per shipment item
    LEFT JOIN LATERAL (
      SELECT
        coalesce(sum(gii.quantity), 0) AS sold_qty,
        coalesce(sum(gii.return_quantity), 0) AS returned_qty,
        coalesce(sum(gii.quantity - gii.return_quantity), 0) AS net_sold_qty,
        coalesce(sum(
          gii.sell_price_amount * (gii.quantity - coalesce(gii.return_quantity, 0))
          - coalesce(gii.line_discount_amount, 0) * (greatest(gii.quantity - gii.return_quantity, 0) / nullif(gii.quantity, 0))
          - CASE
            WHEN si.invoice_type = 'dropship'::public.global_invoice_type THEN 0.00
            ELSE (coalesce(si.discount_amount, 0.00) + coalesce(si.written_off_amount, 0.00))
              * (gii.line_total_amount / nullif(invagg.inv_line_subtotal, 0.00))
          END
        ), 0) AS sold_revenue,
        coalesce(sum((gii.quantity - gii.return_quantity) * coalesce(gsi.landed_cost_bdt, 0)), 0) AS cogs
      FROM public.global_invoice_items gii
      JOIN public.bills si ON si.id = gii.invoice_id
      LEFT JOIN LATERAL (
        SELECT coalesce(sum(x.line_total_amount), 0.00) AS inv_line_subtotal
        FROM public.global_invoice_items x
        WHERE x.invoice_id = gii.invoice_id
      ) invagg ON true
      WHERE gii.shipment_item_id = gsi.id
        AND si.invoice_status = 'issued'
    ) sales ON true

    -- Subquery for inventory breakdown per shipment item
    LEFT JOIN LATERAL (
      SELECT
        coalesce(sum(CASE WHEN gs.availability = 'sellable' THEN gs.quantity ELSE 0 END), 0) AS sellable_qty,
        coalesce(sum(CASE WHEN gs.availability = 'held' THEN gs.quantity ELSE 0 END), 0) AS held_qty,
        coalesce(sum(CASE WHEN gs.availability = 'unsellable' THEN gs.quantity ELSE 0 END), 0) AS unsellable_qty
      FROM public.global_stocks gs
      WHERE gs.shipment_item_id = gsi.id
    ) inv ON true

    WHERE s.tenant_id = v_books_id
      AND (p_shipment_id IS NULL OR s.id = p_shipment_id)
      AND (p_start_date IS NULL OR s.created_at >= p_start_date)
      AND (p_end_date IS NULL OR s.created_at <= p_end_date)
      AND (
        p_search IS NULL 
        OR btrim(p_search) = ''
        OR s.name ILIKE ('%' || btrim(p_search) || '%')
        OR (s.tenant_shipment_id IS NOT NULL AND s.tenant_shipment_id::text ILIKE ('%' || btrim(p_search) || '%'))
      )
    GROUP BY s.id, s.name, s.tenant_shipment_id, s.status, s.created_at, s.shipment_cost_currency_id
  ),
  counted AS (
    SELECT count(*) AS total_count FROM shipment_metrics
  ),
  summary_calc AS (
    SELECT
      coalesce(sum(inbound_quantity), 0)::int AS total_inbound_units,
      coalesce(sum(total_landed_cost), 0)::numeric(18,4) AS total_landed_cost,
      coalesce(sum(net_sold_quantity), 0)::int AS total_net_sold_units,
      coalesce(sum(gross_sold_revenue), 0)::numeric(18,4) AS total_gross_sold_revenue,
      coalesce(sum(cogs_amount), 0)::numeric(18,4) AS total_cogs,
      coalesce(sum(realized_gross_profit), 0)::numeric(18,4) AS total_realized_gross_profit,
      CASE
        WHEN coalesce(sum(gross_sold_revenue), 0) > 0
        THEN round((coalesce(sum(realized_gross_profit), 0) / sum(gross_sold_revenue) * 100)::numeric, 2)
        ELSE 0.00
      END AS overall_realized_gp_margin_pct,
      coalesce(sum(unsold_stock_value), 0)::numeric(18,4) AS total_unsold_stock_value,
      coalesce(sum(damage_loss_value), 0)::numeric(18,4) AS total_damage_loss_value,
      count(*)::int AS total_shipments_count
    FROM shipment_metrics
  ),
  paginated_rows AS (
    SELECT
      sm.*,
      CASE
        WHEN sm.gross_sold_revenue > 0
        THEN round((sm.realized_gross_profit / sm.gross_sold_revenue * 100)::numeric, 2)
        ELSE 0.00
      END AS realized_gp_margin_pct,
      CASE
        WHEN sm.inbound_quantity > 0
        THEN round((sm.net_sold_quantity::numeric / sm.inbound_quantity::numeric * 100)::numeric, 1)
        ELSE 0.0
      END AS batch_sold_pct
    FROM shipment_metrics sm
    ORDER BY sm.created_at DESC, sm.shipment_id DESC
    OFFSET (v_page - 1) * v_page_size
    LIMIT v_page_size
  )
  SELECT
    to_jsonb(s),
    coalesce((SELECT total_count FROM counted), 0),
    coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  INTO v_summary, v_total_count, v_rows
  FROM summary_calc s
  CROSS JOIN paginated_rows r
  GROUP BY to_jsonb(s);

  RETURN jsonb_build_object(
    'summary', coalesce(v_summary, jsonb_build_object(
      'total_inbound_units', 0,
      'total_landed_cost', 0,
      'total_net_sold_units', 0,
      'total_gross_sold_revenue', 0,
      'total_cogs', 0,
      'total_realized_gross_profit', 0,
      'overall_realized_gp_margin_pct', 0,
      'total_unsold_stock_value', 0,
      'total_damage_loss_value', 0,
      'total_shipments_count', 0
    )),
    'shipments', coalesce(v_rows, '[]'::jsonb),
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', CASE WHEN v_total_count = 0 THEN 1 ELSE ceil(v_total_count::numeric / v_page_size::numeric)::int END
    )
  );
END;
$function$;

COMMENT ON FUNCTION public.get_tenant_shipment_profit_report(bigint,bigint,text,timestamp with time zone,timestamp with time zone,integer,integer) IS 'Consolidated batch shipment profit, landed cost, COGS, realized gross profit, remaining stock valuation and damage reporting.';

-- issue_shipment_ap_bills

CREATE OR REPLACE FUNCTION public.issue_shipment_ap_bills (
  p_shipment_id bigint
)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent bigint;
  v_bill_id bigint;
  v_count integer := 0;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select gs.tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  perform public._assert_shipment_ap_issue_allowed(p_shipment_id);
  perform public._shipment_money_advisory_lock(p_shipment_id);

  for v_bill_id in
    select b.id
    from public.bills b
    where b.parent_tenant_id = v_parent
      and b.invoice_type = 'ap'::public.global_invoice_type
      and b.document_kind = 'standard'::public.bill_document_kind
      and b.invoice_status = 'draft'::public.global_invoice_status
      and coalesce(b.total_amount, 0) > 0
      and (
        (b.source_type = 'shipment_cost' and b.source_id = p_shipment_id::text)
        or b.ap_shipment_id = p_shipment_id
      )
    order by b.id asc
  loop
    perform public.issue_bill(v_bill_id);
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$function$;

-- list_global_shipment_cost_entries

CREATE OR REPLACE FUNCTION public.list_global_shipment_cost_entries (
  p_shipment_id bigint
)
  RETURNS SETOF public.global_shipment_cost_entries
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent bigint;
begin
  select tenant_id into v_parent
  from public.global_shipments
  where id = p_shipment_id;

  if v_parent is null then
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

  return query
  select e.*
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
  order by e.cost_bucket, e.cost_component, e.id;
end;
$function$;

-- list_global_shipments_paginated

CREATE OR REPLACE FUNCTION public.list_global_shipments_paginated (
  p_tenant_id        bigint,
  p_page             integer DEFAULT 1,
  p_page_size        integer DEFAULT 20,
  p_search           text    DEFAULT NULL::text,
  p_status           text    DEFAULT NULL::text,
  p_is_archived      boolean DEFAULT false,
  p_vendor_id        bigint  DEFAULT NULL::bigint,
  p_cargo_company_id bigint  DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_total_count bigint;
  v_archived_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  select count(*)
  into v_total_count
  from public.global_shipments s
  where s.tenant_id = p_tenant_id
    and (p_is_archived is null or s.is_archived = p_is_archived)
    and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
    and (
      p_search is null or p_search = '' or (
        s.name ilike '%' || p_search || '%'
        or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
      )
    )
    and (p_vendor_id is null or s.vendor_id = p_vendor_id)
    and (p_cargo_company_id is null or s.cargo_company_id = p_cargo_company_id);

  select count(*)
  into v_archived_count
  from public.global_shipments s
  where s.tenant_id = p_tenant_id
    and s.is_archived = true;

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      s.id as sort_id,
      (
        to_jsonb(s)
        || jsonb_build_object(
          'vendor_name', v.name,
          'vendor_code', v.code,
          'progress_tag',
          case
            when t.id is null then null
            else jsonb_build_object(
              'id', t.id,
              'name', t.name,
              'slug', t.slug,
              'group_name', t.group_name,
              'sort_order', t.sort_order,
              'color', t.color
            )
          end
        )
      ) as row_json
    from public.global_shipments s
    left join public.vendors v
      on v.id = s.vendor_id
    left join public.tags t
      on t.id = s.progress_tag_id
     and t.group_name = 'shipment_progress'
    where s.tenant_id = p_tenant_id
      and (p_is_archived is null or s.is_archived = p_is_archived)
      and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
      and (
        p_search is null or p_search = '' or (
          s.name ilike '%' || p_search || '%'
          or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
        )
      )
      and (p_vendor_id is null or s.vendor_id = p_vendor_id)
      and (p_cargo_company_id is null or s.cargo_company_id = p_cargo_company_id)
    order by s.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) q;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages,
      'archived_total', v_archived_count
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_global_shipments_paginated (
  p_tenant_id bigint,
  p_page      integer DEFAULT 1,
  p_page_size integer DEFAULT 20,
  p_search    text    DEFAULT NULL::text,
  p_status    text    DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  select count(*)
  into v_total_count
  from public.global_shipments s
  where s.tenant_id = p_tenant_id
    and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
    and (
      p_search is null or p_search = '' or (
        s.name ilike '%' || p_search || '%'
        or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
      )
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      s.id as sort_id,
      (
        to_jsonb(s)
        || jsonb_build_object(
          'progress_tag',
          case
            when t.id is null then null
            else jsonb_build_object(
              'id', t.id,
              'name', t.name,
              'slug', t.slug,
              'group_name', t.group_name,
              'sort_order', t.sort_order,
              'color', t.color
            )
          end
        )
      ) as row_json
    from public.global_shipments s
    left join public.tags t
      on t.id = s.progress_tag_id
     and t.group_name = 'shipment_progress'
    where s.tenant_id = p_tenant_id
      and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
      and (
        p_search is null or p_search = '' or (
          s.name ilike '%' || p_search || '%'
          or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
        )
      )
    order by s.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) q;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$function$;

-- list_global_stocks_cursor

CREATE OR REPLACE FUNCTION public.list_global_stocks_cursor (
  p_tenant_id       bigint,
  p_limit           integer                   DEFAULT 20,
  p_cursor_id       bigint                    DEFAULT NULL::bigint,
  p_search          text                      DEFAULT NULL::text,
  p_stock_type_id   bigint                    DEFAULT NULL::bigint,
  p_is_sellable     boolean                   DEFAULT NULL::boolean,
  p_shipment_status text                      DEFAULT NULL::text,
  p_hide_zero_stock boolean                   DEFAULT true,
  p_location_id     bigint                    DEFAULT NULL::bigint,
  p_availability    public.stock_availability DEFAULT NULL::public.stock_availability,
  p_shipment_id     bigint                    DEFAULT NULL::bigint,
  p_include_total   boolean                   DEFAULT false,
  p_grade_tag_id    bigint                    DEFAULT NULL::bigint,
  p_group_by        text                      DEFAULT NULL::text,
  p_group_key       text                      DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 100));
  v_fetch integer := v_limit + 1;
  v_data jsonb := '[]'::jsonb;
  v_n integer := 0;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
  v_last_id bigint;
  v_total bigint := null;
begin
  if not public._can_view_parent_warehouse_stock(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  if coalesce(p_include_total, false) and p_cursor_id is null then
    select count(*)
    into v_total
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    where gs.tenant_id = p_tenant_id
      and gs.is_archived = false
      and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
      and (
        p_is_sellable is null
        or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
        or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
      )
      and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
      and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
      and public.stock_location_matches_filter(gs.location_id, p_location_id)
      and (p_availability is null or gs.availability = p_availability)
      and (p_shipment_id is null or gsi.shipment_id = p_shipment_id)
      and (p_grade_tag_id is null or gs.grade_tag_id = p_grade_tag_id)
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
        )
      )
      and (
        p_group_by is null or p_group_key is null or p_group_key = ''
        or case p_group_by
          when 'shipment' then gsi.shipment_id::text = p_group_key
          when 'product' then coalesce(nullif(trim(gsi.product_code), ''), 'si:' || gsi.id::text) = p_group_key
          when 'location' then gs.location_id::text = p_group_key
          when 'grade' then coalesce(gs.grade_tag_id::text, '') = p_group_key
          when 'availability' then gs.availability::text = p_group_key
          else true
        end
      );
  end if;

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id,
      gs.tenant_id,
      gs.shipment_item_id,
      gs.stock_type_id,
      gs.quantity,
      gs.is_usable,
      gs.availability,
      gs.location_id,
      gs.grade_tag_id,
      gs.outcome_id,
      sl.name as location_name,
      o.kind as outcome_kind,
      o.reason as outcome_reason,
      gsi.shipment_id,
      gsi.ordered_quantity,
      gsi.name as item_name,
      gsi.product_code,
      gsi.barcode,
      gsi.image_url,
      gsi.purchase_price,
      gsi.product_weight,
      gsi.package_weight,
      gsi.landed_cost_bdt,
      coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) as resolved_landed_cost_bdt,
      gship.name as shipment_name,
      gship.type as shipment_type,
      gship.status as shipment_status,
      gship.received_weight,
      coalesce(gst.description, gs.availability::text) as stock_type_description,
      (gs.availability = 'sellable'::public.stock_availability) as is_sellable,
      public.global_stock_atp_qty(gs.id) as available_atp
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.global_stock_types gst on gst.id = gs.stock_type_id
    left join public.stock_locations sl on sl.id = gs.location_id
    left join public.global_shipment_item_outcomes o on o.id = gs.outcome_id
    where gs.tenant_id = p_tenant_id
      and gs.is_archived = false
      and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
      and (
        p_is_sellable is null
        or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
        or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
      )
      and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
      and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
      and public.stock_location_matches_filter(gs.location_id, p_location_id)
      and (p_availability is null or gs.availability = p_availability)
      and (p_shipment_id is null or gsi.shipment_id = p_shipment_id)
      and (p_grade_tag_id is null or gs.grade_tag_id = p_grade_tag_id)
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
        )
      )
      and (
        p_group_by is null or p_group_key is null or p_group_key = ''
        or case p_group_by
          when 'shipment' then gsi.shipment_id::text = p_group_key
          when 'product' then coalesce(nullif(trim(gsi.product_code), ''), 'si:' || gsi.id::text) = p_group_key
          when 'location' then gs.location_id::text = p_group_key
          when 'grade' then coalesce(gs.grade_tag_id::text, '') = p_group_key
          when 'availability' then gs.availability::text = p_group_key
          else true
        end
      )
      and (p_cursor_id is null or gs.id < p_cursor_id)
    order by gs.id desc
    limit v_fetch
  ) r;

  v_n := coalesce(jsonb_array_length(v_data), 0);

  if v_n > v_limit then
    v_has_more := true;
    v_data := (
      select coalesce(jsonb_agg(elem), '[]'::jsonb)
      from (
        select elem
        from jsonb_array_elements(v_data) with ordinality as t(elem, ord)
        where ord <= v_limit
      ) s
    );
  end if;

  if coalesce(jsonb_array_length(v_data), 0) > 0 then
    v_last_id := (v_data->(jsonb_array_length(v_data) - 1)->>'id')::bigint;
    if v_has_more then
      v_next_cursor := jsonb_build_object('id', v_last_id);
    end if;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'has_more', v_has_more,
      'next_cursor', v_next_cursor,
      'total', v_total
    )
  );
end;
$function$;

-- list_global_stocks_groups

CREATE OR REPLACE FUNCTION public.list_global_stocks_groups (
  p_tenant_id       bigint,
  p_group_by        text,
  p_limit           integer                   DEFAULT 50,
  p_offset          integer                   DEFAULT 0,
  p_search          text                      DEFAULT NULL::text,
  p_stock_type_id   bigint                    DEFAULT NULL::bigint,
  p_is_sellable     boolean                   DEFAULT NULL::boolean,
  p_shipment_status text                      DEFAULT NULL::text,
  p_hide_zero_stock boolean                   DEFAULT true,
  p_location_id     bigint                    DEFAULT NULL::bigint,
  p_availability    public.stock_availability DEFAULT NULL::public.stock_availability,
  p_shipment_id     bigint                    DEFAULT NULL::bigint,
  p_grade_tag_id    bigint                    DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 200));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_groups jsonb;
  v_total bigint;
  v_has_more boolean;
begin
  if not public._can_view_parent_warehouse_stock(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  if p_group_by is null or p_group_by not in ('shipment', 'product', 'location', 'grade', 'availability') then
    raise exception 'invalid p_group_by';
  end if;

  with filtered as (
    select
      gs.id,
      gs.quantity,
      gs.availability,
      gs.location_id,
      gs.grade_tag_id,
      gsi.id as shipment_item_id,
      gsi.shipment_id,
      gsi.name as item_name,
      gsi.product_code,
      gship.name as shipment_name,
      sl.name as location_name,
      tg.name as grade_name
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.stock_locations sl on sl.id = gs.location_id
    left join public.tags tg on tg.id = gs.grade_tag_id
    where gs.tenant_id = p_tenant_id
      and gs.is_archived = false
      and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
      and (
        p_is_sellable is null
        or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
        or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
      )
      and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
      and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
      and public.stock_location_matches_filter(gs.location_id, p_location_id)
      and (p_availability is null or gs.availability = p_availability)
      and (p_shipment_id is null or gsi.shipment_id = p_shipment_id)
      and (p_grade_tag_id is null or gs.grade_tag_id = p_grade_tag_id)
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
        )
      )
  ),
  keyed as (
    select
      case p_group_by
        when 'shipment' then f.shipment_id::text
        when 'product' then coalesce(nullif(trim(f.product_code), ''), 'si:' || f.shipment_item_id::text)
        when 'location' then coalesce(f.location_id::text, '')
        when 'grade' then coalesce(f.grade_tag_id::text, '')
        when 'availability' then f.availability::text
      end as key,
      case p_group_by
        when 'shipment' then coalesce(f.shipment_name, 'Shipment')
        when 'product' then coalesce(nullif(trim(f.product_code), ''), f.item_name, 'Product')
        when 'location' then coalesce(f.location_name, 'No location')
        when 'grade' then coalesce(f.grade_name, 'Standard')
        when 'availability' then initcap(f.availability::text)
      end as label,
      f.quantity
    from filtered f
  ),
  agg as (
    select
      key,
      max(label) as label,
      sum(quantity)::bigint as quantity,
      count(*)::bigint as lot_count
    from keyed
    where key is not null and key <> ''
    group by key
  ),
  counted as (
    select count(*)::bigint as total from agg
  )
  select
    (select total from counted),
    coalesce(
      (
        select jsonb_agg(row_to_json(g))
        from (
          select key, label, quantity, lot_count
          from agg
          order by quantity desc, label asc
          limit v_limit + 1
          offset v_offset
        ) g
      ),
      '[]'::jsonb
    )
  into v_total, v_groups;

  if coalesce(jsonb_array_length(v_groups), 0) > v_limit then
    v_has_more := true;
    v_groups := (
      select coalesce(jsonb_agg(elem), '[]'::jsonb)
      from (
        select elem
        from jsonb_array_elements(v_groups) with ordinality as t(elem, ord)
        where ord <= v_limit
      ) s
    );
  else
    v_has_more := false;
  end if;

  return jsonb_build_object(
    'groups', v_groups,
    'meta', jsonb_build_object(
      'total', v_total,
      'has_more', v_has_more
    )
  );
end;
$function$;

-- list_global_stocks_paginated

CREATE OR REPLACE FUNCTION public.list_global_stocks_paginated (
  p_tenant_id       bigint,
  p_page            integer                   DEFAULT 1,
  p_page_size       integer                   DEFAULT 20,
  p_search          text                      DEFAULT NULL::text,
  p_stock_type_id   bigint                    DEFAULT NULL::bigint,
  p_is_sellable     boolean                   DEFAULT NULL::boolean,
  p_shipment_status text                      DEFAULT NULL::text,
  p_hide_zero_stock boolean                   DEFAULT true,
  p_location_id     bigint                    DEFAULT NULL::bigint,
  p_availability    public.stock_availability DEFAULT NULL::public.stock_availability,
  p_shipment_id     bigint                    DEFAULT NULL::bigint,
  p_grade_tag_id    bigint                    DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  if not public._can_view_parent_warehouse_stock(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  select count(*)
  into v_total_count
  from public.global_stocks gs
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.global_stock_types gst on gst.id = gs.stock_type_id
  where gs.tenant_id = p_tenant_id
    and gs.is_archived = false
    and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
    and (
      p_is_sellable is null
      or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
      or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
    )
    and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
    and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
    and public.stock_location_matches_filter(gs.location_id, p_location_id)
    and (p_availability is null or gs.availability = p_availability)
    and (p_shipment_id is null or gsi.shipment_id = p_shipment_id)
    and (p_grade_tag_id is null or gs.grade_tag_id = p_grade_tag_id)
    and (
      p_search is null or p_search = '' or (
        gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or gship.name ilike '%' || p_search || '%'
      )
    );

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id,
      gs.tenant_id,
      gs.shipment_item_id,
      gs.stock_type_id,
      gs.quantity,
      gs.is_usable,
      gs.availability,
      gs.location_id,
      gs.grade_tag_id,
      gs.outcome_id,
      sl.name as location_name,
      o.kind as outcome_kind,
      o.reason as outcome_reason,
      gsi.shipment_id,
      gsi.ordered_quantity,
      gsi.name as item_name,
      gsi.product_code,
      gsi.barcode,
      gsi.image_url,
      gsi.purchase_price,
      gsi.product_weight,
      gsi.package_weight,
      gsi.landed_cost_bdt,
      coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) as resolved_landed_cost_bdt,
      gship.name as shipment_name,
      gship.type as shipment_type,
      gship.status as shipment_status,
      gship.received_weight,
      coalesce(gst.description, gs.availability::text) as stock_type_description,
      (gs.availability = 'sellable'::public.stock_availability) as is_sellable,
      public.global_stock_atp_qty(gs.id) as available_atp
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.global_stock_types gst on gst.id = gs.stock_type_id
    left join public.stock_locations sl on sl.id = gs.location_id
    left join public.global_shipment_item_outcomes o on o.id = gs.outcome_id
    where gs.tenant_id = p_tenant_id
      and gs.is_archived = false
      and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
      and (
        p_is_sellable is null
        or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
        or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
      )
      and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
      and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
      and public.stock_location_matches_filter(gs.location_id, p_location_id)
      and (p_availability is null or gs.availability = p_availability)
      and (p_shipment_id is null or gsi.shipment_id = p_shipment_id)
      and (p_grade_tag_id is null or gs.grade_tag_id = p_grade_tag_id)
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
        )
      )
    order by gs.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_global_stocks_paginated (
  p_tenant_id       bigint,
  p_page            integer                   DEFAULT 1,
  p_page_size       integer                   DEFAULT 20,
  p_search          text                      DEFAULT NULL::text,
  p_stock_type_id   bigint                    DEFAULT NULL::bigint,
  p_is_sellable     boolean                   DEFAULT NULL::boolean,
  p_shipment_status text                      DEFAULT NULL::text,
  p_hide_zero_stock boolean                   DEFAULT true,
  p_location_id     bigint                    DEFAULT NULL::bigint,
  p_availability    public.stock_availability DEFAULT NULL::public.stock_availability
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  if not public._can_view_parent_warehouse_stock(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  select count(*)
  into v_total_count
  from public.global_stocks gs
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.global_stock_types gst on gst.id = gs.stock_type_id
  where gs.tenant_id = p_tenant_id
    and gs.is_archived = false
    and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
    and (p_availability is null or gs.availability = p_availability)
    and (
      p_is_sellable is null
      or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
      or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
    )
    and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
    and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
    and (p_location_id is null or gs.location_id = p_location_id)
    and (
      p_search is null or p_search = '' or (
        gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or gship.name ilike '%' || p_search || '%'
      )
    );

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id,
      gs.tenant_id,
      gs.shipment_item_id,
      gs.stock_type_id,
      gs.quantity,
      gs.is_usable,
      gs.availability,
      gs.location_id,
      sl.name as location_name,
      gsi.shipment_id,
      gsi.ordered_quantity,
      gsi.name as item_name,
      gsi.product_code,
      gsi.barcode,
      gsi.image_url,
      gsi.purchase_price,
      gsi.product_weight,
      gsi.package_weight,
      gsi.landed_cost_bdt,
      coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) as resolved_landed_cost_bdt,
      gship.name as shipment_name,
      gship.type as shipment_type,
      gship.status as shipment_status,
      gship.received_weight,
      gst.description as stock_type_description,
      coalesce(gst.is_sellable, gs.availability = 'sellable') as is_sellable,
      public.global_stock_atp_qty(gs.id) as available_atp
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.global_stock_types gst on gst.id = gs.stock_type_id
    left join public.stock_locations sl on sl.id = gs.location_id
    left join public.global_shipment_item_outcomes o on o.id = gs.outcome_id
    where gs.tenant_id = p_tenant_id
      and gs.is_archived = false
      and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
      and (p_availability is null or gs.availability = p_availability)
      and (
        p_is_sellable is null
        or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
        or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
      )
      and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
      and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
      and (p_location_id is null or gs.location_id = p_location_id)
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
        )
      )
    order by gs.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$function$;

-- list_shipment_items_for_shipments

CREATE OR REPLACE FUNCTION public.list_shipment_items_for_shipments (
  p_shipment_ids bigint[]
)
  RETURNS TABLE (
    shipment_id      bigint,
    purchase_price   numeric,
    product_weight   numeric,
    package_weight   numeric,
    ordered_quantity integer
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if p_shipment_ids is null or array_length(p_shipment_ids, 1) is null or array_length(p_shipment_ids, 1) = 0 then
    return;
  end if;

  return query
  select
    gsi.shipment_id,
    gsi.purchase_price,
    gsi.product_weight,
    gsi.package_weight,
    gsi.ordered_quantity
  from public.global_shipment_items gsi
  inner join public.global_shipments gs on gs.id = gsi.shipment_id
  where gsi.shipment_id = any(p_shipment_ids)
    and (
      public.user_can_manage_parent_tenant(gs.tenant_id)
      or exists (
        select 1 from public.memberships m
        where m.tenant_id = gs.tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.is_active = true
      )
    )
  order by gsi.shipment_id, gsi.sort_order, gsi.id;
end;
$function$;

-- list_shipment_outcome_vendor_credits

CREATE OR REPLACE FUNCTION public.list_shipment_outcome_vendor_credits (
  p_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent bigint;
begin
  select tenant_id into v_parent
  from public.global_shipments
  where id = p_shipment_id;

  if v_parent is null then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_parent) then
    raise exception 'not allowed';
  end if;

  return coalesce(
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
  );
end;
$function$;

-- list_shipment_payee_settlements

CREATE OR REPLACE FUNCTION public.list_shipment_payee_settlements (
  p_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
BEGIN
  SELECT * INTO v_ship
  FROM public.global_shipments
  WHERE id = p_shipment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.has_active_tenant_membership(v_ship.tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  RETURN jsonb_build_object(
    'vendor', public.get_payee_settlement_summary(v_ship.tenant_id, p_shipment_id, 'vendor', v_ship.vendor_id),
    'cargo_company', public.get_payee_settlement_summary(v_ship.tenant_id, p_shipment_id, 'cargo_company', v_ship.cargo_company_id)
  );
END;
$function$;

-- lock_global_shipment_costs

CREATE OR REPLACE FUNCTION public.lock_global_shipment_costs (
  p_shipment_id bigint
)
  RETURNS public.global_shipments
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.status not in ('in_transit', 'received') then
    raise exception 'Set shipment to in transit or received before locking costs';
  end if;

  if not public.global_shipment_stock_is_posted(v_ship) then
    raise exception 'shipment stock is not posted; receive before locking costs';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are already locked';
  end if;

  perform set_config('app.allow_costs_lock', '1', true);

  update public.global_shipments
  set costs_locked = true,
      costs_locked_at = now(),
      costs_locked_by = auth.uid(),
      updated_at = now()
  where id = p_shipment_id
  returning * into v_ship;

  perform public.sync_shipment_ap_bills(p_shipment_id);

  perform set_config('app.shipment_ap_issue', '1', true);
  perform public.issue_shipment_ap_bills(p_shipment_id);
  perform set_config('app.shipment_ap_issue', '0', true);

  return v_ship;
end;
$function$;

-- migrate_legacy_inventory_to_global_stock

CREATE OR REPLACE FUNCTION public.migrate_legacy_inventory_to_global_stock (
  p_tenant_id bigint DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_item record;
  v_stock_id bigint;
  v_parent_id bigint;
  v_migrated integer := 0;
begin
  for v_item in
    select ii.*
    from public.inventory_items ii
    where (p_tenant_id is null or ii.tenant_id = p_tenant_id)
      and not exists (
        select 1 from public.global_stocks gs
        where gs.legacy_inventory_item_id = ii.id
      )
  loop
    v_parent_id := public.resolve_parent_tenant_id(v_item.tenant_id);

    insert into public.global_stocks (
      tenant_id,
      tenant_id,
      name,
      cost,
      image_url,
      product_code,
      barcode,
      product_id,
      source_module,
      source_type,
      source_id,
      legacy_inventory_item_id
    )
    values (
      v_parent_id,
      v_parent_id,
      v_item.name,
      coalesce(v_item.cost, 0),
      v_item.image_url,
      v_item.product_code,
      v_item.barcode,
      v_item.product_id,
      'wholesale',
      coalesce(v_item.source_type, 'migration'),
      v_item.source_id,
      v_item.id
    )
    returning id into v_stock_id;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'excellent', coalesce(s.available_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.available_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'box_less', coalesce(s.open_box_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.open_box_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'expired', coalesce(s.expired_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.expired_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'stolen', coalesce(s.stolen_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.stolen_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    v_migrated := v_migrated + 1;
  end loop;

  return jsonb_build_object('migrated_count', v_migrated);
end;
$function$;

-- post_shipment_outcome_stock

CREATE OR REPLACE FUNCTION public.post_shipment_outcome_stock (
  p_shipment_id bigint,
  p_stock_rows  jsonb  DEFAULT NULL::jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_parent bigint;
BEGIN
  SELECT tenant_id INTO v_parent
  FROM public.global_shipments
  WHERE id = p_shipment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_parent_tenant(v_parent) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  RETURN public._stock_spine_receive_shipment_outcomes(p_shipment_id, p_stock_rows);
END;
$function$;

-- post_stock_movement

CREATE OR REPLACE FUNCTION public.post_stock_movement (
  p_movement_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_mov public.stock_movements%rowtype;
  v_line public.stock_movement_lines%rowtype;
  v_stock public.global_stocks%rowtype;
  v_target_stock public.global_stocks%rowtype;
  v_target_avail public.stock_availability;
  v_target_loc bigint;
  v_target_grade bigint;
  v_move_qty int;
  v_new_qty int;
begin
  select * into v_mov
  from public.stock_movements
  where id = p_movement_id
  for update;

  if not found then
    raise exception 'stock movement not found';
  end if;

  if v_mov.is_posted then
    raise exception 'stock movement already posted';
  end if;

  if not public.can_act_on_stock_movement_context(
    v_mov.tenant_id,
    v_mov.reference_type,
    v_mov.reference_id
  ) then
    raise exception 'not authorized';
  end if;

  for v_line in
    select * from public.stock_movement_lines where movement_id = p_movement_id
  loop
    if v_line.stock_id is null then
      continue;
    end if;

    select * into v_stock
    from public.global_stocks
    where id = v_line.stock_id
    for update;

    if not found then
      raise exception 'stock % not found for movement line', v_line.stock_id;
    end if;

    v_move_qty := coalesce(v_line.quantity::int, 0);
    if v_move_qty <= 0 then
      continue;
    end if;

    case v_mov.movement_type
      when 'adjustment' then
        if v_line.to_availability is not null and v_line.from_availability is null then
          v_new_qty := v_stock.quantity + v_move_qty;
        else
          v_new_qty := v_stock.quantity - v_move_qty;
        end if;

        if v_new_qty < 0 then
          raise exception 'adjustment would make stock % negative', v_line.stock_id;
        end if;

        update public.global_stocks
        set
          quantity = v_new_qty,
          location_id = coalesce(v_line.to_location_id, location_id),
          availability = coalesce(v_line.to_availability, availability),
          grade_tag_id = coalesce(v_line.to_grade_tag_id, grade_tag_id, public.default_stock_grade_tag_id()),
          updated_at = now()
        where id = v_line.stock_id;

      when 'location_transfer', 'availability_transfer', 'grade_change', 'receive_putaway' then
        v_target_avail := coalesce(v_line.to_availability, v_stock.availability);
        v_target_loc := coalesce(v_line.to_location_id, v_stock.location_id);
        v_target_grade := coalesce(v_line.to_grade_tag_id, v_stock.grade_tag_id, public.default_stock_grade_tag_id());

        if v_stock.quantity < v_move_qty then
          raise exception 'insufficient stock quantity on stock % (requested %, available %)',
            v_line.stock_id, v_move_qty, v_stock.quantity;
        end if;

        if v_target_avail = v_stock.availability
           and v_target_loc = v_stock.location_id
           and v_target_grade = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id()) then
          update public.global_stocks
          set updated_at = now()
          where id = v_stock.id;
        else
          select * into v_target_stock
          from public.global_stocks
          where shipment_item_id = v_stock.shipment_item_id
            and availability = v_target_avail
            and location_id = v_target_loc
            and grade_tag_id = v_target_grade
          for update;

          if found then
            update public.global_stocks
            set quantity = quantity + v_move_qty, updated_at = now()
            where id = v_target_stock.id;

            if v_stock.quantity = v_move_qty then
              delete from public.global_stocks where id = v_stock.id;
              update public.stock_movement_lines
              set stock_id = v_target_stock.id
              where id = v_line.id;
            else
              update public.global_stocks
              set quantity = quantity - v_move_qty, updated_at = now()
              where id = v_stock.id;
            end if;
          else
            if v_stock.quantity = v_move_qty then
              update public.global_stocks
              set
                availability = v_target_avail,
                location_id = v_target_loc,
                grade_tag_id = v_target_grade,
                updated_at = now()
              where id = v_stock.id;
            else
              insert into public.global_stocks (
                tenant_id,
                shipment_item_id,
                stock_type_id,
                quantity,
                is_usable,
                availability,
                location_id,
                grade_tag_id
              ) values (
                v_stock.tenant_id,
                v_stock.shipment_item_id,
                v_stock.stock_type_id,
                v_move_qty,
                (v_target_avail = 'sellable'::public.stock_availability),
                v_target_avail,
                v_target_loc,
                v_target_grade
              );

              update public.global_stocks
              set quantity = quantity - v_move_qty, updated_at = now()
              where id = v_stock.id;
            end if;
          end if;
        end if;

      when 'return_inbound' then
        if v_mov.reference_type = 'shipment_return' then
          v_new_qty := v_stock.quantity - v_move_qty;
          if v_new_qty < 0 then
            raise exception 'return would make stock % negative', v_line.stock_id;
          end if;
          if v_new_qty = 0 then
            delete from public.global_stocks where id = v_stock.id;
          else
            update public.global_stocks
            set quantity = v_new_qty, updated_at = now()
            where id = v_stock.id;
          end if;
        else
          v_target_avail := coalesce(v_line.to_availability, 'held'::public.stock_availability);
          v_target_loc := coalesce(
            v_line.to_location_id,
            public.default_returns_stock_location_id(v_stock.tenant_id)
          );
          v_target_grade := coalesce(
            v_line.to_grade_tag_id,
            public.default_stock_grade_tag_id()
          );

          select * into v_target_stock
          from public.global_stocks
          where shipment_item_id = v_stock.shipment_item_id
            and availability = v_target_avail
            and location_id = v_target_loc
            and grade_tag_id = v_target_grade
          for update;

          if found then
            update public.global_stocks
            set quantity = quantity + v_move_qty, updated_at = now()
            where id = v_target_stock.id;
          else
            insert into public.global_stocks (
              tenant_id,
              shipment_item_id,
              stock_type_id,
              quantity,
              is_usable,
              availability,
              location_id,
              grade_tag_id
            ) values (
              v_stock.tenant_id,
              v_stock.shipment_item_id,
              v_stock.stock_type_id,
              v_move_qty,
              (v_target_avail = 'sellable'::public.stock_availability),
              v_target_avail,
              v_target_loc,
              v_target_grade
            );
          end if;
        end if;

      when 'receive_rollback', 'vendor_return', 'issue_outbound' then
        v_new_qty := v_stock.quantity - v_move_qty;
        if v_new_qty < 0 then
          raise exception 'deduct would make stock % negative', v_line.stock_id;
        end if;
        if v_new_qty = 0 then
          delete from public.global_stocks where id = v_stock.id;
        else
          update public.global_stocks
          set quantity = v_new_qty, updated_at = now()
          where id = v_stock.id;
        end if;

      else
        raise exception 'unsupported movement type %', v_mov.movement_type;
    end case;
  end loop;

  update public.stock_movements
  set is_posted = true, posted_at = now(), updated_at = now()
  where id = p_movement_id;

  return jsonb_build_object(
    'movement_id', p_movement_id,
    'is_posted', true,
    'posted_at', now()
  );
end;
$function$;

-- purge_archived_shipment

CREATE OR REPLACE FUNCTION public.purge_archived_shipment (
  p_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.is_archived is not true then
    raise exception 'shipment must be archived before it can be permanently deleted';
  end if;

  delete from public.shop_order_item_stock_picks sp
  where sp.shipment_id = p_id
     or sp.shipment_item_id in (
       select id from public.global_shipment_items where shipment_id = p_id
     )
     or sp.global_stock_id in (
       select gs.id
       from public.global_stocks gs
       inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
       where gsi.shipment_id = p_id
     )
     or sp.held_stock_id in (
       select gs.id
       from public.global_stocks gs
       inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
       where gsi.shipment_id = p_id
     );

  update public.bill_lines bl
  set
    line_meta = bl.line_meta - 'stock_ref',
    shipment_item_id = null,
    updated_at = now()
  where bl.shipment_item_id in (
    select id from public.global_shipment_items where shipment_id = p_id
  )
  or nullif(bl.line_meta->'stock_ref'->>'global_stock_id', '')::bigint in (
    select gs.id
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    where gsi.shipment_id = p_id
  );

  update public.sales_return_items sri
  set
    global_stock_id = null,
    updated_at = now()
  where sri.global_stock_id in (
    select gs.id
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    where gsi.shipment_id = p_id
  );

  delete from public.global_shipments where id = p_id;
end;
$function$;

-- refresh_shipment_investor_profits

CREATE OR REPLACE FUNCTION public.refresh_shipment_investor_profits (
  p_global_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_shipment public.global_shipments;
  v_pnl jsonb;
  v_buy numeric(12,2);
  v_profit numeric(12,2);
  v_updated integer := 0;
  v_inv record;
  v_status text;
  v_sold_qty numeric;
  v_received_qty numeric;
  v_computed_profit numeric(12,2);
begin
  select * into v_shipment from public.global_shipments where id = p_global_shipment_id;
  if v_shipment.id is null then raise exception 'global shipment not found'; end if;

  if not public.user_can_manage_parent_tenant(v_shipment.tenant_id) then
    raise exception 'not allowed';
  end if;

  v_pnl := public.get_shipment_pnl(v_shipment.tenant_id, p_global_shipment_id);
  v_buy := coalesce((v_pnl -> 'totals' ->> 'landed_cost')::numeric, 0.00);
  v_profit := coalesce((v_pnl -> 'totals' ->> 'gross_profit')::numeric, 0.00);

  select
    coalesce(sum(ordered_quantity), 0),
    coalesce(sum(sold_qty), 0)
  into v_received_qty, v_sold_qty
  from (
    select
      si.ordered_quantity,
      coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_qty
    from public.global_shipment_items si
    left join public.global_invoice_items ii on ii.shipment_item_id = si.id
    left join public.bills inv on inv.id = ii.invoice_id and inv.invoice_status = 'issued'::public.global_invoice_status
    where si.shipment_id = p_global_shipment_id
    group by si.id, si.ordered_quantity
  ) t;

  if v_received_qty = 0 then
    v_status := 'open';
  elsif v_sold_qty >= v_received_qty then
    v_status := 'realized';
  elsif v_sold_qty > 0 then
    v_status := 'partial';
  else
    v_status := 'open';
  end if;

  for v_inv in
    select * from public.shipment_investments
    where global_shipment_id = p_global_shipment_id
      and status = 'active'
      and cost_share_pct is not null
  loop
    v_computed_profit := round(v_profit * v_inv.cost_share_pct / 100.0, 2);

    update public.shipment_investments
    set
      allocated_cost = round(v_buy * v_inv.cost_share_pct / 100.0, 2),
      computed_profit = v_computed_profit,
      profit_status = v_status
    where id = v_inv.id;

    -- Update investor pending profit bucket if profit is realized
    if v_computed_profit > 0 and v_status = 'realized' then
      if not exists (
        select 1 from public.cashbook_entries
        where tenant_id = v_shipment.tenant_id
          and entity_type = 'investor'
          and entity_id = v_inv.investor_id
          and source_type = 'vendor_purchase'
          and source_id = p_global_shipment_id::text
          and metadata->>'purpose' = 'shipment_investor_profit'
      ) then
        perform public.record_ledger_transaction(
          p_parent_tenant_id => v_shipment.tenant_id, p_operating_tenant_id => coalesce(v_shipment.assigned_child_tenant_id, v_shipment.tenant_id),
          p_entity_type => 'investor',
          p_entity_id => v_inv.investor_id,
          p_type => 'credit',
          p_amount => v_computed_profit,
          p_currency_code => 'BDT',
          p_exchange_rate => 1.000000,
          p_source_type => 'vendor_purchase',
          p_source_id => p_global_shipment_id::text,
          p_metadata => jsonb_build_object(
            'section', 'investor_capital',
            'purpose', 'shipment_investor_profit',
            'transaction_type', 'profit_accrued',
            'label', 'Shipment Profit Distribution',
            'shipment_id', p_global_shipment_id
          ),
          p_target_bucket => 'pending'
        );
      end if;
    end if;

    v_updated := v_updated + 1;
  end loop;

  return jsonb_build_object(
    'global_shipment_id', p_global_shipment_id,
    'updated_count', v_updated,
    'buy_cost_total', v_buy,
    'profit_total', v_profit,
    'profit_status', v_status
  );
end;
$function$;

-- reorder_shipment_sections

CREATE OR REPLACE FUNCTION public.reorder_shipment_sections (
  p_shipment_id bigint,
  p_section_ids bigint[]
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments;
  v_idx integer;
  v_section_id bigint;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_section_ids is null or array_length(p_section_ids, 1) is null then
    return;
  end if;

  for v_idx in 1..array_length(p_section_ids, 1) loop
    v_section_id := p_section_ids[v_idx];

    update public.global_shipment_sections
    set sort_order = v_idx - 1,
        updated_at = now()
    where id = v_section_id
      and shipment_id = p_shipment_id;
  end loop;
end;
$function$;

-- restamp_global_shipment_on_hand

CREATE OR REPLACE FUNCTION public.restamp_global_shipment_on_hand (
  p_shipment_id bigint DEFAULT NULL::bigint,
  p_outcome_id  bigint DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_parent bigint;
  v_on_hand int;
  r_out record;
  v_updated int := 0;
begin
  if p_outcome_id is not null then
    select gsi.shipment_id into p_shipment_id
    from public.global_shipment_item_outcomes o
    inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
    where o.id = p_outcome_id;
  end if;

  if p_shipment_id is null then
    raise exception 'shipment_id or outcome_id required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  v_parent := v_ship.tenant_id;
  if not public.user_can_manage_parent_tenant(v_parent) then
    raise exception 'not allowed';
  end if;

  if coalesce(v_ship.is_closed, false) then
    raise exception 'shipment is closed';
  end if;

  perform public.stamp_global_shipment_landed_costs(p_shipment_id);
  perform public._stamp_global_shipment_outcome_costs(p_shipment_id);

  for r_out in
    select o.*
    from public.global_shipment_item_outcomes o
    inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
    where gsi.shipment_id = p_shipment_id
      and o.reason <> 'ordered'::public.global_shipment_outcome_reason
      and (p_outcome_id is null or o.id = p_outcome_id)
  loop
    select coalesce(sum(gs.quantity), 0)::int
    into v_on_hand
    from public.global_stocks gs
    where gs.outcome_id = r_out.id;

    if v_on_hand > r_out.quantity then
      raise exception 'outcome qty % below on-hand % for outcome %', r_out.quantity, v_on_hand, r_out.id;
    end if;

    v_updated := v_updated + 1;
  end loop;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'outcomes_checked', v_updated
  );
end;
$function$;

-- return_shipment_to_vendor

CREATE OR REPLACE FUNCTION public.return_shipment_to_vendor (
  p_shipment_id bigint,
  p_items_qty   jsonb,
  p_outcome     text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_item jsonb;
  v_stock_id bigint;
  v_shipment_item_id bigint;
  v_qty numeric;
  v_mov_id bigint;
  v_amount numeric := 0;
  v_ledger jsonb;
  v_vendor_id bigint;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if v_ship.status is distinct from 'received' then
    raise exception 'shipment must be received before return';
  end if;

  if p_outcome not in ('cash_refund', 'store_credit') then
    raise exception 'outcome must be cash_refund or store_credit';
  end if;

  if not public.has_active_tenant_membership(v_ship.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  v_vendor_id := v_ship.vendor_id;

  insert into public.stock_movements (
    tenant_id, movement_no, movement_type, reference_type, reference_id, notes, created_by_email
  ) values (
    v_ship.tenant_id,
    'VR-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('stock_movements_id_seq')::text, 6, '0'),
    'vendor_return'::public.stock_movement_type,
    'shipment_return',
    p_shipment_id::text,
    'Vendor return outcome: ' || p_outcome,
    public.current_user_email()
  )
  returning id into v_mov_id;

  for v_item in select value from jsonb_array_elements(coalesce(p_items_qty, '[]'::jsonb))
  loop
    v_stock_id := (v_item->>'global_stock_id')::bigint;
    v_shipment_item_id := (v_item->>'shipment_item_id')::bigint;
    v_qty := coalesce((v_item->>'quantity')::numeric, 0);

    if v_stock_id is null and v_shipment_item_id is not null then
      select gs.id into v_stock_id
      from public.global_stocks gs
      join public.global_stock_types gst on gst.id = gs.stock_type_id
      where gs.shipment_item_id = v_shipment_item_id
        and gs.tenant_id = v_ship.tenant_id
        and gst.is_sellable = true
        and gs.availability = 'sellable'::public.stock_availability
      order by gs.quantity desc, gs.id
      limit 1;
    end if;

    if v_stock_id is null or v_qty <= 0 then
      continue;
    end if;

    insert into public.stock_movement_lines (
      movement_id, stock_id, quantity, from_availability, to_availability
    ) values (
      v_mov_id, v_stock_id, v_qty, 'sellable'::public.stock_availability, 'held'::public.stock_availability
    );

    v_amount := v_amount + (v_qty * coalesce(
      (select gsi.landed_cost_bdt from public.global_stocks gs
       join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
       where gs.id = v_stock_id),
      0
    ));
  end loop;

  perform public.post_stock_movement(v_mov_id);

  if v_amount <= 0 then
    v_amount := coalesce((
      select sum(coalesce(e.amount, 0))
      from public.global_shipment_cost_entries e
      where e.shipment_id = p_shipment_id and e.cost_bucket = 'material'::public.global_shipment_cost_bucket
    ), 0);
  end if;

  if p_outcome = 'cash_refund' then
    v_ledger := public.record_ledger_transaction(
      p_parent_tenant_id => v_ship.tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => v_ship.tenant_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_source_type => 'shipment_return',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object('outcome', 'cash_refund', 'movement_id', v_mov_id)
    );
    if v_vendor_id is not null then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_ship.tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.tenant_id),
        p_entity_type => 'vendor',
        p_entity_id => v_vendor_id,
        p_type => 'debit',
        p_amount => v_amount,
        p_currency_code => 'BDT',
        p_source_type => 'shipment_return',
        p_source_id => p_shipment_id::text,
        p_metadata => jsonb_build_object('outcome', 'cash_refund', 'movement_id', v_mov_id)
      );
    end if;
  else
    v_ledger := public.record_ledger_transaction(
      p_parent_tenant_id => v_ship.tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.tenant_id),
      p_entity_type => 'vendor',
      p_entity_id => v_vendor_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_source_type => 'shipment_return',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object('outcome', 'store_credit', 'movement_id', v_mov_id)
    );
  end if;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'outcome', p_outcome,
    'movement_id', v_mov_id,
    'return_processed', true,
    'wallet_posted', true,
    'amount_bdt', v_amount
  );
end;
$function$;

-- revise_global_shipment_costs

CREATE OR REPLACE FUNCTION public.revise_global_shipment_costs (
  p_shipment_id bigint,
  p_entries     jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_entry jsonb;
  v_stamped integer;
  v_old_costs jsonb;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if not public.global_shipment_stock_is_posted(v_ship) then
    raise exception 'shipment not finalized; use upsert_global_shipment_cost_entry';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are locked';
  end if;

  if p_entries is null or jsonb_typeof(p_entries) <> 'array' or jsonb_array_length(p_entries) = 0 then
    raise exception 'p_entries must be a non-empty array';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', e.id,
    'cost_bucket', e.cost_bucket,
    'cost_component', e.cost_component,
    'amount', e.amount,
    'landed_snapshot', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'item_id', i.id,
        'landed_cost_bdt', i.landed_cost_bdt
      )), '[]'::jsonb)
      from public.global_shipment_items i
      where i.shipment_id = p_shipment_id
    )
  )), '[]'::jsonb)
  into v_old_costs
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id;

  -- Replace all entries for this shipment with the provided set
  delete from public.global_shipment_cost_entries where shipment_id = p_shipment_id;

  for v_entry in select value from jsonb_array_elements(p_entries)
  loop
    insert into public.global_shipment_cost_entries (
      tenant_id,
      shipment_id,
      cost_bucket,
      cost_component,
      is_capitalizable,
      amount,
      currency_id,
      metadata
    ) values (
      v_ship.tenant_id,
      p_shipment_id,
      (v_entry->>'cost_bucket')::public.global_shipment_cost_bucket,
      (v_entry->>'cost_component')::public.global_shipment_cost_component,
      coalesce((v_entry->>'is_capitalizable')::boolean, true),
      (v_entry->>'amount')::numeric,
      nullif(v_entry->>'currency_id', '')::bigint,
      coalesce(v_entry->'metadata', '{}'::jsonb)
    );
  end loop;

  -- Re-stamp only — no wallet delta, no invoice line rewrite
  v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'items_stamped', v_stamped,
    'prior_entries', v_old_costs,
    'wallet_posted', false
  );
end;
$function$;

-- revoke_shipment_tracking_token

CREATE OR REPLACE FUNCTION public.revoke_shipment_tracking_token (
  p_shipment_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.has_active_tenant_membership(v_ship.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  update public.global_shipments
  set public_tracking_token = null, updated_at = now()
  where id = p_shipment_id;
end;
$function$;

-- save_global_shipment_cost_entries

CREATE OR REPLACE FUNCTION public.save_global_shipment_cost_entries (
  p_shipment_id     bigint,
  p_entries         jsonb,
  p_delete_ids      bigint[] DEFAULT '{}'::bigint[],
  p_received_weight numeric  DEFAULT NULL::numeric,
  p_total_weight_kg numeric  DEFAULT NULL::numeric
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_entry jsonb;
  v_row public.global_shipment_cost_entries%rowtype;
  v_id bigint;
  v_amount numeric;
  v_stamped integer := 0;
  v_cost_entries jsonb;
  v_items jsonb;
  v_cost_bucket public.global_shipment_cost_bucket;
  v_cost_component public.global_shipment_cost_component;
  v_is_capitalizable boolean;
  v_description text;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are locked';
  end if;

  perform set_config('app.skip_shipment_landed_restamp', '1', true);

  if p_received_weight is not null or p_total_weight_kg is not null then
    update public.global_shipments
    set
      received_weight = coalesce(p_received_weight, received_weight),
      total_weight_kg = coalesce(p_total_weight_kg, total_weight_kg),
      updated_at = now()
    where id = p_shipment_id
    returning * into v_ship;
  end if;

  if p_delete_ids is not null and cardinality(p_delete_ids) > 0 then
    delete from public.global_shipment_cost_entries e
    where e.shipment_id = p_shipment_id
      and e.id = any(p_delete_ids);
  end if;

  if p_entries is not null and jsonb_typeof(p_entries) = 'array' then
    for v_entry in select value from jsonb_array_elements(p_entries)
    loop
      v_amount := nullif(v_entry->>'amount', '')::numeric;
      v_id := nullif(v_entry->>'id', '')::bigint;

      if v_amount is null or v_amount < 0 then
        raise exception 'amount must be >= 0';
      end if;

      v_cost_bucket := nullif(v_entry->>'cost_bucket', '')::public.global_shipment_cost_bucket;
      v_cost_component := nullif(v_entry->>'cost_component', '')::public.global_shipment_cost_component;
      if v_cost_bucket is null or v_cost_component is null then
        raise exception 'cost_bucket and cost_component are required';
      end if;

      v_is_capitalizable := case
        when v_entry ? 'is_capitalizable' then (v_entry->>'is_capitalizable')::boolean
        else null
      end;
      v_description := nullif(trim(v_entry->>'description'), '');

      if v_id is not null then
        update public.global_shipment_cost_entries e
        set
          cost_bucket = v_cost_bucket,
          cost_component = v_cost_component,
          is_capitalizable = coalesce(v_is_capitalizable, e.is_capitalizable),
          description = coalesce(v_description, e.description),
          amount = v_amount,
          currency_id = nullif(v_entry->>'currency_id', '')::bigint,
          metadata = coalesce(v_entry->'metadata', '{}'::jsonb),
          section_id = nullif(v_entry->>'section_id', '')::bigint,
          updated_at = now()
        where e.id = v_id
          and e.shipment_id = p_shipment_id
        returning * into v_row;

        if not found then
          raise exception 'cost entry % not found on shipment %', v_id, p_shipment_id;
        end if;
      else
        insert into public.global_shipment_cost_entries (
          tenant_id,
          shipment_id,
          cost_bucket,
          cost_component,
          is_capitalizable,
          description,
          amount,
          currency_id,
          metadata,
          section_id
        ) values (
          v_ship.tenant_id,
          p_shipment_id,
          v_cost_bucket,
          v_cost_component,
          coalesce(v_is_capitalizable, true),
          v_description,
          v_amount,
          nullif(v_entry->>'currency_id', '')::bigint,
          coalesce(v_entry->'metadata', '{}'::jsonb),
          nullif(v_entry->>'section_id', '')::bigint
        )
        returning * into v_row;
      end if;
    end loop;
  end if;

  perform set_config('app.skip_shipment_landed_restamp', '0', true);

  if exists (select 1 from public.global_shipment_items where shipment_id = p_shipment_id) then
    v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);
  end if;

  select coalesce(jsonb_agg(to_jsonb(e) order by e.id), '[]'::jsonb)
  into v_cost_entries
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id;

  select coalesce(jsonb_agg(to_jsonb(i) order by i.sort_order, i.id), '[]'::jsonb)
  into v_items
  from public.global_shipment_items i
  where i.shipment_id = p_shipment_id;

  return jsonb_build_object(
    'cost_entries', v_cost_entries,
    'items', v_items,
    'items_stamped', v_stamped,
    'shipment', jsonb_build_object(
      'id', v_ship.id,
      'received_weight', v_ship.received_weight,
      'total_weight_kg', v_ship.total_weight_kg,
      'updated_at', v_ship.updated_at
    )
  );
end;
$function$;

-- set_shipment_progress_flow

CREATE OR REPLACE FUNCTION public.set_shipment_progress_flow (
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

-- set_shipment_progress_stage

CREATE OR REPLACE FUNCTION public.set_shipment_progress_stage (
  p_shipment_id bigint,
  p_tag_id      bigint DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_tag public.tags%rowtype;
  v_progress jsonb := null;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.has_active_tenant_membership(v_ship.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_tag_id is null then
    update public.global_shipments
    set progress_tag_id = null, updated_at = now()
    where id = p_shipment_id;

    return jsonb_build_object(
      'shipment_id', p_shipment_id,
      'progress_tag', null
    );
  end if;

  select * into v_tag from public.tags where id = p_tag_id;
  if not found then
    raise exception 'tag not found';
  end if;

  if v_tag.group_name is distinct from 'shipment_progress' then
    raise exception 'tag must be in group shipment_progress';
  end if;

  if not exists (
    select 1
    from public.shipment_progress_flow_stages s
    where s.flow_id = v_ship.progress_flow_id
      and s.tag_id = p_tag_id
  ) then
    raise exception 'tag does not belong to shipment flow';
  end if;

  update public.global_shipments
  set progress_tag_id = p_tag_id, updated_at = now()
  where id = p_shipment_id;

  v_progress := jsonb_build_object(
    'id', v_tag.id,
    'name', v_tag.name,
    'slug', v_tag.slug,
    'group_name', v_tag.group_name,
    'sort_order', v_tag.sort_order,
    'color', v_tag.color
  );

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'progress_tag', v_progress
  );
end;
$function$;

-- sync_shipment_ap_bills

CREATE OR REPLACE FUNCTION public.sync_shipment_ap_bills (
  p_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments;
  v_parent bigint;
  v_issued_by bigint;
  v_vendor_profile bigint;
  v_cargo_profile bigint;
  v_local_profile bigint;
  v_tenant_name text;
  v_bucket public.global_shipment_cost_bucket;
  v_bucket_text text;
  v_paper jsonb;
  v_amt numeric(12, 2);
  v_profile bigint;
  v_bill_id bigint;
  v_bills jsonb := '{}'::jsonb;
  v_keep_as_draft boolean := false;
  v_void_id bigint;
  v_groups jsonb;
  v_grp jsonb;
  v_ccy text;
  v_plug_key text;
  v_group_count int;
  v_slice jsonb;
  v_active_keys text[] := '{}';
  v_elem jsonb;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  perform public._shipment_money_advisory_lock(p_shipment_id);

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  v_parent := v_ship.tenant_id;
  v_issued_by := coalesce(v_ship.assigned_child_tenant_id, v_parent);

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  if v_ship.vendor_id is not null then
    select pr.id into v_vendor_profile
    from public.profiles pr
    where pr.parent_tenant_id = v_parent
      and pr.profile_type = 'vendor'::public.profile_party_type
      and pr.subject_id = v_ship.vendor_id;
  end if;

  if v_ship.cargo_company_id is not null then
    select pr.id into v_cargo_profile
    from public.profiles pr
    where pr.parent_tenant_id = v_parent
      and pr.profile_type = 'cargo'::public.profile_party_type
      and pr.subject_id = v_ship.cargo_company_id;
  end if;

  select t.name into v_tenant_name from public.tenants t where t.id = v_parent;

  v_local_profile := public.upsert_profile_for_party(
    v_parent,
    'company'::public.profile_party_type,
    v_parent,
    coalesce(v_tenant_name, 'Local opex'),
    null, null, '+880', null, false, null, true, null
  );

  v_keep_as_draft := not coalesce(v_ship.costs_locked, false);

  if v_ship.status = 'cancelled' then
    for v_void_id in
      select b.id
      from public.bills b
      where b.parent_tenant_id = v_parent
        and b.ap_shipment_id = p_shipment_id
        and b.invoice_type = 'ap'::public.global_invoice_type
        and b.document_kind = 'standard'::public.bill_document_kind
        and b.invoice_status in (
          'issued'::public.global_invoice_status,
          'draft'::public.global_invoice_status
        )
        and coalesce(b.paid_amount, 0) = 0
      order by b.id asc
    loop
      perform public.void_bill(v_void_id);
    end loop;
    return jsonb_build_object('success', true, 'cancelled', true);
  end if;

  foreach v_bucket_text in array enum_range(null::public.global_shipment_cost_bucket)::text[]
  loop
    v_bucket := v_bucket_text::public.global_shipment_cost_bucket;
    v_paper := public._build_shipment_ap_bucket_paper(p_shipment_id, v_ship, v_bucket);
    v_groups := coalesce(v_paper->'currency_groups', '[]'::jsonb);
    v_group_count := jsonb_array_length(v_groups);

    v_profile := case v_bucket
      when 'material'::public.global_shipment_cost_bucket then v_vendor_profile
      when 'freight'::public.global_shipment_cost_bucket then v_cargo_profile
      when 'customs'::public.global_shipment_cost_bucket then v_cargo_profile
      else v_local_profile
    end;

    if v_group_count = 0 then
      for v_void_id in
        select b.id
        from public.bills b
        where b.parent_tenant_id = v_parent
          and b.source_type = 'shipment_cost'
          and b.source_id = p_shipment_id::text
          and b.invoice_type = 'ap'::public.global_invoice_type
          and b.document_kind = 'standard'::public.bill_document_kind
          and b.invoice_status in (
            'issued'::public.global_invoice_status,
            'draft'::public.global_invoice_status
          )
          and coalesce(b.paid_amount, 0) = 0
          and (
            b.source_key = v_bucket::text
            or b.source_key like v_bucket::text || ':%'
          )
        order by b.id asc
      loop
        perform public.void_bill(v_void_id);
      end loop;
      continue;
    end if;

    for v_elem in select value from jsonb_array_elements(v_groups)
    loop
      v_grp := v_elem;
      v_ccy := upper(trim(coalesce(v_grp->>'currency_code', 'BDT')));
      v_plug_key := case
        when v_group_count > 1 then v_bucket::text || ':' || v_ccy
        else v_bucket::text
      end;
      v_amt := round(coalesce((v_grp->>'foreign_total')::numeric, 0), 2);
      v_slice := v_paper
        || jsonb_build_object(
          'foreign_total', v_grp->>'foreign_total',
          'currency_code', v_ccy,
          'currency_symbol', v_grp->>'currency_symbol',
          'currency_groups', jsonb_build_array(v_grp),
          'mixed_currencies', false,
          'lines', coalesce(v_grp->'lines', '[]'::jsonb)
        );

      if coalesce(v_amt, 0) <= 0 or v_profile is null then
        v_bill_id := public._upsert_shipment_ap_bill(
          v_parent,
          v_issued_by,
          p_shipment_id,
          v_ship.name,
          v_bucket::text,
          v_profile,
          v_amt,
          v_slice,
          v_keep_as_draft,
          v_plug_key
        );
      else
        select u.id
        into v_bill_id
        from public.upsert_draft_bill(
          jsonb_build_object(
            'tenant_id', v_issued_by,
            'adapter', 'shipment_cost',
            'parent_tenant_id', v_parent,
            'issued_by_tenant_id', v_issued_by,
            'shipment_id', p_shipment_id,
            'shipment_name', v_ship.name,
            'ap_kind', v_bucket::text,
            'profile_id', v_profile,
            'amount', v_amt,
            'ap_paper', v_slice,
            'keep_as_draft', v_keep_as_draft,
            'source_key', v_plug_key
          )
        ) u;
      end if;

      if v_bill_id is not null then
        v_active_keys := array_append(v_active_keys, v_plug_key);
        v_bills := v_bills || jsonb_build_object(v_plug_key, v_bill_id);
      end if;
    end loop;
  end loop;

  for v_void_id in
    select b.id
    from public.bills b
    where b.parent_tenant_id = v_parent
      and b.source_type = 'shipment_cost'
      and b.source_id = p_shipment_id::text
      and b.invoice_type = 'ap'::public.global_invoice_type
      and b.document_kind = 'standard'::public.bill_document_kind
      and b.invoice_status in (
        'draft'::public.global_invoice_status,
        'issued'::public.global_invoice_status
      )
      and coalesce(b.paid_amount, 0) = 0
      and b.source_key is not null
      and not (b.source_key = any(v_active_keys))
    order by b.id asc
  loop
    perform public.void_bill(v_void_id);
  end loop;

  for v_void_id in
    select b.id
    from public.bills b
    where b.parent_tenant_id = v_parent
      and b.ap_shipment_id = p_shipment_id
      and b.invoice_type = 'ap'::public.global_invoice_type
      and b.document_kind = 'standard'::public.bill_document_kind
      and b.ap_kind in ('vendor', 'cargo', 'local')
      and b.invoice_status = 'issued'::public.global_invoice_status
      and coalesce(b.paid_amount, 0) = 0
    order by b.id asc
  loop
    perform public.void_bill(v_void_id);
  end loop;

  return jsonb_build_object('success', true, 'bills', v_bills);
end;
$function$;

-- trg_sync_catalog_weights_from_global_shipment_item

CREATE OR REPLACE FUNCTION public.trg_sync_catalog_weights_from_global_shipment_item()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
begin
  if new.product_id is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and new.product_weight is not distinct from old.product_weight
     and new.package_weight is not distinct from old.package_weight
     and new.product_id is not distinct from old.product_id then
    return new;
  end if;

  select * into v_ship
  from public.global_shipments
  where id = new.shipment_id;

  if not found then
    return new;
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    return new;
  end if;

  update public.products p
  set
    product_weight = new.product_weight,
    package_weight = new.package_weight,
    updated_at = now()
  where p.id = new.product_id;

  return new;
end;
$function$;

-- unarchive_shipment

CREATE OR REPLACE FUNCTION public.unarchive_shipment (
  p_id bigint
)
  RETURNS public.global_shipments
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  update public.global_shipments
  set is_archived = false,
      archived_at = null,
      updated_at = now()
  where id = p_id
  returning * into v_ship;

  perform public._set_global_stocks_archived_for_shipment(p_id, false);

  return v_ship;
end;
$function$;

-- update_global_shipment_item

CREATE OR REPLACE FUNCTION public.update_global_shipment_item (
  p_item_id bigint,
  p_patch   jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_item public.global_shipment_items;
  v_ship public.global_shipments;
  v_outcome public.global_shipment_item_outcomes;
  v_items jsonb;
  v_sync_outcome boolean := false;
begin
  if p_item_id is null then
    raise exception 'item_id is required';
  end if;
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' then
    raise exception 'patch object is required';
  end if;

  select i.* into v_item
  from public.global_shipment_items i
  where i.id = p_item_id;

  if not found then
    raise exception 'shipment item not found';
  end if;

  select * into v_ship
  from public.global_shipments
  where id = v_item.shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are locked';
  end if;

  v_sync_outcome := (
    p_patch ? 'ordered_quantity'
    or p_patch ? 'purchase_price'
    or p_patch ? 'landed_cost_bdt'
  );

  perform set_config('app.skip_item_landed_restamp', '1', true);

  update public.global_shipment_items
  set
    section_id = case
      when p_patch ? 'section_id' then nullif((p_patch->>'section_id'), '')::bigint
      else section_id
    end,
    vendor_id = case
      when p_patch ? 'vendor_id' then nullif((p_patch->>'vendor_id'), '')::bigint
      else vendor_id
    end,
    ordered_quantity = case
      when p_patch ? 'ordered_quantity' and (p_patch->>'ordered_quantity') is not null
        then greatest(1, (p_patch->>'ordered_quantity')::integer)
      else ordered_quantity
    end,
    purchase_price = case
      when p_patch ? 'purchase_price' and (p_patch->>'purchase_price') is not null
        then greatest(0, (p_patch->>'purchase_price')::numeric)
      else purchase_price
    end,
    product_weight = case
      when p_patch ? 'product_weight' and (p_patch->>'product_weight') is not null
        then greatest(0, (p_patch->>'product_weight')::numeric)
      else product_weight
    end,
    package_weight = case
      when p_patch ? 'package_weight' and (p_patch->>'package_weight') is not null
        then greatest(0, (p_patch->>'package_weight')::numeric)
      else package_weight
    end,
    landed_cost_bdt = case
      when p_patch ? 'landed_cost_bdt' then nullif((p_patch->>'landed_cost_bdt'), '')::numeric
      else landed_cost_bdt
    end,
    barcode = case
      when p_patch ? 'barcode' then p_patch->>'barcode'
      else barcode
    end,
    product_code = case
      when p_patch ? 'product_code' then p_patch->>'product_code'
      else product_code
    end,
    name = case
      when p_patch ? 'name' and (p_patch->>'name') is not null then p_patch->>'name'
      else name
    end,
    image_url = case
      when p_patch ? 'image_url' then p_patch->>'image_url'
      else image_url
    end,
    updated_at = now()
  where id = p_item_id and shipment_id = v_item.shipment_id
  returning * into v_item;

  if v_sync_outcome then
    update public.global_shipment_item_outcomes o
    set
      quantity = case
        when p_patch ? 'ordered_quantity' and (p_patch->>'ordered_quantity') is not null
          then greatest(1, (p_patch->>'ordered_quantity')::integer)
        else o.quantity
      end,
      purchase_price = case
        when p_patch ? 'purchase_price' and (p_patch->>'purchase_price') is not null
          then greatest(0, (p_patch->>'purchase_price')::numeric)
        else o.purchase_price
      end,
      cost = case
        when p_patch ? 'landed_cost_bdt' then nullif((p_patch->>'landed_cost_bdt'), '')::numeric
        else o.cost
      end,
      updated_at = now()
    where o.shipment_item_id = p_item_id
      and o.reason = 'ordered'::public.global_shipment_outcome_reason
    returning * into v_outcome;
  end if;

  perform set_config('app.skip_item_landed_restamp', '0', true);

  if exists (select 1 from public.global_shipment_items where shipment_id = v_item.shipment_id) then
    perform public.stamp_global_shipment_landed_costs(v_item.shipment_id);
  end if;

  select coalesce(jsonb_agg(to_jsonb(i) order by i.sort_order asc, i.id asc), '[]'::jsonb)
  into v_items
  from public.global_shipment_items i
  where i.shipment_id = v_item.shipment_id;

  return jsonb_build_object(
    'items', v_items,
    'ordered_outcome', case when v_outcome.id is not null then to_jsonb(v_outcome) else null end
  );
end;
$function$;

-- upsert_global_shipment_cost_entry

CREATE OR REPLACE FUNCTION public.upsert_global_shipment_cost_entry (
  p_shipment_id      bigint,
  p_cost_bucket      public.global_shipment_cost_bucket,
  p_cost_component   public.global_shipment_cost_component,
  p_amount           numeric,
  p_currency_id      bigint                                DEFAULT NULL::bigint,
  p_metadata         jsonb                                 DEFAULT '{}'::jsonb,
  p_section_id       bigint                                DEFAULT NULL::bigint,
  p_id               bigint                                DEFAULT NULL::bigint,
  p_description      text                                  DEFAULT NULL::text,
  p_is_capitalizable boolean                               DEFAULT true
)
  RETURNS public.global_shipment_cost_entries
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_row public.global_shipment_cost_entries%rowtype;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are locked';
  end if;

  if p_amount is null or p_amount < 0 then
    raise exception 'amount must be >= 0';
  end if;

  if p_id is not null then
    update public.global_shipment_cost_entries e
    set
      cost_bucket = p_cost_bucket,
      cost_component = p_cost_component,
      is_capitalizable = coalesce(p_is_capitalizable, e.is_capitalizable),
      description = coalesce(p_description, e.description),
      amount = p_amount,
      currency_id = p_currency_id,
      metadata = coalesce(p_metadata, '{}'::jsonb),
      section_id = p_section_id,
      updated_at = now()
    where e.id = p_id
      and e.shipment_id = p_shipment_id
    returning * into v_row;

    if not found then
      raise exception 'cost entry % not found on shipment %', p_id, p_shipment_id;
    end if;
  else
    insert into public.global_shipment_cost_entries (
      tenant_id,
      shipment_id,
      cost_bucket,
      cost_component,
      is_capitalizable,
      description,
      amount,
      currency_id,
      metadata,
      section_id
    ) values (
      v_ship.tenant_id,
      p_shipment_id,
      p_cost_bucket,
      p_cost_component,
      coalesce(p_is_capitalizable, true),
      p_description,
      p_amount,
      p_currency_id,
      coalesce(p_metadata, '{}'::jsonb),
      p_section_id
    )
    returning * into v_row;
  end if;

  if coalesce(v_row.is_capitalizable, true)
     and exists (select 1 from public.global_shipment_items where shipment_id = p_shipment_id) then
    perform public.stamp_global_shipment_landed_costs(p_shipment_id);
  end if;

  return v_row;
end;
$function$;


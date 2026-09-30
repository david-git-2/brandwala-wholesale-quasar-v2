-- Missing fifo_run_pick_reserve rows must not null ATP via SELECT INTO.
CREATE OR REPLACE FUNCTION "public"."fill_preorder_demand_oldest_stock_for_document"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_parent_tenant_id bigint;
  v_updated integer := 0;
  v_skipped integer := 0;
  r record;
  v_stock record;
  v_total_avail integer := 0;
  v_remaining integer;
  v_avail integer;
  v_take integer;
  v_picks jsonb;
  v_delivered integer;
  v_db_reserved integer;
  v_run_reserved integer;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  create temp table if not exists fifo_run_pick_reserve (
    global_stock_id bigint primary key,
    reserved_qty integer not null default 0
  ) on commit delete rows;
  delete from fifo_run_pick_reserve where true;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then
    raise exception 'tenant not found: %', p_tenant_id;
  end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then
    raise exception 'access denied';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_line_tenant_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_line_tenant_id is null then
      raise exception 'shop order not found or not vendor catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_line_tenant_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id
      and f.billing_profile_id is not null;

    if v_line_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_line_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_line_tenant_id <> p_tenant_id then
    if not exists (
      select 1
      from public.tenants t
      where t.id = v_line_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_parent_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand document';
    end if;
  end if;

  if v_doc_status not in ('procuring', 'ready_for_shipment') then
    raise exception 'document is not open for stock pick updates';
  end if;

  select coalesce(t.parent_id, t.id) into v_parent_tenant_id
  from public.tenants t
  where t.id = v_line_tenant_id;

  for r in
    select
      q.source_type,
      q.source_id,
      q.tenant_id,
      q.product_id,
      q.need_qty
    from (
      select
        'shop_order_item'::public.preorder_demand_source_type as source_type,
        oi.id as source_id,
        o.tenant_id,
        oi.product_id,
        greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as need_qty
      from public.shop_order_items oi
      inner join public.shop_orders o on o.id = oi.order_id
      where v_doc_type = 'shop_order'
        and o.id = p_document_id
        and o.shop_type_snapshot = 'vendor_catalog'
      union all
      select
        'pbc_costing_item'::public.preorder_demand_source_type,
        pci.id,
        f.tenant_id,
        pci.product_id,
        greatest(
          case
            when pci.assigned_shipment_id is not null then 0
            else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
          end,
          0
        )::integer
      from public.product_based_costing_items pci
      inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
      where v_doc_type = 'pbc_costing_file'
        and f.id = p_document_id
        and f.billing_profile_id is not null
    ) q
    order by q.source_id
  loop
    if r.product_id is null or r.need_qty <= 0 then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    if exists (
      select 1
      from public.preorder_demand pd
      where pd.source_type = r.source_type
        and pd.source_id = r.source_id
        and public.sum_preorder_stock_picks(pd.stock_picks) > 0
    ) then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_total_avail := 0;
    for v_stock in
      select
        gs.id as global_stock_id,
        floor(public.global_stock_atp_qty(gs.id))::integer as atp
      from public.global_stocks gs
      inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      left join public.stock_locations sl on sl.id = gs.location_id
      where gs.parent_tenant_id = v_parent_tenant_id
        and gsi.product_id = r.product_id
        and gs.availability = 'sellable'::public.stock_availability
        and (gs.location_id is null or sl.is_pickable = true)
      order by gs.created_at, gs.id
    loop
      select coalesce(sum((e.value->>'quantity')::integer), 0)::integer
      into v_db_reserved
      from public.preorder_demand pd
      cross join jsonb_array_elements(coalesce(pd.stock_picks, '[]'::jsonb)) e(value)
      where nullif(e.value->>'global_stock_id', '')::bigint = v_stock.global_stock_id;

      v_run_reserved := coalesce((
        select fr.reserved_qty
        from fifo_run_pick_reserve fr
        where fr.global_stock_id = v_stock.global_stock_id
      ), 0);

      v_avail := greatest(v_stock.atp - v_db_reserved - v_run_reserved, 0);
      v_total_avail := v_total_avail + v_avail;
    end loop;

    if v_total_avail < r.need_qty then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_picks := '[]'::jsonb;
    v_remaining := r.need_qty;

    for v_stock in
      select
        gs.id as global_stock_id,
        sh.name as shipment_name,
        sl.name as location_name,
        floor(public.global_stock_atp_qty(gs.id))::integer as atp
      from public.global_stocks gs
      inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      inner join public.global_shipments sh on sh.id = gsi.shipment_id
      left join public.stock_locations sl on sl.id = gs.location_id
      where gs.parent_tenant_id = v_parent_tenant_id
        and gsi.product_id = r.product_id
        and gs.availability = 'sellable'::public.stock_availability
        and (gs.location_id is null or sl.is_pickable = true)
      order by gs.created_at, gs.id
    loop
      select coalesce(sum((e.value->>'quantity')::integer), 0)::integer
      into v_db_reserved
      from public.preorder_demand pd
      cross join jsonb_array_elements(coalesce(pd.stock_picks, '[]'::jsonb)) e(value)
      where nullif(e.value->>'global_stock_id', '')::bigint = v_stock.global_stock_id;

      v_run_reserved := coalesce((
        select fr.reserved_qty
        from fifo_run_pick_reserve fr
        where fr.global_stock_id = v_stock.global_stock_id
      ), 0);

      v_avail := greatest(v_stock.atp - v_db_reserved - v_run_reserved, 0);
      if v_avail <= 0 then
        continue;
      end if;

      v_take := least(v_avail, v_remaining);
      v_picks := v_picks || jsonb_build_array(
        jsonb_build_object(
          'global_stock_id', v_stock.global_stock_id,
          'quantity', v_take,
          'shipment_name', coalesce(v_stock.shipment_name, ''),
          'location_name', coalesce(v_stock.location_name, '')
        )
      );

      insert into fifo_run_pick_reserve (global_stock_id, reserved_qty)
      values (v_stock.global_stock_id, v_take)
      on conflict (global_stock_id) do update
        set reserved_qty = fifo_run_pick_reserve.reserved_qty + excluded.reserved_qty;

      v_remaining := v_remaining - v_take;
      if v_remaining <= 0 then
        exit;
      end if;
    end loop;

    if v_remaining > 0 then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_delivered := public.sum_preorder_stock_picks(v_picks);

    insert into public.preorder_demand (
      tenant_id,
      source_type,
      source_id,
      placed_quantity,
      delivered_quantity,
      stock_picks,
      updated_by_user_id
    ) values (
      r.tenant_id,
      r.source_type,
      r.source_id,
      0,
      v_delivered,
      v_picks,
      auth.uid()
    )
    on conflict (source_type, source_id) do update set
      delivered_quantity = excluded.delivered_quantity,
      stock_picks = excluded.stock_picks,
      updated_by_user_id = auth.uid(),
      updated_at = now();

    v_updated := v_updated + 1;
  end loop;

  return jsonb_build_object(
    'document_type', v_doc_type,
    'document_id', p_document_id,
    'updated_count', v_updated,
    'skipped_count', v_skipped
  );
end;
$$;

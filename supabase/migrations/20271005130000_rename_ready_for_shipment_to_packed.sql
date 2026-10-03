-- Rename catalog/PBC procurement middle status: ready_for_shipment -> packed
begin;

alter type public.shop_order_status rename value 'ready_for_shipment' to 'packed';

update public.product_based_costing_files
set status = 'packed', updated_at = now()
where status = 'ready_for_shipment';

drop function if exists public.staff_mark_pbc_ready_for_shipment(bigint);

CREATE OR REPLACE FUNCTION "public"."create_invoice_from_preorder_demand_document"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_billing_profile_id bigint;
  v_operating_tenant_id bigint;
  v_existing_invoice_id bigint;
  v_doc_status text;
  v_items jsonb := '[]'::jsonb;
  v_pick_elem jsonb;
  v_pd record;
  v_sell_price numeric(12,2);
  v_global_stock_id bigint;
  v_qty integer;
  v_payload jsonb;
  v_result jsonb;
  v_invoice_id bigint;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      o.billing_profile_id,
      o.global_invoice_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_operating_tenant_id, v_billing_profile_id, v_existing_invoice_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_operating_tenant_id is null then
      raise exception 'shop order not found or not vendor_catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      f.billing_profile_id,
      f.invoice_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_operating_tenant_id, v_billing_profile_id, v_existing_invoice_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id;

    if v_operating_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_operating_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_doc_status <> 'procuring' then
    raise exception 'document must be procuring to create invoice from demand';
  end if;

  if v_billing_profile_id is null then
    raise exception 'billing_profile_id is required on document';
  end if;

  if v_existing_invoice_id is not null then
    return jsonb_build_object(
      'success', true,
      'invoice_id', v_existing_invoice_id,
      'created', false
    );
  end if;

  if v_doc_type = 'shop_order' then
    for v_pd in
      select
        pd.stock_picks,
        coalesce(oi.final_price_amount, oi.staff_offer_amount, 0)::numeric(12,2) as sell_price
      from public.preorder_demand pd
      inner join public.shop_order_items oi
        on pd.source_type = 'shop_order_item'
        and pd.source_id = oi.id
      where oi.order_id = p_document_id
        and jsonb_array_length(coalesce(pd.stock_picks, '[]'::jsonb)) > 0
    loop
      v_sell_price := v_pd.sell_price;
      for v_pick_elem in
        select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
      loop
        v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
        v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
        if v_global_stock_id is not null and v_qty > 0 then
          v_items := v_items || jsonb_build_array(jsonb_build_object(
            'global_stock_id', v_global_stock_id,
            'quantity', v_qty,
            'sell_price_amount', v_sell_price
          ));
        end if;
      end loop;
    end loop;
  else
    for v_pd in
      select
        pd.stock_picks,
        coalesce(pci.offer_price, 0)::numeric(12,2) as sell_price
      from public.preorder_demand pd
      inner join public.product_based_costing_items pci
        on pd.source_type = 'pbc_costing_item'
        and pd.source_id = pci.id
      where pci.product_based_costing_file_id = p_document_id
        and jsonb_array_length(coalesce(pd.stock_picks, '[]'::jsonb)) > 0
    loop
      v_sell_price := v_pd.sell_price;
      for v_pick_elem in
        select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
      loop
        v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
        v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
        if v_global_stock_id is not null and v_qty > 0 then
          v_items := v_items || jsonb_build_array(jsonb_build_object(
            'global_stock_id', v_global_stock_id,
            'quantity', v_qty,
            'sell_price_amount', v_sell_price
          ));
        end if;
      end loop;
    end loop;
  end if;

  if jsonb_array_length(v_items) = 0 then
    raise exception 'at least one stock pick is required before marking ready for shipment';
  end if;

  v_payload := jsonb_build_object(
    'invoice', jsonb_build_object(
      'invoice_type', 'wholesale',
      'billing_profile_id', v_billing_profile_id
    ),
    'items', v_items,
    'issue', false
  );

  v_result := public.create_sales_invoice_from_payload(v_operating_tenant_id, v_payload);

  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'failed to create invoice from demand');
  end if;

  v_invoice_id := (v_result->>'invoice_id')::bigint;

  update public.sales_invoices
  set
    invoice_status = 'proforma_generated'::public.global_invoice_status,
    shop_order_id = case when v_doc_type = 'shop_order' then p_document_id else shop_order_id end,
    updated_at = now()
  where id = v_invoice_id
    and invoice_status = 'draft'::public.global_invoice_status;

  if v_doc_type = 'shop_order' then
    update public.shop_orders
    set
      global_invoice_id = v_invoice_id,
      updated_at = now()
    where id = p_document_id
      and global_invoice_id is null;
  else
    update public.product_based_costing_files
    set
      invoice_id = v_invoice_id,
      updated_at = now()
    where id = p_document_id
      and invoice_id is null;
  end if;

  return v_result || jsonb_build_object(
    'created', true,
    'invoice_status', 'proforma_generated'
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."customer_shop_order_glance_bucket"("p_status" "public"."shop_order_status") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select case
    when p_status = 'draft'::public.shop_order_status then null
    when p_status in (
      'priced'::public.shop_order_status,
      'negotiating'::public.shop_order_status,
      'countered'::public.shop_order_status,
      'final_offered'::public.shop_order_status
    ) then 'needs_you'
    when p_status in (
      'fulfilled'::public.shop_order_status,
      'delivered'::public.shop_order_status,
      'payment_received'::public.shop_order_status,
      'reseller_paid'::public.shop_order_status,
      'cancelled'::public.shop_order_status,
      'returned'::public.shop_order_status
    ) then 'done'
    else 'in_progress'
  end;
$$;

CREATE OR REPLACE FUNCTION "public"."customer_shop_order_glance_segment"("p_status" "public"."shop_order_status") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select case
    when p_status in (
      'priced'::public.shop_order_status,
      'negotiating'::public.shop_order_status,
      'countered'::public.shop_order_status,
      'final_offered'::public.shop_order_status
    ) then 'needs_you'
    when p_status in (
      'submitted'::public.shop_order_status,
      'costing_pending'::public.shop_order_status,
      'confirmed'::public.shop_order_status,
      'placed'::public.shop_order_status,
      'procuring'::public.shop_order_status,
      'ordered'::public.shop_order_status,
      'processing'::public.shop_order_status,
      'shipped'::public.shop_order_status,
      'packed'::public.shop_order_status,
      'ready_for_pickup'::public.shop_order_status
    ) then 'in_progress'
    when p_status = 'delivered'::public.shop_order_status then 'delivered'
    when p_status in (
      'payment_received'::public.shop_order_status,
      'reseller_paid'::public.shop_order_status
    ) then 'paid'
    else null
  end;
$$;

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

  if v_doc_status not in ('procuring', 'packed') then
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

CREATE OR REPLACE FUNCTION "public"."get_customer_dashboard_summary"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_group_id bigint;
  v_shops jsonb := '[]'::jsonb;
  v_categories jsonb := '[]'::jsonb;
  v_recent_orders jsonb := '[]'::jsonb;
  v_active_carts jsonb := '[]'::jsonb;
  v_buckets jsonb;
  v_catalog_glance jsonb := jsonb_build_object('total_products', 0, 'total_brands', 0);
begin
  if p_tenant_id is null then
    return jsonb_build_object(
      'tenant_id', null,
      'customer_group_id', null,
      'shops', '[]'::jsonb,
      'categories', '[]'::jsonb,
      'catalog_glance', v_catalog_glance,
      'order_glance', jsonb_build_object(
        'buckets', jsonb_build_object('needs_you', 0, 'in_progress', 0, 'done', 0, 'total', 0),
        'segments', jsonb_build_object(
          'needs_you', 0,
          'in_progress', 0,
          'delivered', 0,
          'paid', 0,
          'payment_needed', 0,
          'total', 0
        )
      ),
      'recent_orders', '[]'::jsonb,
      'active_carts', '[]'::jsonb
    );
  end if;

  v_group_id := public.current_customer_group_id(p_tenant_id);
  if v_group_id is null then
    return jsonb_build_object(
      'tenant_id', p_tenant_id,
      'customer_group_id', null,
      'shops', '[]'::jsonb,
      'categories', '[]'::jsonb,
      'catalog_glance', v_catalog_glance,
      'order_glance', jsonb_build_object(
        'buckets', jsonb_build_object('needs_you', 0, 'in_progress', 0, 'done', 0, 'total', 0),
        'segments', jsonb_build_object(
          'needs_you', 0,
          'in_progress', 0,
          'delivered', 0,
          'paid', 0,
          'payment_needed', 0,
          'total', 0
        )
      ),
      'recent_orders', '[]'::jsonb,
      'active_carts', '[]'::jsonb
    );
  end if;

  v_catalog_glance := public.customer_accessible_catalog_glance(p_tenant_id, v_group_id);

  select coalesce(jsonb_agg(row_to_json(shop_row) order by shop_row.name), '[]'::jsonb)
  into v_shops
  from (
    select
      s.id,
      s.tenant_id,
      s.name,
      s.slug,
      s.shop_type,
      s.order_mode,
      s.is_negotiable,
      bool_or(
        case
          when access.status = false or coalesce(profile.is_active, true) = false then false
          else public.resolve_shop_can_see_buy_price(
            s.shop_type,
            access.can_see_buy_price,
            access.can_see_sell_price,
            profile.default_can_see_buy_price,
            profile.default_can_see_sell_price
          )
        end
      ) as can_see_buy_price,
      bool_or(
        case
          when access.status = false or coalesce(profile.is_active, true) = false then false
          when s.shop_type = 'dropship' then true
          else coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, false)
        end
      ) as can_see_sell_price,
      s.description,
      s.category_ids,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', c.id,
              'name', c.name,
              'slug', c.slug,
              'icon', c.icon
            )
            order by c.name
          )
          from public.shop_categories c
          where c.id = any(s.category_ids)
            and c.is_active = true
        ),
        '[]'::jsonb
      ) as categories,
      s.sell_currency_id,
      gc.code as sell_currency_code,
      gc.symbol as sell_currency_symbol
    from public.shops s
    join public.shop_customer_group_access access on access.shop_id = s.id
    join public.customer_groups cg on cg.id = access.customer_group_id
    left join public.customer_group_shop_profiles profile
      on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
    left join public.global_currencies gc on gc.id = s.sell_currency_id
    where s.is_active = true
      and s.deleted_at is null
      and s.tenant_id = p_tenant_id
      and cg.id = v_group_id
      and cg.is_active = true
      and access.status = true
      and coalesce(profile.is_active, true) = true
      and coalesce(access.can_browse, profile.default_can_browse, false) = true
    group by
      s.id,
      s.tenant_id,
      s.name,
      s.slug,
      s.shop_type,
      s.order_mode,
      s.is_negotiable,
      s.description,
      s.category_ids,
      s.sell_currency_id,
      gc.code,
      gc.symbol
  ) shop_row;

  select coalesce(jsonb_agg(cat order by cat ->> 'name'), '[]'::jsonb)
  into v_categories
  from (
    select distinct on ((cat ->> 'id')::bigint) cat
    from (
      select jsonb_array_elements(coalesce(shop_elem -> 'categories', '[]'::jsonb)) as cat
      from jsonb_array_elements(v_shops) shop_elem
    ) cats
    order by (cat ->> 'id')::bigint
  ) deduped;

  select jsonb_build_object(
    'buckets', jsonb_build_object(
      'needs_you', coalesce(count(*) filter (
        where public.customer_shop_order_glance_bucket(o.status) = 'needs_you'
      ), 0),
      'in_progress', coalesce(count(*) filter (
        where public.customer_shop_order_glance_bucket(o.status) = 'in_progress'
      ), 0),
      'done', coalesce(count(*) filter (
        where public.customer_shop_order_glance_bucket(o.status) = 'done'
      ), 0),
      'total', coalesce(count(*) filter (where o.status is distinct from 'draft'), 0)
    ),
    'segments', jsonb_build_object(
      'needs_you', coalesce(count(*) filter (
        where public.customer_shop_order_glance_segment(o.status) = 'needs_you'
      ), 0),
      'in_progress', coalesce(count(*) filter (
        where public.customer_shop_order_glance_segment(o.status) = 'in_progress'
      ), 0),
      'delivered', coalesce(count(*) filter (
        where public.customer_shop_order_glance_segment(o.status) = 'delivered'
      ), 0),
      'paid', coalesce(count(*) filter (
        where public.customer_shop_order_glance_segment(o.status) = 'paid'
      ), 0),
      'payment_needed', coalesce(count(*) filter (
        where public.customer_shop_order_glance_segment(o.status) = 'payment_needed'
      ), 0),
      'total', coalesce(count(*) filter (
        where public.customer_shop_order_glance_segment(o.status) is not null
      ), 0)
    )
  )
  into v_buckets
  from public.shop_orders o
  where o.tenant_id = p_tenant_id
    and o.customer_group_id = v_group_id
    and o.status is distinct from 'draft';

  select coalesce(jsonb_agg(row_to_json(order_row) order by order_row.created_at desc), '[]'::jsonb)
  into v_recent_orders
  from (
    select
      o.id,
      o.shop_id,
      s.name as shop_name,
      s.slug as shop_slug,
      o.order_no,
      o.status,
      gc.symbol as currency_symbol,
      o.created_at
    from public.shop_orders o
    join public.shops s on s.id = o.shop_id
    left join public.global_currencies gc on gc.id = s.sell_currency_id
    where o.tenant_id = p_tenant_id
      and o.customer_group_id = v_group_id
      and o.status is distinct from 'draft'
    order by o.created_at desc
    limit 5
  ) order_row;

  select coalesce(jsonb_agg(row_to_json(cart_row) order by cart_row.updated_at desc), '[]'::jsonb)
  into v_active_carts
  from (
    select
      c.id as cart_id,
      s.id as shop_id,
      s.name as shop_name,
      s.slug as shop_slug,
      null::text as shop_logo_url,
      s.shop_type::text as shop_type,
      c.can_see_buy_price_snapshot as can_see_buy_price,
      c.can_see_sell_price_snapshot as can_see_sell_price,
      s.sell_currency_id as currency_id,
      gc.code as currency_code,
      gc.symbol as currency_symbol,
      coalesce(sum(ci.quantity), 0)::bigint as item_count,
      case
        when c.can_see_sell_price_snapshot then
          sum(
            ci.quantity * coalesce(
              ci.customer_sell_price_amount,
              ci.unit_sell_price_amount,
              ci.unit_list_price_amount,
              0
            )
          )::numeric
        else null
      end as cart_total,
      c.updated_at
    from public.shop_carts c
    join public.shops s on s.id = c.shop_id
    join public.shop_cart_items ci on ci.cart_id = c.id
    left join public.global_currencies gc on gc.id = s.sell_currency_id
    where c.status = 'active'
      and c.tenant_id = p_tenant_id
      and c.customer_group_id = v_group_id
    group by c.id, s.id, gc.code, gc.symbol
  ) cart_row;

  return jsonb_build_object(
    'tenant_id', p_tenant_id,
    'customer_group_id', v_group_id,
    'shops', v_shops,
    'categories', v_categories,
    'catalog_glance', v_catalog_glance,
    'order_glance', v_buckets,
    'recent_orders', v_recent_orders,
    'active_carts', v_active_carts
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."get_procurement_demand_open_qty"("p_source_type" "public"."preorder_demand_source_type", "p_source_id" bigint) RETURNS TABLE("tenant_id" bigint, "open_qty" integer, "document_status" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if p_source_type = 'shop_order_item' then
    return query
    select
      o.tenant_id,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer,
      public.normalize_shop_order_procurement_status(o.status)
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    where oi.id = p_source_id
      and o.shop_type_snapshot = 'vendor_catalog';
  elsif p_source_type = 'pbc_costing_item' then
    return query
    select
      f.tenant_id,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer,
      public.normalize_pbc_procurement_status(f.status)
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    where pci.id = p_source_id
      and f.billing_profile_id is not null;
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."get_shop_order_dashboard_metrics"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_today date;
  v_sales numeric := 0;
  v_invoice_count bigint := 0;
  v_shipped bigint := 0;
  v_ready bigint := 0;
  v_needs_quote bigint := 0;
  v_processing bigint := 0;
  v_dropship_submitted bigint := 0;
  v_dropship_processing bigint := 0;
  v_dropship_ready bigint := 0;
  v_hourly jsonb := '[]'::jsonb;
  v_couriers jsonb := '[]'::jsonb;
  v_pipeline jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'shop_order', 'view') THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_today := (timezone('Asia/Dhaka', now()))::date;

  SELECT
    coalesce(sum(si.total_amount), 0),
    count(*)
  INTO v_sales, v_invoice_count
  FROM public.sales_invoices si
  WHERE si.issued_by_tenant_id = p_tenant_id
    AND si.invoice_status = 'issued'::public.global_invoice_status
    AND si.invoice_date = v_today;

  SELECT
    coalesce(count(*) FILTER (WHERE o.status = 'shipped'::public.shop_order_status), 0),
    coalesce(count(*) FILTER (WHERE o.status = 'ready_for_pickup'::public.shop_order_status), 0)
  INTO v_shipped, v_ready
  FROM public.shop_orders o
  WHERE o.tenant_id = p_tenant_id
    AND o.status IN (
      'shipped'::public.shop_order_status,
      'ready_for_pickup'::public.shop_order_status
    );

  SELECT
    coalesce(count(*) FILTER (
      WHERE o.status IN (
        'submitted'::public.shop_order_status,
        'costing_pending'::public.shop_order_status,
        'countered'::public.shop_order_status
      )
    ), 0),
    coalesce(count(*) FILTER (
      WHERE o.status IN (
        'processing'::public.shop_order_status,
        'confirmed'::public.shop_order_status,
        'procuring'::public.shop_order_status,
        'packed'::public.shop_order_status,
        'placed'::public.shop_order_status,
        'ordered'::public.shop_order_status
      )
    ), 0)
  INTO v_needs_quote, v_processing
  FROM public.shop_orders o
  WHERE o.tenant_id = p_tenant_id;

  SELECT
    coalesce(count(*) FILTER (
      WHERE o.shop_type_snapshot = 'dropship'::public.shop_type_enum
        AND o.status = 'submitted'::public.shop_order_status
    ), 0),
    coalesce(count(*) FILTER (
      WHERE o.shop_type_snapshot = 'dropship'::public.shop_type_enum
        AND o.status = 'processing'::public.shop_order_status
    ), 0),
    coalesce(count(*) FILTER (
      WHERE o.shop_type_snapshot = 'dropship'::public.shop_type_enum
        AND o.status = 'ready_for_pickup'::public.shop_order_status
    ), 0)
  INTO v_dropship_submitted, v_dropship_processing, v_dropship_ready
  FROM public.shop_orders o
  WHERE o.tenant_id = p_tenant_id;

  SELECT coalesce(jsonb_agg(row_to_json(p) ORDER BY p.sort_key), '[]'::jsonb)
  INTO v_pipeline
  FROM (
    SELECT
      bucket.status,
      count(*)::bigint AS count,
      bucket.sort_key
    FROM (
      SELECT
        CASE
          WHEN o.status IN (
            'submitted'::public.shop_order_status,
            'costing_pending'::public.shop_order_status,
            'countered'::public.shop_order_status
          ) THEN 'needs_quote'
          WHEN o.status IN (
            'priced'::public.shop_order_status,
            'final_offered'::public.shop_order_status,
            'negotiating'::public.shop_order_status
          ) THEN 'awaiting_customer'
          WHEN o.status IN (
            'processing'::public.shop_order_status,
            'confirmed'::public.shop_order_status,
            'procuring'::public.shop_order_status,
            'packed'::public.shop_order_status,
            'placed'::public.shop_order_status,
            'ordered'::public.shop_order_status
          ) THEN 'processing'
          WHEN o.status = 'ready_for_pickup'::public.shop_order_status THEN 'ready_for_pickup'
          WHEN o.status = 'shipped'::public.shop_order_status THEN 'shipped'
        END AS status,
        CASE
          WHEN o.status IN (
            'submitted'::public.shop_order_status,
            'costing_pending'::public.shop_order_status,
            'countered'::public.shop_order_status
          ) THEN 1
          WHEN o.status IN (
            'priced'::public.shop_order_status,
            'final_offered'::public.shop_order_status,
            'negotiating'::public.shop_order_status
          ) THEN 2
          WHEN o.status IN (
            'processing'::public.shop_order_status,
            'confirmed'::public.shop_order_status,
            'procuring'::public.shop_order_status,
            'packed'::public.shop_order_status,
            'placed'::public.shop_order_status,
            'ordered'::public.shop_order_status
          ) THEN 3
          WHEN o.status = 'ready_for_pickup'::public.shop_order_status THEN 4
          WHEN o.status = 'shipped'::public.shop_order_status THEN 5
        END AS sort_key
      FROM public.shop_orders o
      WHERE o.tenant_id = p_tenant_id
    ) bucket
    WHERE bucket.status IS NOT NULL
    GROUP BY bucket.status, bucket.sort_key
  ) p;

  SELECT coalesce(jsonb_agg(row_to_json(h) ORDER BY h.hour_at), '[]'::jsonb)
  INTO v_hourly
  FROM (
    SELECT
      date_trunc('hour', timezone('Asia/Dhaka', si.created_at)) AS hour_at,
      to_char(timezone('Asia/Dhaka', si.created_at), 'HH12 AM') AS label,
      round(sum(si.total_amount), 2) AS amount
    FROM public.sales_invoices si
    WHERE si.issued_by_tenant_id = p_tenant_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.invoice_date = v_today
    GROUP BY 1, 2
  ) h;

  SELECT coalesce(jsonb_agg(row_to_json(c) ORDER BY c.count DESC), '[]'::jsonb)
  INTO v_couriers
  FROM (
    SELECT
      coalesce(nullif(trim(o.courier_name), ''), 'Store pickup') AS name,
      count(*)::bigint AS count,
      count(*) FILTER (WHERE o.status = 'shipped'::public.shop_order_status)::bigint AS shipped_count,
      count(*) FILTER (WHERE o.status = 'ready_for_pickup'::public.shop_order_status)::bigint AS ready_count
    FROM public.shop_orders o
    WHERE o.tenant_id = p_tenant_id
      AND o.status IN (
        'shipped'::public.shop_order_status,
        'ready_for_pickup'::public.shop_order_status
      )
    GROUP BY 1
  ) c;

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'today_sales_amount', round(v_sales, 2),
    'today_invoice_count', v_invoice_count,
    'shipped_count', v_shipped,
    'ready_for_pickup_count', v_ready,
    'needs_quote_count', v_needs_quote,
    'processing_count', v_processing,
    'dropship_submitted', v_dropship_submitted,
    'dropship_processing', v_dropship_processing,
    'dropship_ready', v_dropship_ready,
    'hourly', v_hourly,
    'couriers', v_couriers,
    'pipeline', v_pipeline
  );
END;
$$;

CREATE OR REPLACE FUNCTION "public"."list_procurement_demand_group_items"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_cursor_source_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 100));
  v_items jsonb := '[]'::jsonb;
  v_n integer := 0;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
  v_last_source_id bigint;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then raise exception 'tenant not found: %', p_tenant_id; end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then raise exception 'access denied'; end if;

  if v_doc_type not in ('shop_order', 'pbc_costing_file') then
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  with tenant_scope as (
    select t.id as tenant_id from public.tenants t
    where (
      (v_is_parent and (t.parent_id = p_tenant_id or t.id = p_tenant_id))
      or (not v_is_parent and t.id = p_tenant_id)
    )
  ),
  shop_lines as (
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      'shop_order_item'::text as source_type,
      oi.id as source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') as barcode,
      coalesce(p.product_code, '') as product_code,
      nullif(trim(coalesce(p.vendor_code, '')), '') as vendor_code,
      nullif(trim(coalesce(p.market_code, '')), '') as market_code,
      nullif(trim(coalesce(p.brand, '')), '') as brand,
      nullif(trim(coalesce(p.category, '')), '') as category,
      p.available_units,
      nullif(trim(coalesce(p.languages, '')), '') as languages,
      nullif(trim(coalesce(p.country_of_origin, '')), '') as country_of_origin,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.products p on p.id = oi.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'shop_order_item'
      and pd.source_id = oi.id
      and pd.tenant_id = o.tenant_id
    where v_doc_type = 'shop_order'
      and o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog'
  ),
  pbc_lines as (
    select
      'pbc_costing_file'::text as document_type,
      f.id as document_id,
      'pbc_costing_item'::text as source_type,
      pci.id as source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url,
      coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      coalesce(
        nullif(trim(coalesce(pci.vendor_code, '')), ''),
        nullif(trim(coalesce(p.vendor_code, '')), '')
      ) as vendor_code,
      coalesce(
        nullif(trim(coalesce(pci.market_code, '')), ''),
        nullif(trim(coalesce(p.market_code, '')), '')
      ) as market_code,
      coalesce(
        nullif(trim(coalesce(pci.brand, '')), ''),
        nullif(trim(coalesce(p.brand, '')), '')
      ) as brand,
      nullif(trim(coalesce(p.category, '')), '') as category,
      p.available_units,
      nullif(trim(coalesce(p.languages, '')), '') as languages,
      nullif(trim(coalesce(p.country_of_origin, '')), '') as country_of_origin,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.products p on p.id = pci.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'pbc_costing_item'
      and pd.source_id = pci.id
      and pd.tenant_id = f.tenant_id
    where v_doc_type = 'pbc_costing_file'
      and f.id = p_document_id
      and f.billing_profile_id is not null
  ),
  demand_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  eligible_lines as (
    select dl.*
    from demand_lines dl
    where (
      dl.quantity > 0
      or dl.placed_quantity > 0
      or dl.delivered_quantity > 0
    )
      and (
        v_search is null
        or dl.name ilike '%' || v_search || '%'
        or coalesce(dl.barcode, '') ilike '%' || v_search || '%'
        or coalesce(dl.product_code, '') ilike '%' || v_search || '%'
      )
      and (
        p_cursor_source_id is null
        or dl.source_id > p_cursor_source_id
      )
  ),
  paged as (
    select el.*
    from eligible_lines el
    order by el.source_id
    limit v_limit + 1
  ),
  page_count as (
    select count(*)::integer as n from paged
  ),
  page_rows as (
    select p.*
    from paged p
    order by p.source_id
    limit v_limit
  ),
  item_json as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'source_type', row.source_type,
          'source_id', row.source_id,
          'product_id', row.product_id,
          'name', row.name,
          'image_url', row.image_url,
          'barcode', nullif(row.barcode, ''),
          'product_code', nullif(row.product_code, ''),
          'vendor_code', row.vendor_code,
          'market_code', row.market_code,
          'brand', row.brand,
          'category', row.category,
          'available_units', row.available_units,
          'languages', row.languages,
          'country_of_origin', row.country_of_origin,
          'quantity', row.quantity,
          'need_quantity', row.quantity,
          'preorder_demand_id', row.preorder_demand_id,
          'vendor_id', row.vendor_id,
          'placed_quantity', row.placed_quantity,
          'delivered_quantity', row.delivered_quantity,
          'remaining_quantity', row.quantity - row.placed_quantity,
          'remaining_to_deliver', greatest(row.quantity - row.delivered_quantity, 0),
          'stock_picks', row.stock_picks
        )
        order by row.source_id
      ),
      '[]'::jsonb
    ) as items
    from page_rows row
  ),
  cursor_row as (
    select p.source_id
    from paged p
    order by p.source_id
    offset v_limit
    limit 1
  )
  select
    ij.items,
    pc.n,
    cr.source_id
  into v_items, v_n, v_last_source_id
  from item_json ij
  cross join page_count pc
  left join cursor_row cr on true;

  if v_n > v_limit then
    v_has_more := true;
    v_next_cursor := jsonb_build_object('source_id', v_last_source_id);
  end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'document_type', v_doc_type,
      'document_id', p_document_id,
      'limit', v_limit,
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    ),
    'items', v_items
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."list_procurement_demand_groups"("p_tenant_id" bigint, "p_procurement_status" "text" DEFAULT 'procuring'::"text", "p_search" "text" DEFAULT NULL::"text", "p_child_tenant_id" bigint DEFAULT NULL::bigint, "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_is_parent boolean;
  v_allowed boolean := false;
  v_status text := lower(trim(coalesce(p_procurement_status, 'procuring')));
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(coalesce(p_limit, 50), 1);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_groups jsonb := '[]'::jsonb;
  v_group_count integer := 0;
  v_item_count integer := 0;
  v_has_shop boolean := false;
  v_has_pbc boolean := false;
  v_sources text[] := '{}'::text[];
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then raise exception 'tenant not found: %', p_tenant_id; end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then raise exception 'access denied'; end if;
  if v_status not in ('procuring', 'packed', 'delivered') then
    raise exception 'invalid procurement status: %', v_status;
  end if;

  with tenant_scope as (
    select t.id as tenant_id from public.tenants t
    where (
      (v_is_parent and (t.parent_id = p_tenant_id or t.id = p_tenant_id))
      or (not v_is_parent and t.id = p_tenant_id)
    )
      and (p_child_tenant_id is null or t.id = p_child_tenant_id)
  ),
  shop_lines as (
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      public.normalize_shop_order_procurement_status(o.status) as document_status,
      o.customer_group_id,
      cg.name as customer_group_name,
      null::jsonb as vendor,
      'shop_order_item'::text as source_type,
      oi.id as source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') as barcode,
      coalesce(p.product_code, '') as product_code,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      o.global_invoice_id as invoice_id
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.customer_groups cg on cg.id = o.customer_group_id
    left join public.products p on p.id = oi.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'shop_order_item'
      and pd.source_id = oi.id
      and pd.tenant_id = o.tenant_id
    where o.shop_type_snapshot = 'vendor_catalog'
      and public.normalize_shop_order_procurement_status(o.status) = v_status
      and (
        v_search is null
        or oi.name ilike '%' || v_search || '%'
        or o.name ilike '%' || v_search || '%'
        or o.order_no ilike '%' || v_search || '%'
        or coalesce(p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  pbc_lines as (
    select
      'pbc_costing_file'::text as document_type,
      f.id as document_id,
      public.normalize_pbc_procurement_status(f.status) as document_status,
      f.customer_group_id,
      cg.name as customer_group_name,
      case
        when v.id is not null then jsonb_build_object(
          'id', v.id,
          'code', coalesce(nullif(trim(f.vendor_code), ''), v.code),
          'name', v.name
        )
        when nullif(trim(f.vendor_code), '') is not null then jsonb_build_object(
          'id', f.vendor_id,
          'code', trim(f.vendor_code),
          'name', null
        )
        else null::jsonb
      end as vendor,
      'pbc_costing_item'::text as source_type,
      pci.id as source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url,
      coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      f.invoice_id
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.customer_groups cg on cg.id = f.customer_group_id
    left join public.products p on p.id = pci.product_id
    left join public.vendors v on v.id = f.vendor_id
    left join public.preorder_demand pd
      on pd.source_type = 'pbc_costing_item'
      and pd.source_id = pci.id
      and pd.tenant_id = f.tenant_id
    where f.billing_profile_id is not null
      and public.normalize_pbc_procurement_status(f.status) = v_status
      and (
        v_search is null
        or coalesce(pci.name, p.name, '') ilike '%' || v_search || '%'
        or coalesce(f.name, '') ilike '%' || v_search || '%'
        or coalesce(pci.barcode, p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(pci.product_code, p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  demand_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  eligible_lines as (
    select dl.*
    from demand_lines dl
    where dl.quantity > 0
      or dl.placed_quantity > 0
      or dl.delivered_quantity > 0
  ),
  grouped as (
    select
      el.document_type,
      el.document_id,
      max(el.document_status) as document_status,
      max(el.customer_group_id) as customer_group_id,
      max(el.customer_group_name) as customer_group_name,
      (array_agg(el.vendor) filter (where el.vendor is not null))[1] as vendor,
      max(el.invoice_id) as invoice_id,
      jsonb_agg(
        jsonb_build_object(
          'source_type', el.source_type,
          'source_id', el.source_id,
          'product_id', el.product_id,
          'name', el.name,
          'image_url', el.image_url,
          'barcode', nullif(el.barcode, ''),
          'product_code', nullif(el.product_code, ''),
          'quantity', el.quantity,
          'need_quantity', el.quantity,
          'preorder_demand_id', el.preorder_demand_id,
          'vendor_id', el.vendor_id,
          'placed_quantity', el.placed_quantity,
          'delivered_quantity', el.delivered_quantity,
          'remaining_quantity', el.quantity - el.placed_quantity,
          'remaining_to_deliver', greatest(el.quantity - el.delivered_quantity, 0),
          'stock_picks', el.stock_picks
        )
        order by el.source_id
      ) as items,
      count(*)::integer as item_count
    from eligible_lines el
    group by el.document_type, el.document_id
  ),
  paged as (
    select g.*, count(*) over ()::integer as total_groups
    from grouped g
    order by g.document_type, g.document_id
    limit v_limit offset v_offset
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'document_type', p.document_type,
          'document_id', p.document_id,
          'document_status', p.document_status,
          'customer_group_id', p.customer_group_id,
          'customer_group_name', p.customer_group_name,
          'vendor', p.vendor,
          'invoice_id', p.invoice_id,
          'items', p.items
        )
        order by p.document_type, p.document_id
      ),
      '[]'::jsonb
    ),
    coalesce(max(p.total_groups), 0),
    coalesce(sum(p.item_count), 0),
    coalesce(bool_or(p.document_type = 'shop_order'), false),
    coalesce(bool_or(p.document_type = 'pbc_costing_file'), false)
  into v_groups, v_group_count, v_item_count, v_has_shop, v_has_pbc
  from paged p;

  if v_has_shop then v_sources := array_append(v_sources, 'shop_order'); end if;
  if v_has_pbc then v_sources := array_append(v_sources, 'pbc_costing'); end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'tenant_id', p_tenant_id,
      'procurement_status', v_status,
      'sources_included', to_jsonb(v_sources),
      'group_count', coalesce(jsonb_array_length(v_groups), 0),
      'item_count', v_item_count,
      'total_group_count', v_group_count,
      'limit', v_limit,
      'offset', v_offset,
      'has_more', v_group_count > (v_offset + v_limit)
    ),
    'groups', v_groups
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."list_procurement_fulfill_group_items"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_cursor_source_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.list_procurement_demand_group_items(
    p_tenant_id,
    p_document_type,
    p_document_id,
    p_search,
    p_limit,
    p_cursor_source_id
  );
$$;

CREATE OR REPLACE FUNCTION "public"."list_procurement_fulfill_groups"("p_tenant_id" bigint, "p_procurement_status" "text" DEFAULT 'procuring'::"text", "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_is_parent boolean;
  v_allowed boolean := false;
  v_status text := lower(trim(coalesce(p_procurement_status, 'procuring')));
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(coalesce(p_limit, 50), 1);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_groups jsonb := '[]'::jsonb;
  v_group_count integer := 0;
  v_item_count integer := 0;
  v_has_shop boolean := false;
  v_has_pbc boolean := false;
  v_sources text[] := '{}'::text[];
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then raise exception 'tenant not found: %', p_tenant_id; end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then raise exception 'access denied'; end if;
  if v_status not in ('procuring', 'packed', 'delivered') then
    raise exception 'invalid procurement status: %', v_status;
  end if;

  with tenant_scope as (
    select t.id as tenant_id from public.tenants t
    where (
      (v_is_parent and (t.parent_id = p_tenant_id or t.id = p_tenant_id))
      or (not v_is_parent and t.id = p_tenant_id)
    )
  ),
  shop_lines as (
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      public.normalize_shop_order_procurement_status(o.status) as document_status,
      o.customer_group_id,
      cg.name as customer_group_name,
      null::jsonb as vendor,
      'shop_order_item'::text as source_type,
      oi.id as source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') as barcode,
      coalesce(p.product_code, '') as product_code,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      o.global_invoice_id as invoice_id,
      nullif(trim(coalesce(o.name, o.order_no, '')), '') as document_name
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.customer_groups cg on cg.id = o.customer_group_id
    left join public.products p on p.id = oi.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'shop_order_item'
      and pd.source_id = oi.id
      and pd.tenant_id = o.tenant_id
    where o.shop_type_snapshot = 'vendor_catalog'
      and public.normalize_shop_order_procurement_status(o.status) = v_status
      and (
        v_search is null
        or oi.name ilike '%' || v_search || '%'
        or o.name ilike '%' || v_search || '%'
        or o.order_no ilike '%' || v_search || '%'
        or coalesce(p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  pbc_lines as (
    select
      'pbc_costing_file'::text as document_type,
      f.id as document_id,
      public.normalize_pbc_procurement_status(f.status) as document_status,
      f.customer_group_id,
      cg.name as customer_group_name,
      case
        when v.id is not null then jsonb_build_object(
          'id', v.id,
          'code', coalesce(nullif(trim(f.vendor_code), ''), v.code),
          'name', v.name
        )
        when nullif(trim(f.vendor_code), '') is not null then jsonb_build_object(
          'id', f.vendor_id,
          'code', trim(f.vendor_code),
          'name', null
        )
        else null::jsonb
      end as vendor,
      'pbc_costing_item'::text as source_type,
      pci.id as source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url,
      coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      f.invoice_id,
      nullif(trim(coalesce(f.name, '')), '') as document_name
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.customer_groups cg on cg.id = f.customer_group_id
    left join public.products p on p.id = pci.product_id
    left join public.vendors v on v.id = f.vendor_id
    left join public.preorder_demand pd
      on pd.source_type = 'pbc_costing_item'
      and pd.source_id = pci.id
      and pd.tenant_id = f.tenant_id
    where f.billing_profile_id is not null
      and public.normalize_pbc_procurement_status(f.status) = v_status
      and (
        v_search is null
        or coalesce(pci.name, p.name, '') ilike '%' || v_search || '%'
        or coalesce(f.name, '') ilike '%' || v_search || '%'
        or coalesce(pci.barcode, p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(pci.product_code, p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  demand_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  eligible_lines as (
    select dl.*
    from demand_lines dl
    where dl.quantity > 0
      or dl.placed_quantity > 0
      or dl.delivered_quantity > 0
  ),
  grouped as (
    select
      el.document_type,
      el.document_id,
      max(el.document_status) as document_status,
      max(el.customer_group_id) as customer_group_id,
      max(el.customer_group_name) as customer_group_name,
      (array_agg(el.vendor) filter (where el.vendor is not null))[1] as vendor,
      max(el.invoice_id) as invoice_id,
      max(el.document_name) as document_name,
      count(*)::integer as item_count,
      count(*) filter (where el.quantity > el.delivered_quantity)::integer as unallocated_item_count
    from eligible_lines el
    group by el.document_type, el.document_id
  ),
  enriched as (
    select
      g.*,
      inv.invoice_status,
      case
        when g.invoice_id is null then false
        else public.preorder_demand_invoice_items_stale(g.document_type, g.document_id, g.invoice_id)
      end as invoice_stale
    from grouped g
    left join public.sales_invoices inv on inv.id = g.invoice_id
  ),
  paged as (
    select e.*, count(*) over ()::integer as total_groups
    from enriched e
    order by e.document_type, e.document_id
    limit v_limit offset v_offset
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'document_type', p.document_type,
          'document_id', p.document_id,
          'document_name', p.document_name,
          'document_status', p.document_status,
          'customer_group_id', p.customer_group_id,
          'customer_group_name', p.customer_group_name,
          'vendor', p.vendor,
          'invoice_id', p.invoice_id,
          'invoice_status', p.invoice_status,
          'invoice_stale', coalesce(p.invoice_stale, false),
          'item_count', p.item_count,
          'unallocated_item_count', p.unallocated_item_count
        )
        order by p.document_type, p.document_id
      ),
      '[]'::jsonb
    ),
    coalesce(max(p.total_groups), 0),
    coalesce(sum(p.item_count), 0),
    coalesce(bool_or(p.document_type = 'shop_order'), false),
    coalesce(bool_or(p.document_type = 'pbc_costing_file'), false)
  into v_groups, v_group_count, v_item_count, v_has_shop, v_has_pbc
  from paged p;

  if v_has_shop then v_sources := array_append(v_sources, 'shop_order'); end if;
  if v_has_pbc then v_sources := array_append(v_sources, 'pbc_costing'); end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'tenant_id', p_tenant_id,
      'procurement_status', v_status,
      'sources_included', to_jsonb(v_sources),
      'group_count', coalesce(jsonb_array_length(v_groups), 0),
      'item_count', v_item_count,
      'total_group_count', v_group_count,
      'limit', v_limit,
      'offset', v_offset,
      'has_more', v_group_count > (v_offset + v_limit)
    ),
    'groups', v_groups
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."normalize_pbc_procurement_status"("p_status" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select case lower(trim(coalesce(p_status, '')))
    when 'placing_order' then 'procuring'
    when 'invoicing' then 'delivered'
    else lower(trim(coalesce(p_status, '')))
  end;
$$;

CREATE OR REPLACE FUNCTION "public"."normalize_shop_order_procurement_status"("p_status" "public"."shop_order_status") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select case
    when p_status = 'ordered'::public.shop_order_status then 'packed'
    else p_status::text
  end;
$$;

CREATE OR REPLACE FUNCTION "public"."staff_mark_pbc_packed"("p_file_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_file record;
  v_result jsonb;
begin
  select * into v_file
  from public.product_based_costing_files
  where id = p_file_id;

  if not found then
    raise exception 'costing file not found: %', p_file_id;
  end if;

  if not public.is_tenant_staff(v_file.tenant_id) then
    raise exception 'access denied';
  end if;

  if public.normalize_pbc_procurement_status(v_file.status) <> 'procuring' then
    raise exception 'costing file must be procuring to mark ready for shipment';
  end if;

  v_result := public.create_invoice_from_preorder_demand_document(
    v_file.tenant_id,
    'pbc_costing_file',
    p_file_id
  );

  update public.product_based_costing_files
  set
    status = 'packed',
    updated_at = now()
  where id = p_file_id;

  return jsonb_build_object(
    'success', true,
    'file_id', p_file_id,
    'status', 'packed',
    'invoice_id', v_result->>'invoice_id',
    'invoice_created', coalesce(v_result->>'created', 'false')::boolean
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."staff_set_catalog_delivered_qty"("p_order_id" bigint, "p_items" "jsonb" DEFAULT '[]'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_desk_tenant_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  v_desk_tenant_id := coalesce(v_order.parent_tenant_id, v_order.tenant_id);

  if not public.is_tenant_staff(v_desk_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_set_catalog_delivered_qty is only valid for vendor_catalog orders.';
  end if;

  update public.shop_orders
  set
    status = 'delivered'::public.shop_order_status,
    fulfilled_at = coalesce(fulfilled_at, now()),
    updated_at = now()
  where id = p_order_id;

  perform public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.order.delivered',
    p_title := format('Order %s delivered', v_order.order_no),
    p_body := 'Open the order for details.'
  );

  return public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
end;
$$;

CREATE OR REPLACE FUNCTION "public"."staff_set_catalog_ordered_qty"("p_order_id" bigint, "p_items" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_desk_tenant_id bigint;
  v_item_row record;
  v_target_qty integer;
  v_allocated integer;
  v_shortfall integer;
  v_product record;
  v_invoice_result jsonb;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  v_desk_tenant_id := coalesce(v_order.parent_tenant_id, v_order.tenant_id);

  if not public.is_tenant_staff(v_desk_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_set_catalog_ordered_qty is only valid for vendor_catalog orders.';
  end if;

  if public.normalize_shop_order_procurement_status(v_order.status) <> 'procuring' then
    raise exception 'order must be procuring to mark ready for shipment';
  end if;

  v_invoice_result := public.create_invoice_from_preorder_demand_document(
    v_desk_tenant_id,
    'shop_order',
    p_order_id
  );

  for v_item_row in
    select oi.*
    from public.shop_order_items oi
    where oi.order_id = p_order_id
  loop
    v_target_qty := coalesce(v_item_row.confirmed_quantity, v_item_row.quantity, 0);

    select coalesce(pd.delivered_quantity, 0)
    into v_allocated
    from public.preorder_demand pd
    where pd.source_type = 'shop_order_item'
      and pd.source_id = v_item_row.id;

    v_shortfall := greatest(v_target_qty - coalesce(v_allocated, 0), 0);

    if v_shortfall > 0 and v_order.billing_profile_id is not null then
        select p.barcode, p.product_code
        into v_product
        from public.products p
        where p.id = v_item_row.product_id;

        perform public.add_demand_bucket_item_internal(
          p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
          p_billing_profile_id => v_order.billing_profile_id,
          p_product_id => v_item_row.product_id,
          p_source_type => 'shop_order_item',
          p_source_id => v_item_row.id,
          p_snapshot => jsonb_build_object(
            'name', coalesce(v_item_row.name, ''),
            'image_url', v_item_row.image_url,
            'barcode', v_product.barcode,
            'product_code', v_product.product_code,
            'note', null
          ),
          p_quantity => v_shortfall
        );

        insert into public.customer_order_backlog_items (
          tenant_id,
          billing_profile_id,
          product_id,
          order_id,
          order_item_id,
          requested_quantity,
          fulfilled_quantity,
          backlog_status
        ) values (
          v_order.tenant_id,
          v_order.billing_profile_id,
          v_item_row.product_id,
          p_order_id,
          v_item_row.id,
          v_shortfall,
          0,
          'open'
        )
        on conflict (tenant_id, billing_profile_id, product_id)
        do update set
          requested_quantity = customer_order_backlog_items.requested_quantity + excluded.requested_quantity,
          backlog_status = 'open',
          updated_at = now();
    end if;
  end loop;

  update public.shop_orders
  set
    status = 'packed'::public.shop_order_status,
    placed_at = coalesce(placed_at, now()),
    updated_at = now()
  where id = p_order_id;

  perform public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.order.packed',
    p_title := format('%s is packing', v_order.order_no),
    p_body := 'We will mark it on the way when it ships.'
  );

  return public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
end;
$$;

CREATE OR REPLACE FUNCTION "public"."sync_invoice_from_preorder_demand_document"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_operating_tenant_id bigint;
  v_invoice_id bigint;
  v_doc_status text;
  v_invoice_status public.global_invoice_status;
  v_items jsonb := '[]'::jsonb;
  v_remove_ids jsonb := '[]'::jsonb;
  v_payload jsonb;
  v_result jsonb;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      o.global_invoice_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_operating_tenant_id, v_invoice_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_operating_tenant_id is null then
      raise exception 'shop order not found or not vendor_catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      f.invoice_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_operating_tenant_id, v_invoice_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id;

    if v_operating_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_operating_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_doc_status <> 'packed' then
    raise exception 'document must be packed to sync invoice from demand';
  end if;

  if v_invoice_id is null then
    raise exception 'document has no linked invoice';
  end if;

  select si.invoice_status
  into v_invoice_status
  from public.sales_invoices si
  where si.id = v_invoice_id;

  if v_invoice_status is null then
    raise exception 'invoice not found';
  end if;

  if v_invoice_status not in (
    'draft'::public.global_invoice_status,
    'proforma_generated'::public.global_invoice_status
  ) then
    raise exception 'invoice is not editable (status: %)', v_invoice_status;
  end if;

  v_items := public.build_preorder_demand_invoice_items(v_doc_type, p_document_id);

  if jsonb_array_length(v_items) = 0 then
    raise exception 'at least one stock pick is required to sync invoice';
  end if;

  select coalesce(jsonb_agg(sii.id), '[]'::jsonb)
  into v_remove_ids
  from public.sales_invoice_items sii
  where sii.invoice_id = v_invoice_id;

  v_payload := jsonb_build_object(
    'items', v_items,
    'remove_item_ids', v_remove_ids
  );

  v_result := public.update_sales_invoice_from_payload(
    coalesce(v_operating_tenant_id, p_tenant_id),
    v_invoice_id,
    v_payload
  );

  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'failed to sync invoice from demand');
  end if;

  return v_result || jsonb_build_object(
    'invoice_id', v_invoice_id,
    'synced', true
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."upsert_preorder_demand"("p_tenant_id" bigint, "p_source_type" "public"."preorder_demand_source_type", "p_source_id" bigint, "p_vendor_id" bigint DEFAULT NULL::bigint, "p_placed_quantity" integer DEFAULT NULL::integer, "p_stock_picks" "jsonb" DEFAULT NULL::"jsonb", "p_notes" "text" DEFAULT NULL::"text") RETURNS "public"."preorder_demand"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.preorder_demand;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_open_qty integer;
  v_delivered integer;
  v_placed integer;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;
  if p_source_id is null then
    raise exception 'source_id is required';
  end if;

  select g.tenant_id, g.open_qty, g.document_status
  into v_line_tenant_id, v_open_qty, v_doc_status
  from public.get_procurement_demand_open_qty(p_source_type, p_source_id) g;

  if v_line_tenant_id is null then
    raise exception 'demand line not found';
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_line_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_line_tenant_id <> p_tenant_id then
    if not exists (
      select 1 from public.tenants t
      where t.id = v_line_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_parent_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand line';
    end if;
  end if;

  if v_doc_status not in ('procuring', 'packed') then
    raise exception 'document is not open for preorder demand updates';
  end if;

  if p_placed_quantity is not null and v_doc_status <> 'procuring' then
    raise exception 'placed_quantity can only be updated while procuring';
  end if;

  if p_stock_picks is not null and v_doc_status <> 'procuring' then
    raise exception 'stock_picks can only be updated while procuring';
  end if;

  if p_placed_quantity is not null and coalesce(p_placed_quantity, 0) < 0 then
    raise exception 'placed_quantity cannot be negative';
  end if;

  if p_stock_picks is not null and not public.validate_preorder_stock_picks(p_stock_picks) then
    raise exception 'invalid stock_picks payload';
  end if;

  v_delivered := case
    when p_stock_picks is not null then public.sum_preorder_stock_picks(p_stock_picks)
    else null
  end;

  select pd.* into v_row
  from public.preorder_demand pd
  where pd.source_type = p_source_type
    and pd.source_id = p_source_id;

  if found then
    v_placed := coalesce(p_placed_quantity, v_row.placed_quantity, 0);
  else
    v_placed := coalesce(p_placed_quantity, 0);
  end if;

  if v_delivered is not null and v_delivered > coalesce(v_open_qty, 0) then
    raise exception 'delivered_quantity cannot exceed need quantity';
  end if;

  insert into public.preorder_demand (
    tenant_id,
    source_type,
    source_id,
    vendor_id,
    placed_quantity,
    delivered_quantity,
    stock_picks,
    notes,
    updated_by_user_id
  ) values (
    v_line_tenant_id,
    p_source_type,
    p_source_id,
    coalesce(p_vendor_id, case when found then v_row.vendor_id else null end),
    v_placed,
    coalesce(v_delivered, case when found then v_row.delivered_quantity else 0 end, 0),
    coalesce(p_stock_picks, case when found then v_row.stock_picks else '[]'::jsonb end, '[]'::jsonb),
    coalesce(nullif(trim(p_notes), ''), case when found then v_row.notes else null end),
    auth.uid()
  )
  on conflict (source_type, source_id) do update set
    vendor_id = case when p_vendor_id is not null then p_vendor_id else preorder_demand.vendor_id end,
    placed_quantity = case when p_placed_quantity is not null then p_placed_quantity else preorder_demand.placed_quantity end,
    delivered_quantity = case when v_delivered is not null then v_delivered else preorder_demand.delivered_quantity end,
    stock_picks = case when p_stock_picks is not null then p_stock_picks else preorder_demand.stock_picks end,
    notes = case when p_notes is not null then nullif(trim(p_notes), '') else preorder_demand.notes end,
    updated_by_user_id = auth.uid(),
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;
commit;

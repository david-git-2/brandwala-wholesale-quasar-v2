-- Allow stock picks while procuring; create invoice when marking ready for shipment.

create or replace function public.upsert_preorder_demand(
  p_tenant_id bigint,
  p_source_type public.preorder_demand_source_type,
  p_source_id bigint,
  p_vendor_id bigint default null,
  p_placed_quantity integer default null,
  p_stock_picks jsonb default null,
  p_notes text default null
)
returns public.preorder_demand
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.preorder_demand;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_delivered integer;
  v_placed integer;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;
  if p_source_id is null then
    raise exception 'source_id is required';
  end if;

  select g.tenant_id, g.document_status
  into v_line_tenant_id, v_doc_status
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

  if v_doc_status not in ('procuring', 'ready_for_shipment') then
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

  if v_delivered is not null and v_delivered > v_placed then
    raise exception 'delivered_quantity cannot exceed placed_quantity';
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

create or replace function public.create_invoice_from_preorder_demand_document(
  p_tenant_id bigint,
  p_document_type text,
  p_document_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
    'issue', true
  );

  v_result := public.create_sales_invoice_from_payload(v_operating_tenant_id, v_payload);

  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'failed to create invoice from demand');
  end if;

  v_invoice_id := (v_result->>'invoice_id')::bigint;

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

  return v_result || jsonb_build_object('created', true);
end;
$$;

create or replace function public.staff_mark_pbc_ready_for_shipment(p_file_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
    status = 'ready_for_shipment',
    updated_at = now()
  where id = p_file_id;

  return jsonb_build_object(
    'success', true,
    'file_id', p_file_id,
    'status', 'ready_for_shipment',
    'invoice_id', v_result->>'invoice_id',
    'invoice_created', coalesce(v_result->>'created', 'false')::boolean
  );
end;
$$;

create or replace function public.staff_set_catalog_ordered_qty(
  p_order_id bigint,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_ordered_qty integer;
  v_item_row record;
  v_target_qty integer;
  v_shortfall integer;
  v_product record;
  v_invoice_result jsonb;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_set_catalog_ordered_qty is only valid for vendor_catalog orders.';
  end if;

  if public.normalize_shop_order_procurement_status(v_order.status) <> 'procuring' then
    raise exception 'order must be procuring to mark ready for shipment';
  end if;

  v_invoice_result := public.create_invoice_from_preorder_demand_document(
    v_order.tenant_id,
    'shop_order',
    p_order_id
  );

  for v_elem in select * from jsonb_array_elements(p_items) loop
    v_item_id := (v_elem->>'id')::bigint;
    v_ordered_qty := (v_elem->>'ordered_quantity')::integer;

    select * into v_item_row from public.shop_order_items where id = v_item_id and order_id = p_order_id;

    if v_item_row.id is not null then
      v_target_qty := coalesce(v_item_row.confirmed_quantity, v_item_row.quantity, 0);
      v_shortfall := v_target_qty - coalesce(v_ordered_qty, 0);

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
          p_source_id => v_item_id,
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
          v_item_id,
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
    end if;
  end loop;

  update public.shop_orders
  set
    status = 'ready_for_shipment'::public.shop_order_status,
    placed_at = coalesce(placed_at, now()),
    updated_at = now()
  where id = p_order_id;

  perform public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.order.ready_for_shipment',
    p_title := format('%s is packing', v_order.order_no),
    p_body := 'We will mark it on the way when it ships.'
  );

  return public.get_shop_order_for_staff(v_order.tenant_id, p_order_id);
end;
$$;

grant execute on function public.create_invoice_from_preorder_demand_document(bigint, text, bigint) to authenticated;
grant execute on function public.staff_mark_pbc_ready_for_shipment(bigint) to authenticated;

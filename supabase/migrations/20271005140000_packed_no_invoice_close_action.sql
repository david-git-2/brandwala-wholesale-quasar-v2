-- Packed transition: status only (no proforma). Allow close_action on stock_picks.

CREATE OR REPLACE FUNCTION public.validate_preorder_stock_picks(p_stock_picks jsonb) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
  v_elem jsonb;
  v_stock_id bigint;
  v_qty integer;
  v_close_action text;
begin
  if p_stock_picks is null then
    return true;
  end if;
  if jsonb_typeof(p_stock_picks) <> 'array' then
    return false;
  end if;

  for v_elem in select value from jsonb_array_elements(p_stock_picks)
  loop
    v_stock_id := nullif(v_elem->>'global_stock_id', '')::bigint;
    v_qty := coalesce((v_elem->>'quantity')::integer, 0);
    if v_stock_id is null or v_qty <= 0 then
      return false;
    end if;
    v_close_action := lower(trim(coalesce(v_elem->>'close_action', '')));
    if v_close_action <> ''
      and v_close_action not in ('take', 'condition', 'return') then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

CREATE OR REPLACE FUNCTION public.staff_mark_pbc_packed(p_file_id bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_file record;
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
    raise exception 'costing file must be procuring to mark packed';
  end if;

  update public.product_based_costing_files
  set
    status = 'packed',
    updated_at = now()
  where id = p_file_id;

  return jsonb_build_object(
    'success', true,
    'file_id', p_file_id,
    'status', 'packed'
  );
end;
$$;

CREATE OR REPLACE FUNCTION public.staff_set_catalog_ordered_qty(
  p_order_id bigint,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_order record;
  v_desk_tenant_id bigint;
  v_item_row record;
  v_target_qty integer;
  v_allocated integer;
  v_shortfall integer;
  v_product record;
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
    raise exception 'order must be procuring to mark packed';
  end if;

  update public.shop_orders
  set
    status = 'packed'::public.shop_order_status,
    placed_at = coalesce(placed_at, now()),
    updated_at = now()
  where id = p_order_id;

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

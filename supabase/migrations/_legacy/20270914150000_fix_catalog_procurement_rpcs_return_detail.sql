-- Restore catalog procurement RPCs to return staff order detail (jsonb).
-- 20270201030000_catalog_procurement_rpcs.sql regressed them to RETURNS void while
-- the web client parses the response via parseStaffShopOrderDetailResponse().

drop function if exists public.staff_start_catalog_procurement(bigint);
drop function if exists public.staff_set_catalog_ordered_qty(bigint, jsonb);
drop function if exists public.staff_set_catalog_delivered_qty(bigint, jsonb);

create or replace function public.staff_start_catalog_procurement(p_order_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_start_catalog_procurement is only valid for vendor_catalog orders.';
  end if;

  if v_order.status <> 'confirmed' then
    raise exception 'Order % cannot start procurement from status %', p_order_id, v_order.status;
  end if;

  update public.shop_order_items
  set
    confirmed_quantity = coalesce(confirmed_quantity, quantity),
    updated_at = now()
  where order_id = p_order_id;

  update public.shop_orders
  set
    status = 'procuring'::public.shop_order_status,
    updated_at = now()
  where id = p_order_id;

  return public.get_shop_order_for_staff(v_order.tenant_id, p_order_id);
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

create or replace function public.staff_set_catalog_delivered_qty(
  p_order_id bigint,
  p_items jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
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

  return public.get_shop_order_for_staff(v_order.tenant_id, p_order_id);
end;
$$;

revoke all on function public.staff_start_catalog_procurement(bigint) from public;
revoke all on function public.staff_start_catalog_procurement(bigint) from anon;
grant execute on function public.staff_start_catalog_procurement(bigint) to authenticated;

revoke all on function public.staff_set_catalog_ordered_qty(bigint, jsonb) from public;
revoke all on function public.staff_set_catalog_ordered_qty(bigint, jsonb) from anon;
grant execute on function public.staff_set_catalog_ordered_qty(bigint, jsonb) to authenticated;

revoke all on function public.staff_set_catalog_delivered_qty(bigint, jsonb) from public;
revoke all on function public.staff_set_catalog_delivered_qty(bigint, jsonb) from anon;
grant execute on function public.staff_set_catalog_delivered_qty(bigint, jsonb) to authenticated;

notify pgrst, 'reload schema';

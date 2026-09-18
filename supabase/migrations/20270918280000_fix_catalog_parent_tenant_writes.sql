-- Parent desk staff: catalog wholesale write RPCs must match get_shop_order_for_staff
-- access (tenant_id OR parent_tenant_id), not strict tenant_id = p_tenant_id only.

create or replace function public.update_catalog_order_item_for_staff(
  p_tenant_id bigint,
  p_order_id bigint,
  p_item_id bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_product_id bigint;
  v_product_weight_gm numeric;
  v_package_weight_gm numeric;
begin
  if p_tenant_id is null or p_order_id is null or p_item_id is null then
    raise exception 'tenant, order, and item required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found
     or (v_order.tenant_id is distinct from p_tenant_id
         and v_order.parent_tenant_id is distinct from p_tenant_id) then
    raise exception 'order not found';
  end if;

  update public.shop_order_items soi
  set
    weight_kg = case when p_payload ? 'weight_kg' then (p_payload->>'weight_kg')::numeric else soi.weight_kg end,
    cost_price_amount = case when p_payload ? 'cost_price_amount' then (p_payload->>'cost_price_amount')::numeric else soi.cost_price_amount end,
    staff_offer_amount = case when p_payload ? 'staff_offer_amount' then (p_payload->>'staff_offer_amount')::numeric else soi.staff_offer_amount end,
    is_first_offer_manual = case when p_payload ? 'is_first_offer_manual' then coalesce((p_payload->>'is_first_offer_manual')::boolean, false) else soi.is_first_offer_manual end,
    customer_offer_amount = case when p_payload ? 'customer_offer_amount' then (p_payload->>'customer_offer_amount')::numeric else soi.customer_offer_amount end,
    customer_offer_currency_id = case when p_payload ? 'customer_offer_currency_id' then nullif(p_payload->>'customer_offer_currency_id', '')::bigint else soi.customer_offer_currency_id end,
    final_price_amount = case when p_payload ? 'final_price_amount' then (p_payload->>'final_price_amount')::numeric else soi.final_price_amount end,
    is_final_offer_manual = case when p_payload ? 'is_final_offer_manual' then coalesce((p_payload->>'is_final_offer_manual')::boolean, false) else soi.is_final_offer_manual end,
    confirmed_quantity = case when p_payload ? 'confirmed_quantity' then (p_payload->>'confirmed_quantity')::integer else soi.confirmed_quantity end,
    quantity = case when p_payload ? 'quantity' then (p_payload->>'quantity')::integer else soi.quantity end,
    updated_at = now()
  where soi.id = p_item_id and soi.order_id = p_order_id;

  select soi.product_id into v_product_id
  from public.shop_order_items soi
  where soi.id = p_item_id and soi.order_id = p_order_id;

  v_product_weight_gm := nullif(p_payload->>'product_weight_gm', '')::numeric;
  v_package_weight_gm := nullif(p_payload->>'package_weight_gm', '')::numeric;

  if v_product_id is not null
     and (
       (v_product_weight_gm is not null and v_product_weight_gm > 0)
       or (v_package_weight_gm is not null and v_package_weight_gm > 0)
     ) then
    update public.products p
    set
      product_weight = case
        when v_product_weight_gm is not null and v_product_weight_gm > 0 then v_product_weight_gm
        else p.product_weight
      end,
      package_weight = case
        when v_package_weight_gm is not null and v_package_weight_gm > 0 then v_package_weight_gm
        else p.package_weight
      end,
      updated_at = now()
    where p.id = v_product_id;
  end if;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$$;


create or replace function public.update_catalog_order_rates_for_staff(
  p_tenant_id bigint,
  p_order_id bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant and order required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found
     or (v_order.tenant_id is distinct from p_tenant_id
         and v_order.parent_tenant_id is distinct from p_tenant_id) then
    raise exception 'order not found';
  end if;

  update public.shop_orders o
  set
    conversion_rate = case when p_payload ? 'conversion_rate' then (p_payload->>'conversion_rate')::numeric else o.conversion_rate end,
    cargo_rate = case when p_payload ? 'cargo_rate' then (p_payload->>'cargo_rate')::numeric else o.cargo_rate end,
    profit_rate = case when p_payload ? 'profit_rate' then (p_payload->>'profit_rate')::numeric else o.profit_rate end,
    first_offer_rate = case when p_payload ? 'first_offer_rate' then (p_payload->>'first_offer_rate')::numeric else o.first_offer_rate end,
    final_offer_rate = case when p_payload ? 'final_offer_rate' then (p_payload->>'final_offer_rate')::numeric else o.final_offer_rate end,
    profit_basis = case when p_payload ? 'profit_basis' then nullif(p_payload->>'profit_basis', '') else o.profit_basis end,
    updated_at = now()
  where o.id = p_order_id;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$$;


create or replace function public.staff_finalize_catalog_prices(
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
  v_desk_tenant_id bigint;
  v_elem jsonb;
  v_item_id bigint;
  v_final_amount numeric;
  v_final_currency_id bigint;
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
    raise exception 'staff_finalize_catalog_prices is only valid for vendor_catalog orders.';
  end if;

  if v_order.status <> 'countered'::public.shop_order_status then
    raise exception 'Order % cannot send final offer from status %', p_order_id, v_order.status;
  end if;

  for v_elem in select * from jsonb_array_elements(p_items) loop
    v_item_id := (v_elem->>'id')::bigint;
    v_final_amount := (v_elem->>'final_offer_amount')::numeric;
    v_final_currency_id := (v_elem->>'final_offer_currency_id')::bigint;

    update public.shop_order_items
    set
      final_price_amount = v_final_amount,
      final_price_currency_id = v_final_currency_id,
      is_final_offer_manual = coalesce((v_elem->>'is_final_offer_manual')::boolean, is_final_offer_manual),
      negotiation_status = 'final_offered',
      final_offer_at = now(),
      updated_at = now()
    where id = v_item_id and order_id = p_order_id;
  end loop;

  update public.shop_orders
  set
    status = 'final_offered'::public.shop_order_status,
    updated_at = now()
  where id = p_order_id;

  perform public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.offer.final',
    p_title := format('Confirm %s', v_order.order_no),
    p_body := 'Check price and quantity, then confirm.'
  );

  return public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
end;
$$;


create or replace function public.staff_start_catalog_procurement(p_order_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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

  return public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
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
  v_desk_tenant_id bigint;
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

  return public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
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

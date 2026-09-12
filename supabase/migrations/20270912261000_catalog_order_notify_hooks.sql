begin;

-- customer_confirm_shop_order
create or replace function public.customer_confirm_shop_order(p_order_id bigint)
returns void
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

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'customer_confirm_shop_order is only valid for vendor_catalog orders.';
  end if;

  if v_order.status <> 'final_offered' and v_order.status <> 'priced' then
    raise exception 'Order % cannot be confirmed from status %', p_order_id, v_order.status;
  end if;

  update public.shop_order_items
  set
    confirmed_quantity = coalesce(confirmed_quantity, quantity),
    updated_at = now()
  where order_id = p_order_id;

  update public.shop_orders
  set
    status = 'confirmed'::public.shop_order_status,
    updated_at = now()
  where id = p_order_id;

  perform public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := true,
    p_notify_customer := false,
    p_event_type := 'catalog.order.confirmed',
    p_title := format('Order %s confirmed', v_order.order_no),
    p_body := 'Customer confirmed the order. Start procurement when ready.'
  );
end;
$$;

-- customer_counter_offer (vendor_catalog branch only — notification hooks)
create or replace function public.customer_counter_offer(p_order_id bigint, p_items jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_item record;
  v_has_counter boolean := false;
begin
  select * into v_order from public.shop_orders where id = p_order_id;

  if v_order.id is null then
    raise exception 'order not found';
  end if;

  if v_order.shop_type_snapshot = 'vendor_catalog' then
    if not coalesce(v_order.is_negotiable_snapshot, false) then
      raise exception 'Order % is not negotiable', p_order_id;
    end if;

    if v_order.status <> 'priced'::public.shop_order_status then
      raise exception 'Catalog order % cannot respond from status %', p_order_id, v_order.status;
    end if;

    for v_item in
      select * from jsonb_to_recordset(p_items) as x(
        id bigint,
        customer_offer_amount numeric,
        customer_offer_currency_id bigint
      )
    loop
      update public.shop_order_items
      set
        customer_offer_amount = v_item.customer_offer_amount,
        customer_offer_currency_id = v_item.customer_offer_currency_id,
        customer_counter_at = now(),
        updated_at = now()
      where id = v_item.id and order_id = p_order_id;
    end loop;

    select exists (
      select 1
      from public.shop_order_items soi
      where soi.order_id = p_order_id
        and soi.customer_offer_amount is not null
        and soi.staff_offer_amount is not null
        and soi.customer_offer_amount <> soi.staff_offer_amount
    )
    into v_has_counter;

    if v_has_counter then
      update public.shop_orders
      set
        status = 'countered'::public.shop_order_status,
        negotiate_round = negotiate_round + 1,
        updated_at = now()
      where id = p_order_id;

      perform public.notify_catalog_shop_order(
        p_order_id := p_order_id,
        p_notify_staff := true,
        p_notify_customer := false,
        p_event_type := 'catalog.offer.countered',
        p_title := format('Customer countered %s', v_order.order_no),
        p_body := 'Set the final offer when ready.'
      );
    else
      update public.shop_order_items
      set
        confirmed_quantity = coalesce(confirmed_quantity, quantity),
        updated_at = now()
      where order_id = p_order_id;

      update public.shop_orders
      set
        status = 'confirmed'::public.shop_order_status,
        updated_at = now()
      where id = p_order_id;

      perform public.notify_catalog_shop_order(
        p_order_id := p_order_id,
        p_notify_staff := true,
        p_notify_customer := false,
        p_event_type := 'catalog.order.confirmed',
        p_title := format('Order %s confirmed', v_order.order_no),
        p_body := 'Customer accepted all first-offer prices.'
      );
    end if;
  else
    if not public.is_cart_owner(v_order.customer_group_id, v_order.tenant_id) then
      raise exception 'access denied';
    end if;

    for v_item in
      select * from jsonb_to_recordset(p_items) as x(
        id bigint,
        customer_offer_amount numeric,
        customer_offer_currency_id bigint
      )
    loop
      update public.shop_order_items
      set
        customer_offer_amount = v_item.customer_offer_amount,
        customer_offer_currency_id = v_item.customer_offer_currency_id,
        updated_at = now()
      where id = v_item.id and order_id = p_order_id;
    end loop;

    update public.shop_orders
    set
      status = 'negotiating'::public.shop_order_status,
      negotiate_round = negotiate_round + 1,
      updated_at = now()
    where id = p_order_id;
  end if;
end;
$$;

-- staff_price_shop_order
create or replace function public.staff_price_shop_order(
  p_order_id bigint,
  p_items jsonb,
  p_profit_basis text default null,
  p_fx_rate numeric default null,
  p_cargo_rate numeric default null,
  p_profit_pct numeric default null
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
  v_offer_amount numeric;
  v_offer_currency_id bigint;
  v_weight_kg numeric;
  v_is_manual boolean;
  v_product_id bigint;
  v_product_weight_gm numeric;
  v_package_weight_gm numeric;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_price_shop_order is only valid for vendor_catalog orders.';
  end if;

  if v_order.status not in ('submitted'::public.shop_order_status, 'costing_pending'::public.shop_order_status) then
    raise exception 'Order % cannot send first offer from status %', p_order_id, v_order.status;
  end if;

  update public.shop_orders
  set
    profit_basis = coalesce(p_profit_basis, profit_basis),
    conversion_rate = coalesce(p_fx_rate, conversion_rate),
    cargo_rate = coalesce(p_cargo_rate, cargo_rate),
    first_offer_rate = coalesce(p_profit_pct, first_offer_rate),
    profit_rate = coalesce(p_profit_pct, profit_rate),
    status = 'priced'::public.shop_order_status,
    updated_at = now()
  where id = p_order_id;

  for v_elem in select * from jsonb_array_elements(p_items) loop
    v_item_id := (v_elem->>'id')::bigint;
    v_offer_amount := (v_elem->>'staff_offer_amount')::numeric;
    v_offer_currency_id := (v_elem->>'staff_offer_currency_id')::bigint;
    v_weight_kg := coalesce(
      nullif(v_elem->>'weight_kg', '')::numeric,
      nullif(v_elem->>'gross_weight_kg', '')::numeric,
      null
    );
    v_is_manual := coalesce((v_elem->>'is_first_offer_manual')::boolean, false);
    v_product_weight_gm := nullif(v_elem->>'product_weight_gm', '')::numeric;
    v_package_weight_gm := nullif(v_elem->>'package_weight_gm', '')::numeric;

    update public.shop_order_items
    set
      staff_offer_amount = v_offer_amount,
      staff_offer_currency_id = v_offer_currency_id,
      weight_kg = coalesce(v_weight_kg, weight_kg),
      is_first_offer_manual = v_is_manual,
      negotiation_status = 'priced',
      staff_offer_at = now(),
      updated_at = now()
    where id = v_item_id and order_id = p_order_id;

    select soi.product_id
    into v_product_id
    from public.shop_order_items soi
    where soi.id = v_item_id and soi.order_id = p_order_id;

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
  end loop;

  perform public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.offer.sent',
    p_title := 'Review your offer',
    p_body := format('Order %s is ready for your review.', v_order.order_no)
  );

  return public.get_shop_order_for_staff(v_order.tenant_id, p_order_id);
end;
$$;

-- staff_finalize_catalog_prices
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
  v_elem jsonb;
  v_item_id bigint;
  v_final_amount numeric;
  v_final_currency_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
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
    p_title := 'Confirm price and quantity',
    p_body := format('Order %s — confirm your final quantities.', v_order.order_no)
  );

  return public.get_shop_order_for_staff(v_order.tenant_id, p_order_id);
end;
$$;

-- update_shop_order_status_for_staff
create or replace function public.update_shop_order_status_for_staff(
  p_tenant_id bigint,
  p_order_id bigint,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
begin
  if p_tenant_id is null or p_order_id is null or p_status is null then
    raise exception 'tenant, order, and status required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found or v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'order not found';
  end if;

  update public.shop_orders o
  set
    status = p_status::public.shop_order_status,
    updated_at = now()
  where o.id = p_order_id;

  if p_status = 'cancelled'
     and v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum then
    perform public.notify_catalog_shop_order(
      p_order_id := p_order_id,
      p_notify_staff := false,
      p_notify_customer := true,
      p_event_type := 'catalog.order.cancelled',
      p_title := format('Order %s cancelled', v_order.order_no),
      p_body := 'This order was cancelled by staff.'
    );
  end if;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$$;

-- staff_set_catalog_ordered_qty (ready_for_shipment)
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
    p_title := 'On the way',
    p_body := format('Order %s is ready for shipment.', v_order.order_no)
  );

  return public.get_shop_order_for_staff(v_order.tenant_id, p_order_id);
end;
$$;

-- staff_set_catalog_delivered_qty
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
    p_title := 'Delivered',
    p_body := format('Order %s has been delivered.', v_order.order_no)
  );

  return public.get_shop_order_for_staff(v_order.tenant_id, p_order_id);
end;
$$;

-- submit_shop_order_from_cart — notify staff on new catalog order
create or replace function public.submit_shop_order_from_cart(
  p_cart_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_recipient_phone_secondary text default null,
  p_shipping_district text default null,
  p_shipping_thana text default null,
  p_billing_profile_id bigint default null,
  p_is_prepaid boolean default false,
  p_delivery_instructions text default null,
  p_cod_charge_amount numeric default 0,
  p_delivery_charge_amount numeric default 0,
  p_print_charge_amount numeric default 0,
  p_packing_charge_amount numeric default 0,
  p_discount_amount numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart public.shop_carts%rowtype;
  v_shop public.shops%rowtype;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_item_count integer;
  v_result jsonb;
  v_billing_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci record;
  v_rem_alloc_qty integer;
  v_rem_override_qty integer;
begin
  select * into v_cart from public.shop_carts where id = p_cart_id and status = 'active';
  if v_cart.id is null then
    raise exception 'active cart not found';
  end if;

  if not public.is_cart_owner(v_cart.customer_group_id, v_cart.tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_shop from public.shops where id = v_cart.shop_id;
  if v_shop.id is null or not v_shop.is_active then
    raise exception 'shop not found or inactive';
  end if;

  select can_place_order, can_negotiate
  into v_can_place_order, v_can_negotiate
  from public.get_shop_permissions_for_customer(v_shop.id);

  if coalesce(v_can_place_order, false) is not true then
    raise exception 'checkout not allowed for this customer group';
  end if;

  select count(*) into v_item_count from public.shop_cart_items where cart_id = p_cart_id;
  if v_item_count = 0 then
    raise exception 'cart is empty';
  end if;

  if v_shop.shop_type = 'dropship' then
    if exists (
      select 1 from public.shop_cart_items ci
      where ci.cart_id = p_cart_id
        and ci.customer_sell_price_currency_id = ci.unit_minimum_sell_price_currency_id
        and ci.customer_sell_price_amount < ci.unit_minimum_sell_price_amount
    ) then
      raise exception 'price floor violation: some items are priced below the minimum sell price';
    end if;
  end if;

  v_billing_profile_id := p_billing_profile_id;
  if v_billing_profile_id is null then
    v_billing_profile_id := public.resolve_billing_profile_for_customer_group(v_cart.tenant_id, v_cart.customer_group_id);
  end if;

  if v_shop.shop_type = 'vendor_catalog' then
    if v_shop.order_mode <> 'procurement_intent' then
      raise exception 'invalid order mode for vendor catalog shop';
    end if;
    v_order_status := 'submitted';
  else
    if v_shop.order_mode = 'checkout_fixed' then
      v_order_status := 'confirmed';
    else
      v_order_status := 'submitted';
    end if;
  end if;

  select public.generate_shop_order_number(v_cart.tenant_id, v_cart.shop_id) into v_order_no;

  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  if v_phone is not null then
    v_profile := public.upsert_recipient_profile_and_address(
      p_tenant_id => v_cart.tenant_id,
      p_name => p_recipient_name,
      p_phone => v_phone,
      p_phone_secondary => p_recipient_phone_secondary,
      p_address => p_shipping_address,
      p_district => p_shipping_district,
      p_thana => p_shipping_thana
    );
    v_recipient_profile_id := (v_profile->>'id')::bigint;
  end if;

  insert into public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id,
    order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot,
    status, negotiate_round,
    recipient_name, recipient_phone, recipient_phone_secondary,
    shipping_address, shipping_district, shipping_thana,
    recipient_profile_id, billing_profile_id,
    created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  )
  values (
    v_cart.tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id,
    v_order_no, 'Order for ' || coalesce(nullif(trim(coalesce(p_recipient_name, '')), ''), 'customer'),
    v_shop.shop_type, v_shop.order_mode,
    coalesce(v_shop.is_negotiable, false) and coalesce(v_can_negotiate, false),
    v_order_status, case when v_order_status = 'negotiating' then 1 else 0 end,
    nullif(trim(coalesce(p_recipient_name, '')), ''), v_phone, nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''),
    nullif(trim(coalesce(p_shipping_address, '')), ''), nullif(trim(coalesce(p_shipping_district, '')), ''), nullif(trim(coalesce(p_shipping_thana, '')), ''),
    v_recipient_profile_id, v_billing_profile_id,
    public.current_user_email(),
    p_cod_charge_amount, p_delivery_charge_amount, p_print_charge_amount, p_packing_charge_amount, p_discount_amount,
    p_is_prepaid, p_delivery_instructions, v_shop.deduct_charges_from_margin,
    false, false, v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
  )
  returning id into v_order_id;

  insert into public.shop_order_items (
    order_id, product_id, global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    cost_price_amount, cost_price_currency_id
  )
  select
    v_order_id, ci.product_id, ci.global_stock_id, ci.global_stock_allocation_id,
    ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    case when v_shop.shop_type = 'dropship' then ci.customer_sell_price_amount else null end,
    case when v_shop.shop_type = 'dropship' then ci.customer_sell_price_currency_id else null end,
    case
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, ci.unit_list_price_amount)
      else null
    end,
    case
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id, ci.unit_list_price_currency_id)
      else null
    end,
    case when v_shop.shop_type = 'dropship' then public.resolve_shop_order_item_landed_cost(ci.global_stock_id, null, ci.unit_list_price_amount) else null end,
    case when v_shop.shop_type = 'dropship' then v_shop.buy_currency_id else null end
  from public.shop_cart_items ci
  where ci.cart_id = p_cart_id;

  if v_shop.shop_type = 'dropship' then
    for v_ci in select * from public.shop_cart_items where cart_id = p_cart_id loop
      if v_ci.product_id is not null and v_ci.global_stock_allocation_id is not null then
        update public.shop_product_listings
        set display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
        where shop_id = v_shop.id
          and product_id = v_ci.product_id
          and global_stock_allocation_id = v_ci.global_stock_allocation_id
          and display_quantity_override is not null;
      end if;

      if v_ci.global_stock_allocation_id is not null then
        update public.global_stock_allocations
        set quantity = greatest(0, quantity - v_ci.quantity)
        where id = v_ci.global_stock_allocation_id;
      end if;

      if v_ci.global_stock_id is not null then
        update public.global_stocks
        set quantity = greatest(0, quantity - v_ci.quantity)
        where id = v_ci.global_stock_id;
      end if;

      if v_ci.product_id is not null and v_ci.global_stock_allocation_id is not null then
        select gsa.quantity into v_rem_alloc_qty
        from public.global_stock_allocations gsa
        where gsa.id = v_ci.global_stock_allocation_id;

        select display_quantity_override into v_rem_override_qty
        from public.shop_product_listings
        where shop_id = v_shop.id
          and product_id = v_ci.product_id
          and global_stock_allocation_id = v_ci.global_stock_allocation_id;

        if coalesce(v_rem_override_qty, v_rem_alloc_qty, 0) <= 0 then
          update public.shop_product_listings
          set is_active = false
          where shop_id = v_shop.id
            and product_id = v_ci.product_id
            and global_stock_allocation_id = v_ci.global_stock_allocation_id;
        end if;
      end if;
    end loop;
  end if;

  delete from public.shop_stock_reservations
  where cart_item_id in (select id from public.shop_cart_items where cart_id = p_cart_id);

  update public.shop_carts
  set status = 'converted', updated_at = now()
  where id = p_cart_id;

  if v_shop.shop_type = 'vendor_catalog' then
    perform public.notify_catalog_shop_order(
      p_order_id := v_order_id,
      p_notify_staff := true,
      p_notify_customer := false,
      p_event_type := 'catalog.order.created',
      p_title := format('New catalog order %s', v_order_no),
      p_body := format('%s line(s) placed', v_item_count)
    );
  end if;

  select jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_order_status
  ) into v_result;

  return v_result;
end;
$$;

commit;


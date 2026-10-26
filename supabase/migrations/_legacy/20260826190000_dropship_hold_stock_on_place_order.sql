-- Dropship place order: hold stock (sellable → held) instead of immediate deduction.
-- Invoice posting consumes held stock; order delete releases held → sellable.

create or replace function public.submit_dropship_order_from_cart(
  p_shop_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_recipient_phone_secondary text default null,
  p_shipping_district text default null,
  p_shipping_thana text default null,
  p_shipping_post_code text default null,
  p_billing_profile_id bigint default null,
  p_is_prepaid boolean default false,
  p_delivery_instructions text default null,
  p_cod_charge_amount numeric default 0,
  p_delivery_charge_amount numeric default 0,
  p_print_charge_amount numeric default 0,
  p_packing_charge_amount numeric default 0,
  p_discount_amount numeric default 0,
  p_recipient_pays_delivery boolean default true,
  p_recipient_pays_cod boolean default true
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_shop public.shops%rowtype;
  v_cart public.shop_carts%rowtype;
  v_customer_group_id bigint;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_can_place_order boolean;
  v_item_count integer;
  v_result jsonb;
  v_billing_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci record;
  v_rem_override_qty integer;
  v_rem_sellable_qty integer;
  v_deduct_delivery_from_margin boolean;
  v_deduct_cod_from_margin boolean;
  v_parent_tenant_id bigint;
  v_stock public.global_stocks%rowtype;
  v_held_stock_id bigint;
begin
  select * into v_shop
  from public.shops
  where id = p_shop_id
    and is_active = true;

  if v_shop.id is null then
    raise exception 'shop not found or inactive';
  end if;

  if v_shop.shop_type <> 'dropship' then
    raise exception 'shop is not dropship';
  end if;

  if not public.can_customer_access_shop(p_shop_id) then
    raise exception 'access denied';
  end if;

  select access.customer_group_id into v_customer_group_id
  from public.shop_customer_group_access access
  join public.customer_groups cg on cg.id = access.customer_group_id
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  where access.shop_id = p_shop_id
    and access.status = true
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
  order by access.created_at asc
  limit 1;

  if v_customer_group_id is null then
    raise exception 'no customer group access found';
  end if;

  select * into v_cart
  from public.shop_carts c
  where c.tenant_id = v_shop.tenant_id
    and c.shop_id = p_shop_id
    and c.customer_group_id = v_customer_group_id
    and c.status = 'active'
  order by c.id desc
  limit 1;

  if v_cart.id is null then
    raise exception 'active cart not found';
  end if;

  if not public.is_cart_owner(v_cart.customer_group_id, v_cart.tenant_id) then
    raise exception 'access denied';
  end if;

  select can_place_order into v_can_place_order
  from public.get_shop_permissions_for_customer(p_shop_id);

  if coalesce(v_can_place_order, false) is not true then
    raise exception 'checkout not allowed for this customer group';
  end if;

  select count(*) into v_item_count
  from public.shop_cart_items
  where cart_id = v_cart.id;

  if v_item_count = 0 then
    raise exception 'cart is empty';
  end if;

  if nullif(trim(coalesce(p_recipient_name, '')), '') is null then
    raise exception 'recipient name is required';
  end if;

  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  if v_phone is null then
    raise exception 'recipient phone is required';
  end if;

  if nullif(trim(coalesce(p_shipping_address, '')), '') is null then
    raise exception 'shipping address is required';
  end if;

  if nullif(trim(coalesce(p_shipping_district, '')), '') is null then
    raise exception 'shipping district is required';
  end if;

  if nullif(trim(coalesce(p_shipping_thana, '')), '') is null then
    raise exception 'shipping thana is required';
  end if;

  if exists (
    select 1
    from public.shop_cart_items ci
    where ci.cart_id = v_cart.id
      and coalesce(ci.unit_minimum_sell_price_amount, 0) > 0
      and coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
        < ci.unit_minimum_sell_price_amount
  ) then
    raise exception 'price floor violation: some items are priced below the minimum sell price';
  end if;

  v_billing_profile_id := p_billing_profile_id;
  if v_billing_profile_id is null then
    v_billing_profile_id := public.resolve_billing_profile_for_customer_group(v_cart.tenant_id, v_cart.customer_group_id);
  end if;

  if v_shop.order_mode = 'checkout_fixed' then
    v_order_status := 'confirmed';
  else
    v_order_status := 'submitted';
  end if;

  v_deduct_delivery_from_margin := not coalesce(p_recipient_pays_delivery, true);
  v_deduct_cod_from_margin := not coalesce(p_recipient_pays_cod, true);
  v_parent_tenant_id := public.resolve_parent_tenant_id(v_cart.tenant_id);

  select public.generate_shop_order_number(v_cart.tenant_id, v_cart.shop_id) into v_order_no;

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
    v_order_no, 'Order for ' || nullif(trim(coalesce(p_recipient_name, '')), ''),
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable,
    v_order_status, 0,
    nullif(trim(coalesce(p_recipient_name, '')), ''), v_phone, nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''),
    nullif(trim(coalesce(p_shipping_address, '')), ''), nullif(trim(coalesce(p_shipping_district, '')), ''), nullif(trim(coalesce(p_shipping_thana, '')), ''),
    v_recipient_profile_id, v_billing_profile_id,
    public.current_user_email(),
    coalesce(p_cod_charge_amount, 0), coalesce(p_delivery_charge_amount, 0),
    coalesce(p_print_charge_amount, 0), coalesce(p_packing_charge_amount, 0), coalesce(p_discount_amount, 0),
    coalesce(p_is_prepaid, false), nullif(trim(coalesce(p_delivery_instructions, '')), ''),
    v_shop.deduct_charges_from_margin,
    v_deduct_cod_from_margin, v_deduct_delivery_from_margin,
    v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
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
    final_price_amount, final_price_currency_id
  )
  select
    v_order_id, ci.product_id, ci.global_stock_id, ci.global_stock_allocation_id,
    ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    case
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount)
      else null
    end,
    case
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id)
      else null
    end
  from public.shop_cart_items ci
  where ci.cart_id = v_cart.id;

  for v_ci in select * from public.shop_cart_items where cart_id = v_cart.id loop
    if v_ci.product_id is not null and v_ci.global_stock_allocation_id is not null then
      update public.shop_product_listings
      set display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      where shop_id = v_shop.id
        and product_id = v_ci.product_id
        and global_stock_allocation_id = v_ci.global_stock_allocation_id
        and display_quantity_override is not null;
    end if;

    if v_ci.global_stock_id is not null then
      select * into v_stock
      from public.global_stocks
      where id = v_ci.global_stock_id
      for update;

      if not found then
        raise exception 'stock not found for cart item %', v_ci.name;
      end if;

      if v_stock.availability <> 'sellable'::public.stock_availability then
        raise exception 'insufficient sellable stock for %', v_ci.name;
      end if;

      if v_stock.quantity < v_ci.quantity then
        raise exception 'insufficient stock quantity for % (requested %, available %)',
          v_ci.name, v_ci.quantity, v_stock.quantity;
      end if;

      perform public.create_and_post_stock_movement(
        p_tenant_id => v_parent_tenant_id,
        p_stock_id => v_ci.global_stock_id,
        p_quantity => v_ci.quantity,
        p_to_location_id => v_stock.location_id,
        p_to_availability => 'held'::public.stock_availability,
        p_to_grade_tag_id => v_stock.grade_tag_id,
        p_movement_type => 'availability_transfer'::public.stock_movement_type,
        p_notes => 'Dropship order hold',
        p_reference_type => 'shop_order',
        p_reference_id => v_order_id::text
      );

      select gs.id into v_held_stock_id
      from public.global_stocks gs
      where gs.shipment_item_id = v_stock.shipment_item_id
        and gs.parent_tenant_id = v_parent_tenant_id
        and gs.availability = 'held'::public.stock_availability
        and gs.location_id = v_stock.location_id
        and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id())
          = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id())
      order by gs.id desc
      limit 1;

      if v_held_stock_id is not null then
        update public.shop_order_items
        set global_stock_id = v_held_stock_id
        where order_id = v_order_id
          and product_id is not distinct from v_ci.product_id
          and global_stock_id = v_ci.global_stock_id;
      end if;
    end if;

    if v_ci.product_id is not null and v_ci.global_stock_allocation_id is not null then
      v_rem_sellable_qty := 0;
      if v_ci.global_stock_id is not null then
        select coalesce(sum(gs.quantity), 0) into v_rem_sellable_qty
        from public.global_stocks gs
        where gs.shipment_item_id = (
          select shipment_item_id from public.global_stocks where id = v_ci.global_stock_id
        )
          and gs.availability = 'sellable'::public.stock_availability;
      end if;

      select display_quantity_override into v_rem_override_qty
      from public.shop_product_listings
      where shop_id = v_shop.id
        and product_id = v_ci.product_id
        and global_stock_allocation_id = v_ci.global_stock_allocation_id;

      if coalesce(v_rem_override_qty, v_rem_sellable_qty, 0) <= 0 then
        update public.shop_product_listings
        set is_active = false
        where shop_id = v_shop.id
          and product_id = v_ci.product_id
          and global_stock_allocation_id = v_ci.global_stock_allocation_id;
      end if;
    end if;
  end loop;

  delete from public.shop_stock_reservations
  where cart_item_id in (select id from public.shop_cart_items where cart_id = v_cart.id);

  update public.shop_carts
  set status = 'converted', updated_at = now()
  where id = v_cart.id;

  select jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_order_status,
    'cart_id', v_cart.id,
    'shop_id', v_shop.id
  ) into v_result;

  return v_result;
end;
$$;

create or replace function public.restock_dropship_order_on_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
  v_is_dropship boolean := false;
  v_new_override_qty integer;
  v_new_sellable_qty integer;
  v_skip_stock_release boolean := false;
  v_invoice_status public.global_invoice_status;
  v_parent_tenant_id bigint;
  v_stock public.global_stocks%rowtype;
begin
  if OLD.shop_type_snapshot = 'dropship' then
    v_is_dropship := true;
  else
    select (shop_type = 'dropship') into v_is_dropship
    from public.shops
    where id = OLD.shop_id;
  end if;

  if not coalesce(v_is_dropship, false) then
    return OLD;
  end if;

  if OLD.global_invoice_id is not null then
    select invoice_status into v_invoice_status
    from public.global_invoices
    where id = OLD.global_invoice_id;

    if v_invoice_status = 'issued'::public.global_invoice_status then
      v_skip_stock_release := true;
    end if;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(OLD.tenant_id);

  for v_item in select * from public.shop_order_items where order_id = OLD.id loop
    if v_item.product_id is not null and v_item.global_stock_allocation_id is not null then
      update public.shop_product_listings
      set display_quantity_override = display_quantity_override + v_item.quantity
      where shop_id = OLD.shop_id
        and product_id = v_item.product_id
        and global_stock_allocation_id = v_item.global_stock_allocation_id
        and display_quantity_override is not null;
    end if;

    if not v_skip_stock_release and v_item.global_stock_id is not null then
      select * into v_stock
      from public.global_stocks
      where id = v_item.global_stock_id
      for update;

      if found
         and v_stock.availability = 'held'::public.stock_availability
         and v_stock.quantity >= v_item.quantity then
        perform public.create_and_post_stock_movement(
          p_tenant_id => v_parent_tenant_id,
          p_stock_id => v_stock.id,
          p_quantity => v_item.quantity,
          p_to_location_id => v_stock.location_id,
          p_to_availability => 'sellable'::public.stock_availability,
          p_to_grade_tag_id => v_stock.grade_tag_id,
          p_movement_type => 'availability_transfer'::public.stock_movement_type,
          p_notes => 'Dropship order delete release',
          p_reference_type => 'shop_order',
          p_reference_id => OLD.id::text
        );
      end if;
    end if;

    if v_item.product_id is not null and v_item.global_stock_allocation_id is not null then
      v_new_sellable_qty := 0;
      if v_item.global_stock_id is not null then
        select coalesce(sum(gs.quantity), 0) into v_new_sellable_qty
        from public.global_stocks gs
        where gs.shipment_item_id = (
          select shipment_item_id from public.global_stocks where id = v_item.global_stock_id
        )
          and gs.availability = 'sellable'::public.stock_availability;
      end if;

      select display_quantity_override into v_new_override_qty
      from public.shop_product_listings
      where shop_id = OLD.shop_id
        and product_id = v_item.product_id
        and global_stock_allocation_id = v_item.global_stock_allocation_id;

      if coalesce(v_new_override_qty, v_new_sellable_qty, 0) > 0 then
        update public.shop_product_listings
        set is_active = true
        where shop_id = OLD.shop_id
          and product_id = v_item.product_id
          and global_stock_allocation_id = v_item.global_stock_allocation_id;
      end if;
    end if;
  end loop;

  return OLD;
end;
$$;

create or replace function public.post_sales_invoice(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_invoice public.global_invoices;
  v_item public.global_invoice_items%rowtype;
  v_unit_cost numeric;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_stock record;
  v_qty integer;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'only draft or proforma invoices can be posted/issued';
  end if;

  if not exists (select 1 from public.global_invoice_items where invoice_id = p_invoice_id) then
    raise exception 'cannot post an empty invoice';
  end if;

  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id);
  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);

  if v_invoice.invoice_type = 'wholesale'::public.global_invoice_type then
    if v_invoice.billing_profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
  elsif v_invoice.invoice_type = 'retail'::public.global_invoice_type then
    if v_invoice.retail_billing_mode = 'account'::public.retail_billing_mode then
      if v_invoice.billing_profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
    elsif v_invoice.retail_billing_mode = 'direct'::public.retail_billing_mode then
      if v_invoice.billing_profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for retail invoices';
    end if;
  elsif v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
    if v_invoice.billing_profile_id is null then
      raise exception 'billing profile is required for dropship invoices';
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for dropship invoices';
    end if;
  end if;

  for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
    v_unit_cost := public.calculate_landed_unit_cost(v_item.shipment_item_id);
    update public.global_invoice_items
    set unit_cost_price = v_unit_cost
    where id = v_item.id;
  end loop;

  v_mov_no := 'MOV-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.stock_movements_id_seq')::text, 6, '0');

  insert into public.stock_movements (
    tenant_id,
    movement_no,
    movement_type,
    reference_type,
    reference_id,
    notes,
    created_by_email,
    is_posted,
    posted_at
  ) values (
    v_parent_id,
    v_mov_no,
    'adjustment'::public.stock_movement_type,
    'sales_invoice',
    p_invoice_id::text,
    'Issued ' || upper(v_invoice.invoice_type::text) || ' Invoice #' || coalesce(v_invoice.invoice_no, p_invoice_id::text),
    public.current_user_email(),
    true,
    now()
  ) returning id into v_mov_id;

  for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
    v_qty := ceil(v_item.quantity)::integer;

    select * into v_stock from public.global_stocks where id = v_item.global_stock_id for update;
    if v_stock.id is not null then
      if v_invoice.invoice_type = 'dropship'::public.global_invoice_type
         and v_stock.availability <> 'held'::public.stock_availability then
        raise exception 'dropship invoice stock % must be held before issue', v_item.global_stock_id;
      end if;

      if v_stock.quantity < v_qty then
        raise exception 'insufficient stock quantity on stock % (requested %, available %)',
          v_item.global_stock_id, v_qty, v_stock.quantity;
      end if;

      update public.global_stocks
      set quantity = quantity - v_qty
      where id = v_item.global_stock_id;

      insert into public.stock_movement_lines (
        movement_id,
        stock_id,
        quantity,
        from_location_id,
        to_location_id,
        from_availability,
        to_availability
      ) values (
        v_mov_id,
        v_item.global_stock_id,
        v_qty,
        v_stock.location_id,
        v_stock.location_id,
        v_stock.availability,
        v_stock.availability
      );
    end if;
  end loop;

  update public.global_invoices
  set invoice_status = 'issued'::public.global_invoice_status
  where id = p_invoice_id;

  if v_invoice.invoice_type <> 'wholesale'::public.global_invoice_type
     and v_invoice.billing_profile_id is not null
     and coalesce(v_invoice.total_amount, 0) > 0
  then
    if not exists (
      select 1 from public.universal_wallet_ledger
      where source_type = 'sales_invoice'
        and source_id = p_invoice_id::text
        and entity_type = 'customer'
        and entity_id = v_invoice.billing_profile_id
        and metadata->>'transaction_type' = 'invoice_billed'
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.billing_profile_id,
        p_type => 'debit',
        p_amount => v_invoice.total_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice',
        p_source_id => p_invoice_id::text,
        p_metadata => jsonb_build_object(
          'section', 'invoices',
          'purpose', 'invoice_billed',
          'transaction_type', 'invoice_billed',
          'label', 'Invoice Billed',
          'invoice_no', v_invoice.invoice_no,
          'invoice_id', v_invoice.id,
          'invoice_type', v_invoice.invoice_type
        )
      );
    end if;
  end if;
end;
$$;

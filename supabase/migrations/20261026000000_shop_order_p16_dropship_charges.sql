-- SQL Migration: Shop Dropship Charges and Prepaid Logic
begin;

-- 1. Add charge and prepaid columns to shop_carts
alter table public.shop_carts
  add column if not exists cod_charge_amount numeric(12,2) not null default 0,
  add column if not exists delivery_charge_amount numeric(12,2) not null default 0,
  add column if not exists print_charge_amount numeric(12,2) not null default 0,
  add column if not exists packing_charge_amount numeric(12,2) not null default 0,
  add column if not exists discount_amount numeric(12,2) not null default 0,
  add column if not exists is_prepaid boolean not null default false,
  add column if not exists delivery_instructions text;

-- 2. Add charge and prepaid columns to shop_orders
alter table public.shop_orders
  add column if not exists cod_charge_amount numeric(12,2) not null default 0,
  add column if not exists delivery_charge_amount numeric(12,2) not null default 0,
  add column if not exists print_charge_amount numeric(12,2) not null default 0,
  add column if not exists packing_charge_amount numeric(12,2) not null default 0,
  add column if not exists discount_amount numeric(12,2) not null default 0,
  add column if not exists is_prepaid_snapshot boolean not null default false,
  add column if not exists delivery_instructions text;

-- 3. Add default charge settings to shops
alter table public.shops
  add column if not exists default_cod_charge_pct numeric(12,2) not null default 0,
  add column if not exists default_delivery_charge_amount numeric(12,2) not null default 0,
  add column if not exists default_print_charge_amount numeric(12,2) not null default 0,
  add column if not exists default_packing_charge_amount numeric(12,2) not null default 0;

-- 4. Create helper function to resolve billing profile for customer group
create or replace function public.resolve_billing_profile_for_customer_group(
  p_tenant_id bigint,
  p_customer_group_id bigint
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_billing_profile_id bigint;
begin
  select id into v_billing_profile_id
  from public.billing_profiles
  where tenant_id = p_tenant_id
    and customer_group_id = p_customer_group_id
  order by id
  limit 1;
  
  return v_billing_profile_id;
end;
$$;

grant execute on function public.resolve_billing_profile_for_customer_group(bigint, bigint) to authenticated;

-- 5. Update add_to_shop_cart to enforce unit_minimum_sell_price_amount floor
create or replace function public.add_to_shop_cart(
  p_shop_id bigint,
  p_product_id bigint,
  p_global_stock_allocation_id bigint default null,
  p_quantity integer default 1,
  p_customer_sell_price_amount numeric default null,
  p_customer_sell_price_currency_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart_res jsonb;
  v_cart_id bigint;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_prod_name text;
  v_prod_image text;
  v_prod_vendor text;
  v_prod_is_available boolean;
  v_prod_price_amount numeric;
  v_prod_price_currency_id bigint;
  
  v_listing_id bigint;
  v_global_stock_id bigint;
  v_sell_price_amount numeric;
  v_sell_price_currency_id bigint;
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
  v_display_qty_override integer;
  v_landed_cost numeric;
  
  v_allocated_qty integer;
  v_other_reserved_qty integer;
  v_available_to_sell integer;
  
  v_existing_item_id bigint;
  v_existing_item_qty integer;
  v_target_qty integer;
  
  v_can_add_to_cart boolean;
  v_can_set_dropship_price boolean;
  v_customer_sell_price_amount numeric;
  v_customer_sell_price_currency_id bigint;
begin
  -- 1. Resolve / verify cart
  v_cart_res := public.get_or_create_shop_cart(p_shop_id);
  v_cart_id := (v_cart_res->'cart'->>'id')::bigint;
  
  select 
    tenant_id, shop_type, pricing_method, markup_percentage 
  into 
    v_tenant_id, v_shop_type, v_pricing_method, v_markup_percentage 
  from public.shops 
  where id = p_shop_id;
  
  -- Check permission to add to cart
  select can_add_to_cart, can_set_dropship_price
  into v_can_add_to_cart, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(p_shop_id);
  
  if coalesce(v_can_add_to_cart, false) is not true then
    raise exception 'cart additions not allowed';
  end if;

  -- 2. Resolve product details
  select name, image_url, vendor_code, is_available, list_price_amount, list_price_currency_id
  into v_prod_name, v_prod_image, v_prod_vendor, v_prod_is_available, v_prod_price_amount, v_prod_price_currency_id
  from public.products
  where id = p_product_id;
  
  if v_prod_name is null or v_prod_is_available is not true then
    raise exception 'product not found or unavailable';
  end if;

  -- 3. If fixed_price or dropship, enforce allocation matching
  if v_shop_type in ('fixed_price', 'dropship') then
    if p_global_stock_allocation_id is null then
      raise exception 'global stock allocation required for this shop type';
    end if;

    select 
      l.id, l.global_stock_id, l.sell_price_amount, l.sell_price_currency_id,
      l.minimum_sell_price_amount, l.minimum_sell_price_currency_id, l.display_quantity_override,
      gsa.quantity
    into 
      v_listing_id, v_global_stock_id, v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id, v_display_qty_override,
      v_allocated_qty
    from public.shop_product_listings l
    join public.global_stock_allocations gsa on gsa.id = l.global_stock_allocation_id
    where l.shop_id = p_shop_id
      and l.global_stock_allocation_id = p_global_stock_allocation_id
      and l.product_id = p_product_id
      and l.is_active = true;

    if v_listing_id is null then
      raise exception 'active product listing not found on this shop';
    end if;

    -- Dynamic pricing override for fixed_price retail shop
    if v_shop_type = 'fixed_price' then
      select gsi.purchase_price * coalesce(gship.product_conversion_rate, 1.0)
      into v_landed_cost
      from public.global_stock_allocations gsa
      join public.global_stocks gs on gs.id = gsa.stock_id
      join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      join public.global_shipments gship on gship.id = gsi.shipment_id
      where gsa.id = p_global_stock_allocation_id;

      if v_pricing_method = 'markup' then
        v_sell_price_amount := v_landed_cost * (1 + v_markup_percentage / 100.0);
      elsif v_pricing_method = 'direct_cost' then
        v_sell_price_amount := v_landed_cost;
      end if;
    end if;

    -- Calculate current quantity in the cart for this allocation
    select id, quantity into v_existing_item_id, v_existing_item_qty
    from public.shop_cart_items
    where cart_id = v_cart_id
      and global_stock_allocation_id = p_global_stock_allocation_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;

    -- Calculate other reservations (excluding ours)
    select coalesce(sum(quantity), 0)
    into v_other_reserved_qty
    from public.shop_stock_reservations r
    where r.global_stock_allocation_id = p_global_stock_allocation_id
      and r.cart_item_id <> coalesce(v_existing_item_id, -1);

    v_available_to_sell := v_allocated_qty - v_other_reserved_qty;

    if v_target_qty > v_available_to_sell then
      raise exception 'insufficient stock: requested %, available %', v_target_qty, greatest(0, v_available_to_sell);
    end if;

    -- Handle dropship pricing
    if v_shop_type = 'dropship' then
      if coalesce(v_can_set_dropship_price, false) then
        -- Default to the regular sell price amount
        v_customer_sell_price_amount := coalesce(p_customer_sell_price_amount, v_sell_price_amount);
        v_customer_sell_price_currency_id := coalesce(p_customer_sell_price_currency_id, v_sell_price_currency_id);
        
        -- Enforce minimum sell price floor
        if v_customer_sell_price_currency_id = v_min_sell_price_currency_id 
           and v_customer_sell_price_amount < v_min_sell_price_amount then
          raise exception 'price cannot be lower than the minimum sell price %', v_min_sell_price_amount;
        end if;
      else
        v_customer_sell_price_amount := v_sell_price_amount;
        v_customer_sell_price_currency_id := v_sell_price_currency_id;
      end if;
    end if;

  else
    -- Vendor catalog
    select id, quantity into v_existing_item_id, v_existing_item_qty
    from public.shop_cart_items
    where cart_id = v_cart_id
      and product_id = p_product_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;
  end if;

  -- 4. Upsert cart item
  if v_existing_item_id is not null then
    update public.shop_cart_items
    set 
      quantity = v_target_qty,
      unit_sell_price_amount = v_sell_price_amount,
      customer_sell_price_amount = coalesce(v_customer_sell_price_amount, customer_sell_price_amount),
      customer_sell_price_currency_id = coalesce(v_customer_sell_price_currency_id, customer_sell_price_currency_id),
      updated_at = now()
    where id = v_existing_item_id;
  else
    insert into public.shop_cart_items (
      cart_id, product_id, global_stock_id, global_stock_allocation_id,
      quantity, minimum_quantity,
      unit_list_price_amount, unit_list_price_currency_id,
      unit_sell_price_amount, unit_sell_price_currency_id,
      unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
      customer_sell_price_amount, customer_sell_price_currency_id,
      name, image_url
    )
    values (
      v_cart_id, p_product_id, v_global_stock_id, p_global_stock_allocation_id,
      p_quantity, 1,
      v_prod_price_amount, v_prod_price_currency_id,
      v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      v_prod_name, v_prod_image
    );
  end if;

  return public.get_or_create_shop_cart(p_shop_id);
end;
$$;

-- 6. Update update_shop_cart_item_price to enforce unit_minimum_sell_price_amount floor
create or replace function public.update_shop_cart_item_price(
  p_cart_item_id bigint,
  p_price numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart_id bigint;
  v_shop_id bigint;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_global_stock_allocation_id bigint;
  v_sell_price_amount numeric;
  v_sell_price_currency_id bigint;
  v_customer_sell_price_currency_id bigint;
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
begin
  select ci.cart_id, ci.global_stock_allocation_id, c.shop_id, c.tenant_id, s.shop_type,
         ci.unit_sell_price_amount, ci.unit_sell_price_currency_id, ci.customer_sell_price_currency_id,
         ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id
  into v_cart_id, v_global_stock_allocation_id, v_shop_id, v_tenant_id, v_shop_type,
       v_sell_price_amount, v_sell_price_currency_id, v_customer_sell_price_currency_id,
       v_min_sell_price_amount, v_min_sell_price_currency_id
  from public.shop_cart_items ci
  join public.shop_carts c on c.id = ci.cart_id
  join public.shops s on s.id = c.shop_id
  where ci.id = p_cart_item_id;

  if v_cart_id is null then
    raise exception 'cart item not found';
  end if;

  if not public.is_cart_owner((select customer_group_id from public.shop_carts where id = v_cart_id), v_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_shop_type <> 'dropship' then
    raise exception 'price updates only allowed for dropship shops';
  end if;

  if p_price < 0 then
    raise exception 'price cannot be negative';
  end if;

  -- Enforce minimum sell price floor
  if v_customer_sell_price_currency_id = v_min_sell_price_currency_id 
     and p_price < v_min_sell_price_amount then
    raise exception 'price cannot be lower than the minimum sell price %', v_min_sell_price_amount;
  end if;

  update public.shop_cart_items
  set customer_sell_price_amount = p_price, updated_at = now()
  where id = p_cart_item_id;

  return public.get_or_create_shop_cart(v_shop_id);
end;
$$;

-- 7. Update submit_shop_order_from_cart to support charges, prepaid, instructions, and auto-resolved billing profile
drop function if exists public.submit_shop_order_from_cart(bigint, text, text, text, bigint) cascade;

create or replace function public.submit_shop_order_from_cart(
  p_cart_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
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
begin
  -- 1. Fetch and verify cart
  select * into v_cart from public.shop_carts where id = p_cart_id and status = 'active';
  if v_cart.id is null then
    raise exception 'active cart not found';
  end if;

  -- 2. Verify ownership
  if not public.is_cart_owner(v_cart.customer_group_id, v_cart.tenant_id) then
    raise exception 'access denied';
  end if;

  -- 3. Fetch shop context
  select * into v_shop from public.shops where id = v_cart.shop_id;
  if v_shop.id is null or not v_shop.is_active then
    raise exception 'shop not found or inactive';
  end if;

  -- 4. Verify permission
  select can_place_order, can_negotiate
  into v_can_place_order, v_can_negotiate
  from public.get_shop_permissions_for_customer(v_shop.id);

  if coalesce(v_can_place_order, false) is not true then
    raise exception 'checkout not allowed for this customer group';
  end if;

  -- Verify cart has items
  select count(*) into v_item_count from public.shop_cart_items where cart_id = p_cart_id;
  if v_item_count = 0 then
    raise exception 'cart is empty';
  end if;

  -- 5. For dropship shops, enforce price floor validation
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

  -- Resolve billing profile id
  v_billing_profile_id := p_billing_profile_id;
  if v_billing_profile_id is null then
    v_billing_profile_id := public.resolve_billing_profile_for_customer_group(v_cart.tenant_id, v_cart.customer_group_id);
  end if;

  -- 6. Determine order status based on shop_type × order_mode matrix
  if v_shop.shop_type = 'vendor_catalog' then
    if v_shop.order_mode <> 'procurement_intent' then
      raise exception 'invalid order mode for vendor catalog shop';
    end if;
    if v_shop.is_negotiable and coalesce(v_can_negotiate, false) then
      v_order_status := 'negotiating';
    else
      v_order_status := 'submitted';
    end if;
  else
    -- fixed_price or dropship
    if v_shop.order_mode = 'checkout_fixed' then
      v_order_status := 'confirmed';
    else
      v_order_status := 'submitted';
    end if;
  end if;

  -- 7. Generate order number
  v_order_no := 'ORD-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random() * 100000)::text, 5, '0');

  -- 8. Insert order
  insert into public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id,
    order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot,
    status, negotiate_round,
    recipient_name, recipient_phone, shipping_address, billing_profile_id,
    created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions
  )
  values (
    v_cart.tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id,
    v_order_no, 'Order for ' || p_recipient_name,
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable,
    v_order_status, case when v_order_status = 'negotiating' then 1 else 0 end,
    p_recipient_name, p_recipient_phone, p_shipping_address, v_billing_profile_id,
    public.current_user_email(),
    p_cod_charge_amount, p_delivery_charge_amount, p_print_charge_amount, p_packing_charge_amount, p_discount_amount,
    p_is_prepaid, p_delivery_instructions
  )
  returning id into v_order_id;

  -- 9. Copy items and set pricing snapshots
  insert into public.shop_order_items (
    order_id, product_id, global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    ordered_quantity
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
    ci.quantity
  from public.shop_cart_items ci
  where ci.cart_id = p_cart_id;

  -- 10. Delete reservations
  delete from public.shop_stock_reservations
  where cart_item_id in (select id from public.shop_cart_items where cart_id = p_cart_id);

  -- 11. Update cart status
  update public.shop_carts
  set status = 'converted', updated_at = now()
  where id = p_cart_id;

  select jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_order_status
  ) into v_result;

  return v_result;
end;
$$;

grant execute on function public.submit_shop_order_from_cart(bigint, text, text, text, bigint, boolean, text, numeric, numeric, numeric, numeric, numeric) to authenticated;

-- 8. Update fulfill_shop_order_to_invoice to pass charges, instructions, and handle prepaid logic
create or replace function public.fulfill_shop_order_to_invoice(p_order_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice public.global_invoices;
  v_invoice_type public.global_invoice_type;
  v_retail_billing_mode public.retail_billing_mode;
  v_invoice_no text;
  v_item record;
  v_invoice_row record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  
  if v_order.id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'confirmed' then
    raise exception 'only confirmed orders can be fulfilled to an invoice';
  end if;

  if v_order.shop_type_snapshot = 'vendor_catalog' then
    raise exception 'vendor catalog orders cannot be fulfilled to an invoice directly';
  end if;

  -- 1. Determine invoice type & retail billing mode
  if v_order.shop_type_snapshot = 'dropship' then
    v_invoice_type := 'dropship'::public.global_invoice_type;
    v_retail_billing_mode := null;
  else
    -- fixed_price
    if v_order.order_mode_snapshot = 'checkout_wholesale' then
      v_invoice_type := 'wholesale'::public.global_invoice_type;
      v_retail_billing_mode := null;
    else
      v_invoice_type := 'retail'::public.global_invoice_type;
      if v_order.billing_profile_id is not null then
        v_retail_billing_mode := 'account'::public.retail_billing_mode;
      else
        v_retail_billing_mode := 'direct'::public.retail_billing_mode;
      end if;
    end if;
  end if;

  -- Generate invoice number
  v_invoice_no := 'INV-SO-' || v_order.order_no;

  -- 2. Create the global invoice
  select * into v_invoice from public.create_global_invoice(
    p_tenant_id => v_order.tenant_id,
    p_invoice_no => v_invoice_no,
    p_invoice_type => v_invoice_type,
    p_billing_profile_id => v_order.billing_profile_id,
    p_recipient_profile_id => null,
    p_recipient_name => v_order.recipient_name,
    p_recipient_phone => v_order.recipient_phone,
    p_recipient_address => v_order.shipping_address,
    p_retail_billing_mode => v_retail_billing_mode,
    p_due_date => null,
    p_note => coalesce(v_order.delivery_instructions, 'Fulfillment of Shop Order: ' || v_order.order_no)
  );

  -- Update invoice charges and collection source
  update public.global_invoices
  set
    shipping_charge = coalesce(v_order.delivery_charge_amount, 0),
    cod_charge = coalesce(v_order.cod_charge_amount, 0),
    print_charge = coalesce(v_order.print_charge_amount, 0),
    wrapping_charge = coalesce(v_order.packing_charge_amount, 0),
    discount_amount = coalesce(v_order.discount_amount, 0),
    collection_source = case when v_order.is_prepaid_snapshot then 'billing_profile'::public.collection_source_type else 'recipient'::public.collection_source_type end
  where id = v_invoice.id;

  -- 3. Add lines to invoice
  for v_item in select * from public.shop_order_items where order_id = p_order_id loop
    if v_item.global_stock_id is null then
      raise exception 'item % is missing global_stock_id association', v_item.name;
    end if;

    perform public.add_global_invoice_item(
      p_invoice_id => v_invoice.id,
      p_global_stock_id => v_item.global_stock_id,
      p_quantity => v_item.quantity::numeric,
      p_sell_price_amount => coalesce(v_item.final_price_amount, v_item.unit_sell_price_amount, v_item.unit_list_price_amount),
      p_recipient_price_amount => coalesce(v_item.customer_sell_price_amount, v_item.final_price_amount, v_item.unit_sell_price_amount, v_item.unit_list_price_amount),
      p_line_discount_amount => 0.00
    );

    -- Update delivered quantities on order item
    update public.shop_order_items
    set delivered_quantity = quantity,
        updated_at = now()
    where id = v_item.id;
  end loop;

  -- Recompute totals with charges set
  perform public.recompute_global_invoice_totals(v_invoice.id);

  -- 4. Post the invoice to book ledger entries and deduct quantities
  perform public.post_global_invoice(v_invoice.id);

  -- 5. Complete the shop order
  update public.shop_orders
  set status = 'fulfilled',
      global_invoice_id = v_invoice.id,
      fulfilled_at = now(),
      updated_at = now()
  where id = p_order_id;
end;
$$;

grant execute on function public.fulfill_shop_order_to_invoice(bigint) to authenticated;

commit;

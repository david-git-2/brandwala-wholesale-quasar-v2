-- Migration: Dropship quantity deduction on order placement and restocking on order deletion
begin;

-- 1. Update submit_shop_order_from_cart to deduct display quantity and original stock quantity for dropship orders
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
    if v_shop.is_negotiable and coalesce(v_can_negotiate, false) then
      v_order_status := 'negotiating';
    else
      v_order_status := 'submitted';
    end if;
  else
    if v_shop.order_mode = 'checkout_fixed' then
      v_order_status := 'confirmed';
    else
      v_order_status := 'submitted';
    end if;
  end if;

  v_recipient_profile_id := null;
  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');

  if v_phone is not null then
    v_profile := public.upsert_recipient_profile_by_phone(
      v_cart.tenant_id,
      p_recipient_name,
      p_recipient_phone,
      p_recipient_phone_secondary,
      p_shipping_address,
      p_shipping_district,
      p_shipping_thana
    );
    v_recipient_profile_id := (v_profile->>'id')::bigint;
    v_phone := v_profile->>'phone';
  end if;

  v_order_no := 'ORD-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random() * 100000)::text, 5, '0');

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
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable,
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

  -- Deduct display quantity override and original stock quantity for dropship orders
  if v_shop.shop_type = 'dropship' then
    for v_ci in select * from public.shop_cart_items where cart_id = p_cart_id loop
      -- Deduct display_quantity_override from shop_product_listings if not null
      if v_ci.product_id is not null and v_ci.global_stock_allocation_id is not null then
        update public.shop_product_listings
        set display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
        where shop_id = v_shop.id
          and product_id = v_ci.product_id
          and global_stock_allocation_id = v_ci.global_stock_allocation_id
          and display_quantity_override is not null;
      end if;

      -- Deduct original stock quantity from global_stock_allocations
      if v_ci.global_stock_allocation_id is not null then
        update public.global_stock_allocations
        set quantity = greatest(0, quantity - v_ci.quantity)
        where id = v_ci.global_stock_allocation_id;
      end if;

      -- Deduct original stock quantity from global_stocks
      if v_ci.global_stock_id is not null then
        update public.global_stocks
        set quantity = greatest(0, quantity - v_ci.quantity)
        where id = v_ci.global_stock_id;
      end if;
    end loop;
  end if;

  delete from public.shop_stock_reservations
  where cart_item_id in (select id from public.shop_cart_items where cart_id = p_cart_id);

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

grant execute on function public.submit_shop_order_from_cart(bigint, text, text, text, text, text, text, bigint, boolean, text, numeric, numeric, numeric, numeric, numeric) to authenticated;

-- 2. Create trigger function to restock dropship items (display & original quantities) when an order is deleted
create or replace function public.restock_dropship_order_on_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
  v_is_dropship boolean := false;
begin
  if OLD.shop_type_snapshot = 'dropship' then
    v_is_dropship := true;
  else
    select (shop_type = 'dropship') into v_is_dropship
    from public.shops
    where id = OLD.shop_id;
  end if;

  if coalesce(v_is_dropship, false) then
    for v_item in select * from public.shop_order_items where order_id = OLD.id loop
      -- Restock display quantity override on shop listing (if set)
      if v_item.product_id is not null and v_item.global_stock_allocation_id is not null then
        update public.shop_product_listings
        set display_quantity_override = display_quantity_override + v_item.quantity
        where shop_id = OLD.shop_id
          and product_id = v_item.product_id
          and global_stock_allocation_id = v_item.global_stock_allocation_id
          and display_quantity_override is not null;
      end if;

      -- Restock original quantity in stock allocation
      if v_item.global_stock_allocation_id is not null then
        update public.global_stock_allocations
        set quantity = quantity + v_item.quantity
        where id = v_item.global_stock_allocation_id;
      end if;

      -- Restock original quantity in global stocks
      if v_item.global_stock_id is not null then
        update public.global_stocks
        set quantity = quantity + v_item.quantity
        where id = v_item.global_stock_id;
      end if;
    end loop;
  end if;

  return OLD;
end;
$$;

drop trigger if exists trg_restock_dropship_order_on_delete on public.shop_orders;
create trigger trg_restock_dropship_order_on_delete
before delete on public.shop_orders
for each row execute function public.restock_dropship_order_on_delete();

-- 3. Redefine fulfill_shop_order_to_invoice to avoid double-deduction of display quantity
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

  if v_order.shop_type_snapshot = 'dropship' then
    v_invoice_type := 'dropship'::public.global_invoice_type;
    v_retail_billing_mode := null;
  else
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

  v_invoice_no := 'INV-SO-' || v_order.order_no;

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

  update public.global_invoices
  set
    shipping_charge = coalesce(v_order.delivery_charge_amount, 0),
    cod_charge = coalesce(v_order.cod_charge_amount, 0),
    print_charge = coalesce(v_order.print_charge_amount, 0),
    wrapping_charge = coalesce(v_order.packing_charge_amount, 0),
    discount_amount = coalesce(v_order.discount_amount, 0),
    collection_source = case when v_order.is_prepaid_snapshot then 'billing_profile'::public.collection_source_type else 'recipient'::public.collection_source_type end
  where id = v_invoice.id;

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

    update public.shop_order_items
    set delivered_quantity = quantity,
        updated_at = now()
    where id = v_item.id;
  end loop;

  perform public.recompute_global_invoice_totals(v_invoice.id);
  perform public.post_global_invoice(v_invoice.id);

  update public.shop_orders
  set status = 'fulfilled',
      global_invoice_id = v_invoice.id,
      fulfilled_at = now(),
      updated_at = now()
  where id = p_order_id;
end;
$$;

commit;

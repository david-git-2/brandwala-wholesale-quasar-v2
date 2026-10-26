-- vendor_catalog placement: always submitted (CATALOG_NEGOTIATION.md §2.1), not negotiating.

begin;

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
    final_price_amount, final_price_currency_id
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
    end
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

  select jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_order_status
  ) into v_result;

  return v_result;
end;
$$;

grant execute on function public.submit_shop_order_from_cart(bigint, text, text, text, text, text, text, bigint, boolean, text, numeric, numeric, numeric, numeric, numeric) to authenticated;

commit;

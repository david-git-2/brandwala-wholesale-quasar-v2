CREATE OR REPLACE FUNCTION public.submit_dropship_order_from_cart(
  p_shop_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_recipient_phone_secondary text DEFAULT NULL,
  p_shipping_district text DEFAULT NULL,
  p_shipping_thana text DEFAULT NULL,
  p_shipping_post_code text DEFAULT NULL,
  p_billing_profile_id bigint DEFAULT NULL,
  p_is_prepaid boolean DEFAULT false,
  p_delivery_instructions text DEFAULT NULL,
  p_cod_charge_amount numeric DEFAULT 0,
  p_delivery_charge_amount numeric DEFAULT 0,
  p_print_charge_amount numeric DEFAULT 0,
  p_packing_charge_amount numeric DEFAULT 0,
  p_discount_amount numeric DEFAULT 0,
  p_recipient_pays_delivery boolean DEFAULT true,
  p_recipient_pays_cod boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
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
  v_rem_alloc_qty integer;
  v_rem_override_qty integer;
  v_deduct_delivery_from_margin boolean;
  v_deduct_cod_from_margin boolean;
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

grant execute on function public.submit_dropship_order_from_cart(
  bigint, text, text, text, text, text, text, text, bigint, boolean, text,
  numeric, numeric, numeric, numeric, numeric, boolean, boolean
) to authenticated;

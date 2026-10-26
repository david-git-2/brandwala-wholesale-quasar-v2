-- SQL Migration to set dropshipping floor and default to unit_sell_price_amount
begin;

-- 1. Recreate add_to_shop_cart with floor set to sell_price_amount
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
        
        -- Enforce default sell price as the absolute minimum floor
        if v_customer_sell_price_currency_id = v_sell_price_currency_id 
           and v_customer_sell_price_amount < v_sell_price_amount then
          raise exception 'price cannot be lower than the default sell price %', v_sell_price_amount;
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

-- 2. Recreate update_shop_cart_item_price with floor set to unit_sell_price_amount
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
begin
  select ci.cart_id, ci.global_stock_allocation_id, c.shop_id, c.tenant_id, s.shop_type,
         ci.unit_sell_price_amount, ci.unit_sell_price_currency_id, ci.customer_sell_price_currency_id
  into v_cart_id, v_global_stock_allocation_id, v_shop_id, v_tenant_id, v_shop_type,
       v_sell_price_amount, v_sell_price_currency_id, v_customer_sell_price_currency_id
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

  -- Enforce default sell price amount as absolute minimum floor
  if v_customer_sell_price_currency_id = v_sell_price_currency_id 
     and p_price < v_sell_price_amount then
    raise exception 'price cannot be lower than default sell price %', v_sell_price_amount;
  end if;

  update public.shop_cart_items
  set customer_sell_price_amount = p_price, updated_at = now()
  where id = p_cart_item_id;

  return public.get_or_create_shop_cart(v_shop_id);
end;
$$;

commit;

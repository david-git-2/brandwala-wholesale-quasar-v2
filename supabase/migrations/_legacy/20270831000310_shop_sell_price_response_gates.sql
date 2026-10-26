-- Gate cart line prices on buy/sell permission snapshots.

CREATE OR REPLACE FUNCTION public.get_or_create_shop_cart(p_shop_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_tenant_id bigint;
  v_customer_group_id bigint;
  v_can_see_buy_price_snapshot boolean;
  v_can_see_sell_price_snapshot boolean;
  v_cart_id bigint;
  v_result jsonb;
begin
  select tenant_id into v_tenant_id
  from public.shops
  where id = p_shop_id
    and is_active = true;

  if v_tenant_id is null then
    raise exception 'shop not found or inactive';
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

  if not public.can_customer_access_shop(p_shop_id) then
    raise exception 'access denied';
  end if;

  select can_see_buy_price, can_see_sell_price
  into v_can_see_buy_price_snapshot, v_can_see_sell_price_snapshot
  from public.get_shop_permissions_for_customer(p_shop_id);

  select id into v_cart_id
  from public.shop_carts
  where tenant_id = v_tenant_id
    and shop_id = p_shop_id
    and customer_group_id = v_customer_group_id
    and status = 'active'
  order by id desc
  limit 1;

  if v_cart_id is null then
    insert into public.shop_carts (
      tenant_id,
      shop_id,
      customer_group_id,
      can_see_buy_price_snapshot,
      can_see_sell_price_snapshot,
      status,
      deduct_charges_from_margin,
      deduct_print_from_margin,
      deduct_packing_from_margin
    )
    values (
      v_tenant_id,
      p_shop_id,
      v_customer_group_id,
      v_can_see_buy_price_snapshot,
      v_can_see_sell_price_snapshot,
      'active',
      (select deduct_charges_from_margin from public.shops where id = p_shop_id),
      (select deduct_print_from_margin from public.shops where id = p_shop_id),
      (select deduct_packing_from_margin from public.shops where id = p_shop_id)
    )
    returning id into v_cart_id;
  else
    update public.shop_carts
    set
      deduct_charges_from_margin = (select deduct_charges_from_margin from public.shops where id = p_shop_id),
      deduct_print_from_margin = (select deduct_print_from_margin from public.shops where id = p_shop_id),
      deduct_packing_from_margin = (select deduct_packing_from_margin from public.shops where id = p_shop_id)
    where id = v_cart_id;
  end if;

  select jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'customer_group_id', c.customer_group_id,
      'can_see_buy_price_snapshot', c.can_see_buy_price_snapshot,
      'can_see_sell_price_snapshot', c.can_see_sell_price_snapshot,
      'status', c.status,
      'created_at', c.created_at,
      'updated_at', c.updated_at,
      'shop_type', s.shop_type,
      'allow_delivery', s.allow_delivery,
      'default_print_charge_amount', s.default_print_charge_amount,
      'default_packing_charge_amount', s.default_packing_charge_amount,
      'deduct_charges_from_margin', s.deduct_charges_from_margin,
      'deduct_print_from_margin', s.deduct_print_from_margin,
      'deduct_packing_from_margin', s.deduct_packing_from_margin
    ),
    'items', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ci.id,
            'cart_id', ci.cart_id,
            'product_id', ci.product_id,
            'global_stock_id', ci.global_stock_id,
            'global_stock_allocation_id', ci.global_stock_allocation_id,
            'quantity', ci.quantity,
            'minimum_quantity', ci.minimum_quantity,
            'minimum_order_quantity', p.minimum_order_quantity,
            'unit_list_price_amount', case when c.can_see_buy_price_snapshot then ci.unit_list_price_amount else null end,
            'unit_list_price_currency_id', case when c.can_see_buy_price_snapshot then ci.unit_list_price_currency_id else null end,
            'unit_sell_price_amount', case when c.can_see_sell_price_snapshot then ci.unit_sell_price_amount else null end,
            'unit_sell_price_currency_id', case when c.can_see_sell_price_snapshot then ci.unit_sell_price_currency_id else null end,
            'unit_minimum_sell_price_amount', case when c.can_see_sell_price_snapshot then ci.unit_minimum_sell_price_amount else null end,
            'unit_minimum_sell_price_currency_id', case when c.can_see_sell_price_snapshot then ci.unit_minimum_sell_price_currency_id else null end,
            'customer_sell_price_amount', case when c.can_see_sell_price_snapshot then ci.customer_sell_price_amount else null end,
            'customer_sell_price_currency_id', case when c.can_see_sell_price_snapshot then ci.customer_sell_price_currency_id else null end,
            'name', ci.name,
            'image_url', ci.image_url
          )
        )
        from public.shop_cart_items ci
        left join public.products p on p.id = ci.product_id
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  where c.id = v_cart_id;

  return v_result;
end;
$$;

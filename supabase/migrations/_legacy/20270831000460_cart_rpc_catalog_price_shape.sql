-- Cart RPC: catalog-shaped item prices (unit_price / sell_price / resell_minimum_price)
-- gated by live permissions. No root currency — each price object carries currency fields.

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
  v_perm record;
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

  select *
  into v_perm
  from public.get_shop_permissions_for_customer(p_shop_id)
  limit 1;

  v_can_see_buy_price_snapshot := coalesce(v_perm.can_see_buy_price, false);
  v_can_see_sell_price_snapshot := coalesce(v_perm.can_see_sell_price, false);

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
            'name', ci.name,
            'image_url', ci.image_url,
            'unit_price', case
              when s.shop_type in ('vendor_catalog', 'dropship')
                and coalesce(v_perm.can_see_buy_price, false)
                and ci.unit_list_price_amount is not null then
                jsonb_build_object(
                  'amount', ci.unit_list_price_amount,
                  'currency_id', ci.unit_list_price_currency_id,
                  'code', buy_gc.code,
                  'symbol', buy_gc.symbol
                )
              else null
            end,
            'sell_price', case
              when s.shop_type = 'fixed_price'
                and coalesce(v_perm.can_see_sell_price, false)
                and ci.unit_sell_price_amount is not null then
                jsonb_build_object(
                  'amount', ci.unit_sell_price_amount,
                  'currency_id', ci.unit_sell_price_currency_id,
                  'code', sell_gc.code,
                  'symbol', sell_gc.symbol
                )
              when s.shop_type = 'dropship'
                and coalesce(v_perm.can_see_sell_price, false)
                and coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount) is not null then
                jsonb_build_object(
                  'amount', coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount),
                  'currency_id', coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id),
                  'code', sell_gc.code,
                  'symbol', sell_gc.symbol
                )
              else null
            end,
            'resell_minimum_price', case
              when s.shop_type = 'dropship'
                and coalesce(v_perm.can_see_resell_minimum_price, false)
                and ci.unit_minimum_sell_price_amount is not null then
                jsonb_build_object(
                  'amount', ci.unit_minimum_sell_price_amount,
                  'currency_id', ci.unit_minimum_sell_price_currency_id,
                  'code', min_gc.code,
                  'symbol', min_gc.symbol
                )
              else null
            end
          )
          order by ci.id asc
        )
        from public.shop_cart_items ci
        left join public.products p on p.id = ci.product_id
        left join public.global_currencies buy_gc on buy_gc.id = ci.unit_list_price_currency_id
        left join public.global_currencies sell_gc
          on sell_gc.id = coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id)
        left join public.global_currencies min_gc on min_gc.id = ci.unit_minimum_sell_price_currency_id
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    ),
    'permissions', jsonb_build_object(
      'can_browse', coalesce(v_perm.can_browse, false),
      'can_see_buy_price', coalesce(v_perm.can_see_buy_price, false),
      'can_see_sell_price', coalesce(v_perm.can_see_sell_price, false),
      'can_see_resell_minimum_price', coalesce(v_perm.can_see_resell_minimum_price, false),
      'can_add_to_cart', coalesce(v_perm.can_add_to_cart, false),
      'can_place_order', coalesce(v_perm.can_place_order, false),
      'can_negotiate', coalesce(v_perm.can_negotiate, false),
      'can_view_quantity', coalesce(v_perm.can_view_quantity, false),
      'can_set_dropship_price', coalesce(v_perm.can_set_dropship_price, false)
    )
  )
  into v_result
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  where c.id = v_cart_id;

  return v_result;
end;
$$;

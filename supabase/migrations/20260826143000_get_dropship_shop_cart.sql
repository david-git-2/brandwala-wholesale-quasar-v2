-- Dropship cart read RPC with explicit purchase / resell price contract.

create or replace function public.get_dropship_shop_cart(p_shop_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop_type public.shop_type_enum;
  v_cart_id bigint;
  v_result jsonb;
begin
  select shop_type into v_shop_type
  from public.shops
  where id = p_shop_id
    and is_active = true;

  if v_shop_type is null then
    raise exception 'shop not found or inactive';
  end if;

  if v_shop_type <> 'dropship' then
    raise exception 'shop is not dropship';
  end if;

  v_cart_id := (public.get_or_create_shop_cart(p_shop_id)->'cart'->>'id')::bigint;

  select jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'shop_name', s.name,
      'shop_slug', s.slug,
      'customer_group_id', c.customer_group_id,
      'status', c.status,
      'allow_delivery', s.allow_delivery,
      'currency', jsonb_build_object(
        'id', s.sell_currency_id,
        'code', gc.code,
        'symbol', gc.symbol
      ),
      'charges', jsonb_build_object(
        'cod_charge_amount', c.cod_charge_amount,
        'delivery_charge_amount', c.delivery_charge_amount,
        'print_charge_amount', coalesce(nullif(c.print_charge_amount, 0), s.default_print_charge_amount),
        'packing_charge_amount', coalesce(nullif(c.packing_charge_amount, 0), s.default_packing_charge_amount),
        'discount_amount', c.discount_amount,
        'is_prepaid', c.is_prepaid,
        'delivery_instructions', c.delivery_instructions
      ),
      'margin_deductions', jsonb_build_object(
        'deduct_charges_from_margin', c.deduct_charges_from_margin,
        'deduct_print_from_margin', c.deduct_print_from_margin,
        'deduct_packing_from_margin', c.deduct_packing_from_margin
      ),
      'created_at', c.created_at,
      'updated_at', c.updated_at
    ),
    'permissions', (
      select jsonb_build_object(
        'can_browse', p.can_browse,
        'can_see_buy_price', p.can_see_buy_price,
        'can_see_sell_price', p.can_see_sell_price,
        'can_see_resell_minimum_price', p.can_see_resell_minimum_price,
        'can_add_to_cart', p.can_add_to_cart,
        'can_place_order', p.can_place_order,
        'can_negotiate', p.can_negotiate,
        'can_view_quantity', p.can_view_quantity,
        'can_set_dropship_price', p.can_set_dropship_price
      )
      from public.get_shop_permissions_for_customer(p_shop_id) p
      limit 1
    ),
    'items', coalesce(items.items, '[]'::jsonb),
    'totals', coalesce(items.totals, jsonb_build_object(
      'item_count', 0,
      'line_count', 0,
      'purchase_subtotal', 0,
      'resell_subtotal', 0,
      'estimated_profit', 0
    ))
  )
  into v_result
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  left join lateral (
    select
      jsonb_agg(
        jsonb_build_object(
          'id', ci.id,
          'product_id', ci.product_id,
          'global_stock_id', ci.global_stock_id,
          'name', ci.name,
          'image_url', ci.image_url,
          'quantity', ci.quantity,
          'minimum_quantity', ci.minimum_quantity,
          'minimum_order_quantity', p.minimum_order_quantity,
          'purchase_price', jsonb_build_object(
            'amount', ci.unit_list_price_amount,
            'currency_id', ci.unit_list_price_currency_id,
            'code', buy_gc.code,
            'symbol', buy_gc.symbol
          ),
          'listing_sell_price', jsonb_build_object(
            'amount', ci.unit_sell_price_amount,
            'currency_id', ci.unit_sell_price_currency_id,
            'code', sell_gc.code,
            'symbol', sell_gc.symbol
          ),
          'resell_price', jsonb_build_object(
            'amount', coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount),
            'currency_id', coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id),
            'code', coalesce(cust_gc.code, sell_gc.code),
            'symbol', coalesce(cust_gc.symbol, sell_gc.symbol)
          ),
          'min_resell_price', jsonb_build_object(
            'amount', ci.unit_minimum_sell_price_amount,
            'currency_id', ci.unit_minimum_sell_price_currency_id,
            'code', min_gc.code,
            'symbol', min_gc.symbol
          ),
          'line_totals', jsonb_build_object(
            'purchase_subtotal', ci.quantity * coalesce(ci.unit_list_price_amount, 0),
            'resell_subtotal', ci.quantity * coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
          ),
          'is_resell_below_floor', (
            coalesce(ci.unit_minimum_sell_price_amount, 0) > 0
            and coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
              < ci.unit_minimum_sell_price_amount
          )
        )
        order by ci.id
      ) as items,
      jsonb_build_object(
        'item_count', coalesce(sum(ci.quantity), 0),
        'line_count', count(ci.id),
        'purchase_subtotal', coalesce(sum(ci.quantity * coalesce(ci.unit_list_price_amount, 0)), 0),
        'resell_subtotal', coalesce(sum(
          ci.quantity * coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
        ), 0),
        'estimated_profit', coalesce(sum(
          ci.quantity * (
            coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
            - coalesce(ci.unit_list_price_amount, 0)
          )
        ), 0)
      ) as totals
    from public.shop_cart_items ci
    left join public.products p on p.id = ci.product_id
    left join public.global_currencies buy_gc on buy_gc.id = ci.unit_list_price_currency_id
    left join public.global_currencies sell_gc on sell_gc.id = ci.unit_sell_price_currency_id
    left join public.global_currencies cust_gc on cust_gc.id = ci.customer_sell_price_currency_id
    left join public.global_currencies min_gc on min_gc.id = ci.unit_minimum_sell_price_currency_id
    where ci.cart_id = c.id
  ) items on true
  where c.id = v_cart_id;

  return v_result;
end;
$$;

grant execute on function public.get_dropship_shop_cart(bigint) to authenticated;

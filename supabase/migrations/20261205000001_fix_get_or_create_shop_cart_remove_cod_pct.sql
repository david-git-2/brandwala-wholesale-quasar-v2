-- Migration: Remove default_cod_charge_pct and default_delivery_charge_amount from get_or_create_shop_cart RPC
-- In migration 20261114000000_remove_shop_cod_delivery_sender_defaults.sql, default_cod_charge_pct and default_delivery_charge_amount were dropped from public.shops.
-- However, 20261029000000_return_shop_defaults_in_cart_rpc.sql still referenced s.default_cod_charge_pct in get_or_create_shop_cart.

begin;

create or replace function public.get_or_create_shop_cart(p_shop_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id         bigint;
  v_customer_group_id bigint;
  v_see_price_snapshot boolean;
  v_cart_id           bigint;
  v_result            jsonb;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id and is_active = true;
  if v_tenant_id is null then
    raise exception 'shop not found or inactive';
  end if;

  select access.customer_group_id, access.see_price into v_customer_group_id, v_see_price_snapshot
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
      tenant_id, shop_id, customer_group_id, see_price_snapshot, status, deduct_charges_from_margin,
      deduct_print_from_margin, deduct_packing_from_margin
    )
    values (
      v_tenant_id, p_shop_id, v_customer_group_id, v_see_price_snapshot, 'active',
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

  -- Return serialized cart with items list and shop details (excluding dropped default_cod_charge_pct & default_delivery_charge_amount)
  select jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'customer_group_id', c.customer_group_id,
      'see_price_snapshot', c.see_price_snapshot,
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
            'unit_list_price_amount', ci.unit_list_price_amount,
            'unit_list_price_currency_id', ci.unit_list_price_currency_id,
            'unit_sell_price_amount', ci.unit_sell_price_amount,
            'unit_sell_price_currency_id', ci.unit_sell_price_currency_id,
            'unit_minimum_sell_price_amount', ci.unit_minimum_sell_price_amount,
            'unit_minimum_sell_price_currency_id', ci.unit_minimum_sell_price_currency_id,
            'customer_sell_price_amount', ci.customer_sell_price_amount,
            'customer_sell_price_currency_id', ci.customer_sell_price_currency_id,
            'name', ci.name,
            'image_url', ci.image_url
          )
        )
        from public.shop_cart_items ci
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

grant execute on function public.get_or_create_shop_cart(bigint) to authenticated;

commit;

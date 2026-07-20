-- SQL Migration to support updating dropship item selling price from shop cart
begin;

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
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
  v_customer_sell_price_currency_id bigint;
begin
  select ci.cart_id, ci.global_stock_allocation_id, c.shop_id, c.tenant_id, s.shop_type,
         ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id, ci.customer_sell_price_currency_id
  into v_cart_id, v_global_stock_allocation_id, v_shop_id, v_tenant_id, v_shop_type,
       v_min_sell_price_amount, v_min_sell_price_currency_id, v_customer_sell_price_currency_id
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

  if v_customer_sell_price_currency_id = v_min_sell_price_currency_id 
     and p_price < v_min_sell_price_amount then
    raise exception 'price cannot be lower than minimum sell price %', v_min_sell_price_amount;
  end if;

  update public.shop_cart_items
  set customer_sell_price_amount = p_price, updated_at = now()
  where id = p_cart_item_id;

  return public.get_or_create_shop_cart(v_shop_id);
end;
$$;

grant execute on function public.update_shop_cart_item_price(bigint, numeric) to authenticated;

commit;

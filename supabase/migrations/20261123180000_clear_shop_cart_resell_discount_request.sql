create or replace function public.clear_shop_cart_item_resell_discount_request(
  p_cart_item_id bigint
) returns jsonb
language plpgsql
security definer
set search_path to public
as $$
declare
  v_cart_id bigint;
  v_shop_id bigint;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
begin
  select ci.cart_id, c.shop_id, c.tenant_id, s.shop_type
  into v_cart_id, v_shop_id, v_tenant_id, v_shop_type
  from public.shop_cart_items ci
  join public.shop_carts c on c.id = ci.cart_id
  join public.shops s on s.id = c.shop_id
  where ci.id = p_cart_item_id;

  if v_cart_id is null then
    raise exception 'cart item not found';
  end if;

  if not public.is_cart_owner(
    (select customer_group_id from public.shop_carts where id = v_cart_id),
    v_tenant_id
  ) then
    raise exception 'access denied';
  end if;

  if v_shop_type <> 'dropship' then
    raise exception 'resell discount requests only allowed for dropship shops';
  end if;

  update public.shop_cart_items
  set
    requested_resell_discount_price_amount = null,
    requested_resell_discount_price_currency_id = null,
    resell_discount_request_reason = null,
    resell_discount_requested_at = null,
    updated_at = now()
  where id = p_cart_item_id;

  return public.get_dropship_review_cart(v_shop_id);
end;
$$;

alter function public.clear_shop_cart_item_resell_discount_request(bigint) owner to postgres;
grant execute on function public.clear_shop_cart_item_resell_discount_request(bigint) to authenticated;
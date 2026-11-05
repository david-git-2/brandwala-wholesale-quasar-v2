CREATE FUNCTION public.remove_shop_cart_item (
  p_cart_item_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_cart_id bigint;
  v_shop_id bigint;
  v_tenant_id bigint;
begin
  select ci.cart_id, c.shop_id, c.tenant_id
  into v_cart_id, v_shop_id, v_tenant_id
  from public.shop_cart_items ci
  join public.shop_carts c on c.id = ci.cart_id
  where ci.id = p_cart_item_id;

  if v_cart_id is null then
    raise exception 'cart item not found';
  end if;

  -- Access verification
  if not public.is_cart_owner((select customer_group_id from public.shop_carts where id = v_cart_id), v_tenant_id) then
    raise exception 'access denied';
  end if;

  delete from public.shop_cart_items where id = p_cart_item_id;

  return public.get_or_create_shop_cart(v_shop_id);
end;
$function$;

GRANT ALL ON FUNCTION public.remove_shop_cart_item(bigint) TO anon;

GRANT ALL ON FUNCTION public.remove_shop_cart_item(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.remove_shop_cart_item(bigint) TO service_role;
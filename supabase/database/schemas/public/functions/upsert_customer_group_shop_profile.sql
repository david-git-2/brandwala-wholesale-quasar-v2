CREATE FUNCTION public.upsert_customer_group_shop_profile (
  p_tenant_id                      bigint,
  p_customer_group_id              bigint,
  p_is_active                      boolean,
  p_default_can_browse             boolean,
  p_default_can_see_buy_price      boolean,
  p_default_can_see_sell_price     boolean,
  p_default_can_add_to_cart        boolean,
  p_default_can_place_order        boolean,
  p_default_can_negotiate          boolean,
  p_default_can_view_quantity      boolean,
  p_default_can_set_dropship_price boolean
)
  RETURNS SETOF public.customer_group_shop_profiles
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  insert into public.customer_group_shop_profiles (
    tenant_id,
    customer_group_id,
    is_active,
    default_can_browse,
    default_can_see_buy_price,
    default_can_see_sell_price,
    default_can_add_to_cart,
    default_can_place_order,
    default_can_negotiate,
    default_can_view_quantity,
    default_can_set_dropship_price
  )
  values (
    p_tenant_id,
    p_customer_group_id,
    p_is_active,
    p_default_can_browse,
    p_default_can_see_buy_price,
    p_default_can_see_sell_price,
    p_default_can_add_to_cart,
    p_default_can_place_order,
    p_default_can_negotiate,
    p_default_can_view_quantity,
    p_default_can_set_dropship_price
  )
  on conflict (tenant_id, customer_group_id) do update set
    is_active = excluded.is_active,
    default_can_browse = excluded.default_can_browse,
    default_can_see_buy_price = excluded.default_can_see_buy_price,
    default_can_see_sell_price = excluded.default_can_see_sell_price,
    default_can_add_to_cart = excluded.default_can_add_to_cart,
    default_can_place_order = excluded.default_can_place_order,
    default_can_negotiate = excluded.default_can_negotiate,
    default_can_view_quantity = excluded.default_can_view_quantity,
    default_can_set_dropship_price = excluded.default_can_set_dropship_price,
    updated_at = now()
  returning *;
end;
$function$;

GRANT ALL ON FUNCTION public.upsert_customer_group_shop_profile(bigint, bigint, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean) TO anon;

GRANT ALL ON FUNCTION public.upsert_customer_group_shop_profile(bigint, bigint, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_customer_group_shop_profile(bigint, bigint, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean) TO service_role;
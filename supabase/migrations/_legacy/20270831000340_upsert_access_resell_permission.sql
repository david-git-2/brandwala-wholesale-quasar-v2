-- Extend shop access upsert RPC with can_see_resell_minimum_price.

DROP FUNCTION IF EXISTS public.upsert_shop_customer_group_access(
  bigint,
  bigint,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  text,
  numeric,
  bigint
);

CREATE OR REPLACE FUNCTION public.upsert_shop_customer_group_access(
  p_shop_id bigint,
  p_customer_group_id bigint,
  p_status boolean,
  p_can_browse boolean DEFAULT NULL,
  p_can_see_buy_price boolean DEFAULT NULL,
  p_can_see_sell_price boolean DEFAULT NULL,
  p_can_add_to_cart boolean DEFAULT NULL,
  p_can_place_order boolean DEFAULT NULL,
  p_can_negotiate boolean DEFAULT NULL,
  p_can_view_quantity boolean DEFAULT NULL,
  p_can_set_dropship_price boolean DEFAULT NULL,
  p_price_tier_code text DEFAULT NULL,
  p_credit_limit_amount numeric DEFAULT NULL,
  p_credit_limit_currency_id bigint DEFAULT NULL,
  p_can_see_resell_minimum_price boolean DEFAULT NULL
)
RETURNS SETOF public.shop_customer_group_access
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.shops
  where id = p_shop_id;

  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  if (p_credit_limit_amount is null) <> (p_credit_limit_currency_id is null) then
    raise exception 'both credit_limit_amount and credit_limit_currency_id must be provided together or be null';
  end if;

  return query
  insert into public.shop_customer_group_access (
    shop_id,
    customer_group_id,
    status,
    can_browse,
    can_see_buy_price,
    can_see_sell_price,
    can_see_resell_minimum_price,
    can_add_to_cart,
    can_place_order,
    can_negotiate,
    can_view_quantity,
    can_set_dropship_price,
    price_tier_code,
    credit_limit_amount,
    credit_limit_currency_id
  )
  values (
    p_shop_id,
    p_customer_group_id,
    p_status,
    p_can_browse,
    p_can_see_buy_price,
    p_can_see_sell_price,
    p_can_see_resell_minimum_price,
    p_can_add_to_cart,
    p_can_place_order,
    p_can_negotiate,
    p_can_view_quantity,
    p_can_set_dropship_price,
    p_price_tier_code,
    p_credit_limit_amount,
    p_credit_limit_currency_id
  )
  on conflict (shop_id, customer_group_id) do update set
    status = excluded.status,
    can_browse = excluded.can_browse,
    can_see_buy_price = excluded.can_see_buy_price,
    can_see_sell_price = excluded.can_see_sell_price,
    can_see_resell_minimum_price = excluded.can_see_resell_minimum_price,
    can_add_to_cart = excluded.can_add_to_cart,
    can_place_order = excluded.can_place_order,
    can_negotiate = excluded.can_negotiate,
    can_view_quantity = excluded.can_view_quantity,
    can_set_dropship_price = excluded.can_set_dropship_price,
    price_tier_code = excluded.price_tier_code,
    credit_limit_amount = excluded.credit_limit_amount,
    credit_limit_currency_id = excluded.credit_limit_currency_id,
    updated_at = now()
  returning *;
end;
$$;

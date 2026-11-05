CREATE FUNCTION public.list_customer_active_carts (
  p_tenant_id bigint
)
  RETURNS TABLE (
    cart_id            bigint,
    shop_id            bigint,
    shop_name          text,
    shop_slug          text,
    shop_logo_url      text,
    shop_type          text,
    can_see_buy_price  boolean,
    can_see_sell_price boolean,
    currency_id        bigint,
    currency_code      text,
    currency_symbol    text,
    item_count         bigint,
    cart_total         numeric,
    updated_at         timestamp with time zone
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    c.id as cart_id,
    s.id as shop_id,
    s.name as shop_name,
    s.slug as shop_slug,
    null::text as shop_logo_url,
    s.shop_type::text as shop_type,
    coalesce(perm.can_see_buy_price, false) as can_see_buy_price,
    coalesce(perm.can_see_sell_price, false) as can_see_sell_price,
    s.sell_currency_id as currency_id,
    gc.code as currency_code,
    gc.symbol as currency_symbol,
    coalesce(sum(ci.quantity), 0)::bigint as item_count,
    case
      when s.shop_type = 'vendor_catalog'::public.shop_type_enum
        and coalesce(perm.can_see_buy_price, false) then
        sum(ci.quantity * coalesce(ci.unit_list_price_amount, 0))::numeric
      when coalesce(perm.can_see_sell_price, false) then
        sum(
          ci.quantity * coalesce(
            ci.customer_sell_price_amount,
            ci.unit_sell_price_amount,
            case
              when s.shop_type = 'vendor_catalog'::public.shop_type_enum then null
              else ci.unit_list_price_amount
            end,
            0
          )
        )::numeric
      else null
    end as cart_total,
    c.updated_at
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  join public.shop_cart_items ci on ci.cart_id = c.id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  left join lateral (
    select p.can_see_buy_price, p.can_see_sell_price
    from public.get_shop_permissions_for_customer(s.id) p
    limit 1
  ) perm on true
  where p_tenant_id is not null
    and c.status = 'active'
    and c.tenant_id = p_tenant_id
    and c.customer_group_id = public.current_customer_group_id(p_tenant_id)
  group by c.id, s.id, s.shop_type, gc.code, gc.symbol, perm.can_see_buy_price, perm.can_see_sell_price
  order by c.updated_at desc;
$function$;

GRANT ALL ON FUNCTION public.list_customer_active_carts(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_customer_active_carts(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_customer_active_carts(bigint) TO service_role;
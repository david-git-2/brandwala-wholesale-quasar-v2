-- Expose price visibility and each shop's sell currency to the cart picker.
drop function if exists public.list_active_shop_carts();

create function public.list_active_shop_carts()
returns table (
  cart_id bigint,
  shop_id bigint,
  shop_name text,
  shop_slug text,
  shop_logo_url text,
  shop_type text,
  see_price boolean,
  currency_id bigint,
  currency_code text,
  currency_symbol text,
  item_count bigint,
  cart_total numeric,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id as cart_id,
    s.id as shop_id,
    s.name as shop_name,
    s.slug as shop_slug,
    null::text as shop_logo_url,
    s.shop_type::text as shop_type,
    c.see_price_snapshot as see_price,
    s.sell_currency_id as currency_id,
    gc.code as currency_code,
    gc.symbol as currency_symbol,
    coalesce(sum(ci.quantity), 0)::bigint as item_count,
    case
      when c.see_price_snapshot then
        sum(
          ci.quantity * coalesce(
            ci.customer_sell_price_amount,
            ci.unit_sell_price_amount,
            ci.unit_list_price_amount,
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
  where c.status = 'active'
    and (public.current_tenant_id() is null or c.tenant_id = public.current_tenant_id())
    and public.is_cart_owner(c.customer_group_id, c.tenant_id)
  group by c.id, s.id, gc.code, gc.symbol
  order by c.updated_at desc;
$$;

revoke all on function public.list_active_shop_carts() from public;
revoke all on function public.list_active_shop_carts() from anon;
grant execute on function public.list_active_shop_carts() to authenticated;

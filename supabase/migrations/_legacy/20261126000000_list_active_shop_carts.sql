-- Migration: List Active Shop Carts RPC for Shop Scope
create or replace function public.list_active_shop_carts()
returns table (
  cart_id bigint,
  shop_id bigint,
  shop_name text,
  shop_slug text,
  shop_logo_url text,
  shop_type text,
  item_count bigint,
  cart_total numeric,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select 
    c.id as cart_id,
    s.id as shop_id,
    s.name as shop_name,
    s.slug as shop_slug,
    s.logo_url as shop_logo_url,
    s.shop_type::text as shop_type,
    coalesce((select sum(ci.quantity)::bigint from public.shop_cart_items ci where ci.cart_id = c.id), 0) as item_count,
    coalesce((
      select sum(
        ci.quantity * coalesce(
          ci.customer_sell_price_amount, 
          ci.unit_sell_price_amount, 
          ci.unit_list_price_amount, 
          0
        )
      )::numeric
      from public.shop_cart_items ci where ci.cart_id = c.id
    ), 0) as cart_total,
    c.updated_at
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  where c.tenant_id = public.current_tenant_id()
    and c.status = 'active'
    and public.is_cart_owner(c.customer_group_id, c.tenant_id)
    and exists (select 1 from public.shop_cart_items ci where ci.cart_id = c.id)
  order by c.updated_at desc;
end;
$$;

grant execute on function public.list_active_shop_carts() to authenticated;

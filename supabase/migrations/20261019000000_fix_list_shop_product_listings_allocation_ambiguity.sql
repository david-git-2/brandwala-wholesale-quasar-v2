-- Fix the PL/pgSQL ambiguity error (42702) for global_stock_allocation_id in list_shop_product_listings
begin;

create or replace function public.list_shop_product_listings(p_shop_id bigint)
returns table (
  id bigint,
  tenant_id bigint,
  shop_id bigint,
  global_stock_allocation_id bigint,
  global_stock_id bigint,
  product_id bigint,
  sell_price_amount numeric,
  sell_price_currency_id bigint,
  minimum_sell_price_amount numeric,
  minimum_sell_price_currency_id bigint,
  show_quantity boolean,
  display_quantity_override integer,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  product_name text,
  product_image_url text,
  product_barcode text,
  product_code text,
  product_brand text,
  product_category text,
  allocated_quantity integer,
  available_to_sell integer
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_tenant_id bigint;
begin
  select s.tenant_id into v_tenant_id from public.shops s where s.id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  -- Caller must be member of the shop's tenant
  if not exists (
    select 1 from public.memberships m
    where m.tenant_id = v_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'not allowed';
  end if;

  return query
  select
    l.id,
    l.tenant_id,
    l.shop_id,
    l.global_stock_allocation_id,
    l.global_stock_id,
    l.product_id,
    l.sell_price_amount,
    l.sell_price_currency_id,
    l.minimum_sell_price_amount,
    l.minimum_sell_price_currency_id,
    l.show_quantity,
    l.display_quantity_override,
    l.is_active,
    l.created_at,
    l.updated_at,
    p.name as product_name,
    p.image_url as product_image_url,
    p.barcode as product_barcode,
    p.product_code as product_code,
    p.brand as product_brand,
    p.category as product_category,
    gsa.quantity as allocated_quantity,
    -- Subtract active reservations + pending orders
    (gsa.quantity 
     - coalesce((select sum(ssr.quantity)::integer from public.shop_stock_reservations ssr where ssr.global_stock_allocation_id = gsa.id), 0)
     - public.get_pending_order_qty(gsa.id)
    )::integer as available_to_sell
  from public.shop_product_listings l
  join public.products p on p.id = l.product_id
  join public.global_stock_allocations gsa on gsa.id = l.global_stock_allocation_id
  where l.shop_id = p_shop_id
  order by p.name asc;
end;
$$;

commit;

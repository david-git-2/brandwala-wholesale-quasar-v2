-- Fix the PL/pgSQL error (428C9) where inserting a custom/generated value into an identity column is blocked.
begin;

create or replace function public.upsert_shop_product_listing(
  p_tenant_id bigint,
  p_shop_id bigint,
  p_global_stock_allocation_id bigint,
  p_sell_price_amount numeric,
  p_sell_price_currency_id bigint,
  p_minimum_sell_price_amount numeric default null,
  p_minimum_sell_price_currency_id bigint default null,
  p_show_quantity boolean default null,
  p_display_quantity_override integer default null,
  p_is_active boolean default true,
  p_id bigint default null
)
returns setof public.shop_product_listings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_global_stock_id bigint;
  v_product_id bigint;
begin
  -- Caller must be admin/staff of this tenant
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  -- Resolve denormalized IDs
  select gsa.stock_id, gsi.product_id
  into v_global_stock_id, v_product_id
  from public.global_stock_allocations gsa
  join public.global_stocks gs on gs.id = gsa.stock_id
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gsa.id = p_global_stock_allocation_id;

  if v_global_stock_id is null or v_product_id is null then
    raise exception 'invalid global stock allocation';
  end if;

  -- Dropship dual money constraint
  if (p_minimum_sell_price_amount is null) <> (p_minimum_sell_price_currency_id is null) then
    raise exception 'both minimum_sell_price_amount and minimum_sell_price_currency_id must be provided together or be null';
  end if;

  return query
  insert into public.shop_product_listings (
    id,
    tenant_id,
    shop_id,
    global_stock_allocation_id,
    global_stock_id,
    product_id,
    sell_price_amount,
    sell_price_currency_id,
    minimum_sell_price_amount,
    minimum_sell_price_currency_id,
    show_quantity,
    display_quantity_override,
    is_active
  )
  overriding system value
  values (
    coalesce(p_id, nextval(pg_get_serial_sequence('public.shop_product_listings', 'id'))),
    p_tenant_id,
    p_shop_id,
    p_global_stock_allocation_id,
    v_global_stock_id,
    v_product_id,
    p_sell_price_amount,
    p_sell_price_currency_id,
    p_minimum_sell_price_amount,
    p_minimum_sell_price_currency_id,
    p_show_quantity,
    p_display_quantity_override,
    p_is_active
  )
  on conflict (shop_id, global_stock_allocation_id) do update set
    sell_price_amount = excluded.sell_price_amount,
    sell_price_currency_id = excluded.sell_price_currency_id,
    minimum_sell_price_amount = excluded.minimum_sell_price_amount,
    minimum_sell_price_currency_id = excluded.minimum_sell_price_currency_id,
    show_quantity = excluded.show_quantity,
    display_quantity_override = excluded.display_quantity_override,
    is_active = excluded.is_active,
    updated_at = now()
  returning *;
end;
$$;

commit;

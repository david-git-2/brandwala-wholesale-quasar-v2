-- Fix column "product_id" does not exist in upsert_shop_product_listing RPC

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
  p_id bigint default null,
  p_is_price_locked boolean default null,
  p_is_quantity_locked boolean default null,
  p_quantity_override_type text default null
)
returns setof public.shop_product_listings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_id bigint;
  v_global_stock_id bigint;
  v_existing record;
  v_price_locked boolean;
  v_qty_locked boolean;
  v_override_type text;
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  -- Resolve stock & product id from allocation by joining global_stocks and global_shipment_items
  select gsa.stock_id, gsi.product_id
  into v_global_stock_id, v_product_id
  from public.global_stock_allocations gsa
  join public.global_stocks gs on gs.id = gsa.stock_id
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gsa.id = p_global_stock_allocation_id;

  if v_global_stock_id is null then
    raise exception 'allocation not found';
  end if;

  if p_id is not null then
    select * into v_existing from public.shop_product_listings where id = p_id;
  else
    select * into v_existing from public.shop_product_listings
    where shop_id = p_shop_id and global_stock_allocation_id = p_global_stock_allocation_id;
  end if;

  v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
  v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
  v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

  if v_existing.id is not null then
    return query
    update public.shop_product_listings
    set
      sell_price_amount = p_sell_price_amount,
      sell_price_currency_id = p_sell_price_currency_id,
      minimum_sell_price_amount = p_minimum_sell_price_amount,
      minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
      show_quantity = p_show_quantity,
      display_quantity_override = p_display_quantity_override,
      is_active = p_is_active,
      is_price_locked = v_price_locked,
      is_quantity_locked = v_qty_locked,
      quantity_override_type = v_override_type,
      updated_at = now()
    where id = v_existing.id
    returning *;
  else
    return query
    insert into public.shop_product_listings (
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
      is_active,
      is_price_locked,
      is_quantity_locked,
      quantity_override_type
    )
    values (
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
      p_is_active,
      v_price_locked,
      v_qty_locked,
      v_override_type
    )
    returning *;
  end if;
end;
$$;

grant execute on function public.upsert_shop_product_listing(
  bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint, boolean, boolean, text
) to authenticated;

-- SQL Migration: 20261130000012_pricing_ux_fixes.sql
-- Description: Phase 6 - Dropship Automation Pricing UX Fixes (Lock fields, flexible quantity override types, default quantity visibility, and RPC updates)

begin;

-- 1. Schema Extensions
alter table public.shop_product_listings
  add column if not exists is_price_locked boolean not null default false,
  add column if not exists is_quantity_locked boolean not null default false,
  add column if not exists quantity_override_type text not null default 'absolute';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'shop_product_listings_qty_override_type_check'
  ) then
    alter table public.shop_product_listings
      add constraint shop_product_listings_qty_override_type_check
      check (quantity_override_type in ('absolute', 'relative'));
  end if;
end;
$$;

alter table public.shop_pricing_rules
  add column if not exists default_show_quantity boolean not null default true;

-- 2. Update upsert_shop_pricing_rule RPC
create or replace function public.upsert_shop_pricing_rule(
  p_shop_id bigint,
  p_markup_percentage numeric,
  p_is_auto_publish boolean,
  p_default_show_quantity boolean default true
)
returns setof public.shop_pricing_rules
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  insert into public.shop_pricing_rules (
    tenant_id,
    shop_id,
    markup_percentage,
    is_auto_publish,
    default_show_quantity
  )
  values (
    v_tenant_id,
    p_shop_id,
    p_markup_percentage,
    p_is_auto_publish,
    coalesce(p_default_show_quantity, true)
  )
  on conflict (shop_id) do update set
    markup_percentage = excluded.markup_percentage,
    is_auto_publish = excluded.is_auto_publish,
    default_show_quantity = excluded.default_show_quantity,
    updated_at = now()
  returning *;
end;
$$;

grant execute on function public.upsert_shop_pricing_rule(bigint, numeric, boolean, boolean) to authenticated;

-- 3. Update upsert_shop_product_listing RPC
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

  -- Resolve stock & product id from allocation
  select stock_id, product_id into v_global_stock_id, v_product_id
  from public.global_stock_allocations
  where id = p_global_stock_allocation_id;

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

-- 4. Update bulk_apply_shop_markup RPC
create or replace function public.bulk_apply_shop_markup(
  p_shop_id bigint,
  p_markup_amount numeric default null,
  p_markup_type text default 'percentage',
  p_target_price text default 'sell_price',
  p_listing_ids bigint[] default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_amount numeric;
  v_count integer := 0;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_amount := p_markup_amount;
  if v_amount is null then
    select markup_percentage into v_amount
    from public.shop_pricing_rules
    where shop_id = p_shop_id;
  end if;

  v_amount := coalesce(v_amount, 0.00);

  if p_target_price = 'min_sell_price' then
    update public.shop_product_listings spl
    set
      minimum_sell_price_amount = case
        when p_markup_type = 'percentage' then
          round(coalesce(spl.minimum_sell_price_amount, 0.00) * (1 + (v_amount / 100.0)), 2)
        else
          round(coalesce(spl.minimum_sell_price_amount, 0.00) + v_amount, 2)
      end,
      updated_at = now()
    where spl.shop_id = p_shop_id
      and (p_listing_ids is null or spl.id = any(p_listing_ids))
      and spl.is_price_locked is false;
  else
    update public.shop_product_listings spl
    set
      sell_price_amount = case
        when p_markup_type = 'percentage' then
          round(coalesce(spl.minimum_sell_price_amount, spl.sell_price_amount) * (1 + (v_amount / 100.0)), 2)
        else
          round(coalesce(spl.minimum_sell_price_amount, spl.sell_price_amount) + v_amount, 2)
      end,
      updated_at = now()
    where spl.shop_id = p_shop_id
      and (p_listing_ids is null or spl.id = any(p_listing_ids))
      and spl.is_price_locked is false;
  end if;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.bulk_apply_shop_markup(bigint, numeric, text, text, bigint[]) to authenticated;

-- 5. Update trg_reactive_adjust_child_listing_cost trigger
create or replace function public.trg_reactive_adjust_child_listing_cost()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_landed_cost numeric;
begin
  if new.purchase_price <> old.purchase_price then
    v_new_landed_cost := round(new.purchase_price * coalesce((
      select product_conversion_rate from public.global_shipments where id = new.shipment_id
    ), 1.0), 2);

    update public.shop_product_listings spl
    set
      minimum_sell_price_amount = case
        when spl.is_price_locked is true then spl.minimum_sell_price_amount
        else v_new_landed_cost
      end,
      minimum_sell_price_currency_id = new.purchase_price_currency_id,
      sell_price_amount = case
        when spl.is_price_locked is true then spl.sell_price_amount
        else greatest(spl.sell_price_amount, v_new_landed_cost)
      end,
      updated_at = now()
    from public.global_stocks gs
    where spl.global_stock_id = gs.id
      and gs.shipment_item_id = new.id;
  end if;

  return new;
end;
$$;

commit;

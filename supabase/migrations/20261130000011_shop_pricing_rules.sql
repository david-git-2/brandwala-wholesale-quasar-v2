-- SQL Migration: 20261130000011_shop_pricing_rules.sql
-- Description: Phase 1 - Dropship Store Automation & Pricing Strategy (Schema, Rules, Auto-Publish Trigger, Reactive Cost Adjustment Trigger, and Bulk Apply RPC)

begin;

-- 1. Create shop_pricing_rules table
create table if not exists public.shop_pricing_rules (
  id bigint generated always as identity primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  shop_id bigint not null references public.shops(id) on delete cascade,
  markup_percentage numeric(8,2) not null default 0.00,
  is_auto_publish boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint shop_pricing_rules_unique_shop unique (shop_id),
  constraint shop_pricing_rules_markup_non_negative check (markup_percentage >= 0)
);

create or replace function public.set_shop_pricing_rules_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_shop_pricing_rules_updated_at on public.shop_pricing_rules;
create trigger trg_shop_pricing_rules_updated_at
  before update on public.shop_pricing_rules
  for each row execute function public.set_shop_pricing_rules_updated_at();

-- 2. RLS for shop_pricing_rules
alter table public.shop_pricing_rules enable row level security;

drop policy if exists "shop_pricing_rules_select" on public.shop_pricing_rules;
create policy "shop_pricing_rules_select"
  on public.shop_pricing_rules for select
  using (
    tenant_id in (
      select tm.tenant_id
      from public.memberships tm
      where lower(trim(tm.email)) = public.current_user_email()
        and tm.is_active = true
    )
  );

drop policy if exists "shop_pricing_rules_write" on public.shop_pricing_rules;
create policy "shop_pricing_rules_write"
  on public.shop_pricing_rules for all
  using (public.user_can_manage_shop_tenant(tenant_id))
  with check (public.user_can_manage_shop_tenant(tenant_id));

grant select, insert, update, delete on public.shop_pricing_rules to authenticated;

-- 3. Function/RPC to get or upsert shop pricing rule
create or replace function public.upsert_shop_pricing_rule(
  p_shop_id bigint,
  p_markup_percentage numeric,
  p_is_auto_publish boolean
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
    is_auto_publish
  )
  values (
    v_tenant_id,
    p_shop_id,
    p_markup_percentage,
    p_is_auto_publish
  )
  on conflict (shop_id) do update set
    markup_percentage = excluded.markup_percentage,
    is_auto_publish = excluded.is_auto_publish,
    updated_at = now()
  returning *;
end;
$$;

grant execute on function public.upsert_shop_pricing_rule(bigint, numeric, boolean) to authenticated;

-- 4. Bulk Apply Shop Markup RPC
create or replace function public.bulk_apply_shop_markup(
  p_shop_id bigint,
  p_markup_percentage numeric default null,
  p_listing_ids bigint[] default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_markup numeric;
  v_count integer := 0;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  -- Use provided markup or lookup from rule
  v_markup := p_markup_percentage;
  if v_markup is null then
    select markup_percentage into v_markup
    from public.shop_pricing_rules
    where shop_id = p_shop_id;
  end if;

  v_markup := coalesce(v_markup, 0.00);

  update public.shop_product_listings spl
  set
    sell_price_amount = round(
      coalesce(spl.minimum_sell_price_amount, spl.sell_price_amount) * (1 + (v_markup / 100.0)),
      2
    ),
    updated_at = now()
  where spl.shop_id = p_shop_id
    and (p_listing_ids is null or spl.id = any(p_listing_ids));

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.bulk_apply_shop_markup(bigint, numeric, bigint[]) to authenticated;

-- 5. Trigger on global_stock_allocations to auto-publish dropship listings
create or replace function public.trg_auto_publish_dropship_listing()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop record;
  v_rule record;
  v_landed_cost numeric;
  v_currency_id bigint;
  v_product_id bigint;
  v_stock_id bigint;
  v_sell_price numeric;
begin
  -- For each shop owned by the target child tenant that has auto_publish enabled
  for v_shop in (
    select s.id as shop_id, s.tenant_id
    from public.shops s
    where s.tenant_id = new.tenant_id
  ) loop
    select * into v_rule
    from public.shop_pricing_rules
    where shop_id = v_shop.shop_id;

    if v_rule.is_auto_publish is true then
      -- Calculate parent landed cost for minimum_sell_price
      select
        (gsi.purchase_price * coalesce(gship.product_conversion_rate, 1.0)),
        gsi.purchase_price_currency_id,
        gsi.product_id,
        gs.id
      into v_landed_cost, v_currency_id, v_product_id, v_stock_id
      from public.global_stocks gs
      join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      join public.global_shipments gship on gship.id = gsi.shipment_id
      where gs.id = new.stock_id;

      if v_landed_cost is not null and v_currency_id is not null then
        v_sell_price := round(v_landed_cost * (1 + (coalesce(v_rule.markup_percentage, 0.00) / 100.0)), 2);

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
          is_active
        )
        values (
          v_shop.tenant_id,
          v_shop.shop_id,
          new.id,
          v_stock_id,
          v_product_id,
          v_sell_price,
          v_currency_id,
          round(v_landed_cost, 2),
          v_currency_id,
          true
        )
        on conflict (shop_id, global_stock_allocation_id) do update set
          minimum_sell_price_amount = excluded.minimum_sell_price_amount,
          minimum_sell_price_currency_id = excluded.minimum_sell_price_currency_id,
          sell_price_amount = case
            when shop_product_listings.sell_price_amount < excluded.minimum_sell_price_amount then excluded.sell_price_amount
            else shop_product_listings.sell_price_amount
          end,
          updated_at = now();
      end if;
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_global_stock_allocations_auto_publish on public.global_stock_allocations;
create trigger trg_global_stock_allocations_auto_publish
  after insert on public.global_stock_allocations
  for each row execute function public.trg_auto_publish_dropship_listing();

-- 6. Trigger on parent global_shipment_items cost update to reactively adjust child tenant listings minimum_sell_price
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
      minimum_sell_price_amount = v_new_landed_cost,
      minimum_sell_price_currency_id = new.purchase_price_currency_id,
      sell_price_amount = greatest(spl.sell_price_amount, v_new_landed_cost),
      updated_at = now()
    from public.global_stocks gs
    where spl.global_stock_id = gs.id
      and gs.shipment_item_id = new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_global_shipment_items_reactive_cost on public.global_shipment_items;
create trigger trg_global_shipment_items_reactive_cost
  after update of purchase_price on public.global_shipment_items
  for each row execute function public.trg_reactive_adjust_child_listing_cost();

commit;

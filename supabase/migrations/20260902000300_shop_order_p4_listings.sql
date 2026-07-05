begin;

-- =========================================================
-- 1. shop_product_listings Table
-- =========================================================
create table if not exists public.shop_product_listings (
  id bigint generated always as identity primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  shop_id bigint not null references public.shops(id) on delete cascade,
  global_stock_allocation_id bigint not null references public.global_stock_allocations(id) on delete cascade,
  global_stock_id bigint not null references public.global_stocks(id) on delete cascade,
  product_id bigint not null references public.products(id) on delete cascade,
  sell_price_amount numeric(12,4) not null,
  sell_price_currency_id bigint not null references public.global_currencies(id),
  minimum_sell_price_amount numeric(12,4) default null,
  minimum_sell_price_currency_id bigint references public.global_currencies(id) default null,
  show_quantity boolean default null,
  display_quantity_override integer default null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint shop_product_listings_unique_shop_alloc unique (shop_id, global_stock_allocation_id),
  constraint shop_product_listings_min_sell_currency check (
    (minimum_sell_price_amount is null) = (minimum_sell_price_currency_id is null)
  )
);

create or replace function public.set_shop_product_listings_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_shop_product_listings_updated_at on public.shop_product_listings;
create trigger trg_shop_product_listings_updated_at
  before update on public.shop_product_listings
  for each row execute function public.set_shop_product_listings_updated_at();

-- =========================================================
-- 2. RLS Enablement
-- =========================================================
alter table public.shop_product_listings enable row level security;

-- select policy: tenant members can read
create policy "listings_select_tenant_member"
  on public.shop_product_listings for select
  using (
    tenant_id in (
      select tm.tenant_id
      from public.memberships tm
      where lower(trim(tm.email)) = public.current_user_email()
        and tm.is_active = true
    )
  );

-- write policy: tenant admin/staff can manage
create policy "listings_write_tenant_admin_staff"
  on public.shop_product_listings for all
  using (
    tenant_id in (
      select m.tenant_id
      from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
        and m.role in ('admin', 'staff')
        and m.is_active = true
    )
  );

-- superadmin policy
create policy "listings_superadmin_all"
  on public.shop_product_listings for all
  using (
    exists (
      select 1 from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
        and m.role = 'superadmin'
        and m.is_active = true
    )
  );

-- =========================================================
-- 3. RPC: list_shop_product_listings
-- =========================================================
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
  -- joined product details
  product_name text,
  product_image_url text,
  product_barcode text,
  product_code text,
  product_brand text,
  product_category text,
  -- stock quantities
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
  select tenant_id into v_tenant_id from public.shops where shops.id = p_shop_id;
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
    -- Subtract reservations and pending order quantities. For now, since those tables don't exist yet, we treat them as 0.
    gsa.quantity as available_to_sell
  from public.shop_product_listings l
  join public.products p on p.id = l.product_id
  join public.global_stock_allocations gsa on gsa.id = l.global_stock_allocation_id
  where l.shop_id = p_shop_id
  order by p.name asc;
end;
$$;

grant execute on function public.list_shop_product_listings(bigint) to authenticated;

-- =========================================================
-- 4. RPC: upsert_shop_product_listing
-- =========================================================
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

grant execute on function public.upsert_shop_product_listing(bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint) to authenticated;

-- =========================================================
-- 5. RPC: list_allocations_for_shop_pick
-- =========================================================
create or replace function public.list_allocations_for_shop_pick(
  p_tenant_id bigint,
  p_shop_id bigint
)
returns table (
  allocation_id bigint,
  stock_id bigint,
  product_id bigint,
  product_name text,
  product_image_url text,
  product_barcode text,
  product_code text,
  product_brand text,
  product_category text,
  allocated_quantity integer
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  -- Caller must be member of this tenant
  if not exists (
    select 1 from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'not allowed';
  end if;

  return query
  select
    gsa.id as allocation_id,
    gsa.stock_id,
    gsi.product_id,
    p.name as product_name,
    p.image_url as product_image_url,
    p.barcode as product_barcode,
    p.product_code as product_code,
    p.brand as product_brand,
    p.category as product_category,
    gsa.quantity as allocated_quantity
  from public.global_stock_allocations gsa
  join public.global_stocks gs on gs.id = gsa.stock_id
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  join public.products p on p.id = gsi.product_id
  where gsa.child_tenant_id = p_tenant_id
    and not exists (
      select 1 from public.shop_product_listings spl
      where spl.shop_id = p_shop_id
        and spl.global_stock_allocation_id = gsa.id
    )
  order by p.name asc;
end;
$$;

grant execute on function public.list_allocations_for_shop_pick(bigint, bigint) to authenticated;

commit;

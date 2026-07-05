-- Migration: Shop Order Phase 6 — Cart & Reservations
begin;

-- =========================================================
-- 1. Enum types
-- =========================================================
do $$ begin
  if not exists (select 1 from pg_type where typname = 'shop_cart_status') then
    create type public.shop_cart_status as enum (
      'active',
      'converted',
      'abandoned'
    );
  end if;
end $$;

-- =========================================================
-- 2. Tables
-- =========================================================

-- shop_carts
create table if not exists public.shop_carts (
  id                  bigint generated always as identity primary key,
  tenant_id           bigint not null references public.tenants(id) on delete cascade,
  shop_id             bigint not null references public.shops(id) on delete cascade,
  customer_group_id   bigint not null references public.customer_groups(id) on delete cascade,
  see_price_snapshot  boolean not null default false,
  status              public.shop_cart_status not null default 'active',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create unique index if not exists shop_carts_active_unique_idx 
  on public.shop_carts(tenant_id, shop_id, customer_group_id) 
  where status = 'active';

-- shop_cart_items
create table if not exists public.shop_cart_items (
  id                                  bigint generated always as identity primary key,
  cart_id                             bigint not null references public.shop_carts(id) on delete cascade,
  product_id                          bigint not null references public.products(id) on delete cascade,
  global_stock_id                     bigint references public.global_stocks(id) on delete set null,
  global_stock_allocation_id          bigint references public.global_stock_allocations(id) on delete set null,
  quantity                            integer not null constraint shop_cart_items_qty_positive check (quantity > 0),
  minimum_quantity                    integer not null default 1 constraint shop_cart_items_min_qty_positive check (minimum_quantity > 0),
  
  -- pricing snapshots at add time
  unit_list_price_amount              numeric(12,4),
  unit_list_price_currency_id         bigint references public.global_currencies(id),
  unit_sell_price_amount              numeric(12,4),
  unit_sell_price_currency_id         bigint references public.global_currencies(id),
  unit_minimum_sell_price_amount      numeric(12,4),
  unit_minimum_sell_price_currency_id bigint references public.global_currencies(id),
  customer_sell_price_amount          numeric(12,4),
  customer_sell_price_currency_id     bigint references public.global_currencies(id),
  
  name                                text not null,
  image_url                           text,
  created_at                          timestamptz not null default now(),
  updated_at                          timestamptz not null default now()
);

-- shop_stock_reservations
create table if not exists public.shop_stock_reservations (
  cart_item_id                bigint primary key references public.shop_cart_items(id) on delete cascade,
  global_stock_allocation_id  bigint not null references public.global_stock_allocations(id) on delete cascade,
  quantity                    integer not null constraint shop_stock_reservations_qty_non_negative check (quantity >= 0),
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);

-- =========================================================
-- 3. Triggers for updated_at
-- =========================================================
create or replace function public.set_shop_order_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_shop_carts_updated_at on public.shop_carts;
create trigger trg_shop_carts_updated_at
  before update on public.shop_carts
  for each row execute function public.set_shop_order_updated_at();

drop trigger if exists trg_shop_cart_items_updated_at on public.shop_cart_items;
create trigger trg_shop_cart_items_updated_at
  before update on public.shop_cart_items
  for each row execute function public.set_shop_order_updated_at();

drop trigger if exists trg_shop_stock_reservations_updated_at on public.shop_stock_reservations;
create trigger trg_shop_stock_reservations_updated_at
  before update on public.shop_stock_reservations
  for each row execute function public.set_shop_order_updated_at();

-- =========================================================
-- 4. Trigger: Sync reservations from cart items
-- =========================================================
create or replace function public.sync_shop_cart_item_reservation()
returns trigger language plpgsql as $$
begin
  if tg_op = 'DELETE' then
    delete from public.shop_stock_reservations where cart_item_id = old.id;
    return old;
  end if;

  if new.global_stock_allocation_id is not null and new.quantity > 0 then
    insert into public.shop_stock_reservations (cart_item_id, global_stock_allocation_id, quantity)
    values (new.id, new.global_stock_allocation_id, new.quantity)
    on conflict (cart_item_id) do update set
      global_stock_allocation_id = excluded.global_stock_allocation_id,
      quantity = excluded.quantity;
  else
    delete from public.shop_stock_reservations where cart_item_id = new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sync_shop_cart_item_reservation on public.shop_cart_items;
create trigger trg_sync_shop_cart_item_reservation
  after insert or update or delete on public.shop_cart_items
  for each row execute function public.sync_shop_cart_item_reservation();

-- =========================================================
-- 5. RLS Policies
-- =========================================================
alter table public.shop_carts enable row level security;
alter table public.shop_cart_items enable row level security;
alter table public.shop_stock_reservations enable row level security;

-- Helper to verify if the current user belongs to the customer group in the cart
create or replace function public.is_cart_owner(p_customer_group_id bigint, p_tenant_id bigint)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    where cg.id = p_customer_group_id
      and cg.tenant_id = p_tenant_id
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.is_active = true
      and cg.is_active = true
  );
$$;

-- Helper to verify if the current user is tenant admin/staff
create or replace function public.is_tenant_staff(p_tenant_id bigint)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.role in ('admin', 'staff', 'superadmin')
      and m.is_active = true
  );
$$;

-- shop_carts policies
create policy "shop_carts_customer_owner"
  on public.shop_carts for all
  using (public.is_cart_owner(customer_group_id, tenant_id))
  with check (public.is_cart_owner(customer_group_id, tenant_id));

create policy "shop_carts_staff_view"
  on public.shop_carts for select
  using (public.is_tenant_staff(tenant_id));

-- shop_cart_items policies
create policy "shop_cart_items_customer_owner"
  on public.shop_cart_items for all
  using (
    exists (
      select 1 from public.shop_carts c
      where c.id = cart_id
        and public.is_cart_owner(c.customer_group_id, c.tenant_id)
    )
  )
  with check (
    exists (
      select 1 from public.shop_carts c
      where c.id = cart_id
        and public.is_cart_owner(c.customer_group_id, c.tenant_id)
    )
  );

create policy "shop_cart_items_staff_view"
  on public.shop_cart_items for select
  using (
    exists (
      select 1 from public.shop_carts c
      where c.id = cart_id
        and public.is_tenant_staff(c.tenant_id)
    )
  );

-- shop_stock_reservations policies
create policy "shop_stock_reservations_customer_owner"
  on public.shop_stock_reservations for all
  using (
    exists (
      select 1 from public.shop_cart_items ci
      join public.shop_carts c on c.id = ci.cart_id
      where ci.id = cart_item_id
        and public.is_cart_owner(c.customer_group_id, c.tenant_id)
    )
  )
  with check (
    exists (
      select 1 from public.shop_cart_items ci
      join public.shop_carts c on c.id = ci.cart_id
      where ci.id = cart_item_id
        and public.is_cart_owner(c.customer_group_id, c.tenant_id)
    )
  );

create policy "shop_stock_reservations_staff_view"
  on public.shop_stock_reservations for select
  using (
    exists (
      select 1 from public.shop_cart_items ci
      join public.shop_carts c on c.id = ci.cart_id
      where ci.id = cart_item_id
        and public.is_tenant_staff(c.tenant_id)
    )
  );

-- Grant privileges
grant select, insert, update, delete on table public.shop_carts to authenticated;
grant select, insert, update, delete on table public.shop_cart_items to authenticated;
grant select, insert, update, delete on table public.shop_stock_reservations to authenticated;

-- =========================================================
-- 6. RPC: get_or_create_shop_cart
-- =========================================================
create or replace function public.get_or_create_shop_cart(p_shop_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_customer_group_id bigint;
  v_see_price_snapshot boolean;
  v_cart_id bigint;
  v_result jsonb;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id and is_active = true;
  if v_tenant_id is null then
    raise exception 'shop not found or inactive';
  end if;

  -- Find group that belongs to the user and has permissions
  select cg.id, coalesce(p.see_price, false)
  into v_customer_group_id, v_see_price_snapshot
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  join public.get_shop_permissions_for_customer(p_shop_id) p on true
  where cg.tenant_id = v_tenant_id
    and lower(trim(cgm.email)) = public.current_user_email()
    and cgm.is_active = true
    and cg.is_active = true
  limit 1;

  if v_customer_group_id is null then
    raise exception 'no customer group access found';
  end if;

  -- Ensure they can browse
  if not public.can_customer_access_shop(p_shop_id) then
    raise exception 'access denied';
  end if;

  -- Find or insert active cart
  select id into v_cart_id 
  from public.shop_carts
  where tenant_id = v_tenant_id
    and shop_id = p_shop_id
    and customer_group_id = v_customer_group_id
    and status = 'active'
  order by id desc
  limit 1;

  if v_cart_id is null then
    insert into public.shop_carts (
      tenant_id, shop_id, customer_group_id, see_price_snapshot, status
    )
    values (
      v_tenant_id, p_shop_id, v_customer_group_id, v_see_price_snapshot, 'active'
    )
    returning id into v_cart_id;
  end if;

  -- Return serialized cart with items list
  select jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'customer_group_id', c.customer_group_id,
      'see_price_snapshot', c.see_price_snapshot,
      'status', c.status,
      'created_at', c.created_at,
      'updated_at', c.updated_at
    ),
    'items', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ci.id,
            'cart_id', ci.cart_id,
            'product_id', ci.product_id,
            'global_stock_id', ci.global_stock_id,
            'global_stock_allocation_id', ci.global_stock_allocation_id,
            'quantity', ci.quantity,
            'minimum_quantity', ci.minimum_quantity,
            'unit_list_price_amount', ci.unit_list_price_amount,
            'unit_list_price_currency_id', ci.unit_list_price_currency_id,
            'unit_sell_price_amount', ci.unit_sell_price_amount,
            'unit_sell_price_currency_id', ci.unit_sell_price_currency_id,
            'unit_minimum_sell_price_amount', ci.unit_minimum_sell_price_amount,
            'unit_minimum_sell_price_currency_id', ci.unit_minimum_sell_price_currency_id,
            'customer_sell_price_amount', ci.customer_sell_price_amount,
            'customer_sell_price_currency_id', ci.customer_sell_price_currency_id,
            'name', ci.name,
            'image_url', ci.image_url
          )
        )
        from public.shop_cart_items ci
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from public.shop_carts c
  where c.id = v_cart_id;

  return v_result;
end;
$$;

grant execute on function public.get_or_create_shop_cart(bigint) to authenticated;

-- =========================================================
-- 7. RPC: add_to_shop_cart
-- =========================================================
create or replace function public.add_to_shop_cart(
  p_shop_id bigint,
  p_product_id bigint,
  p_global_stock_allocation_id bigint default null,
  p_quantity integer default 1,
  p_customer_sell_price_amount numeric default null,
  p_customer_sell_price_currency_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart_res jsonb;
  v_cart_id bigint;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_prod_name text;
  v_prod_image text;
  v_prod_vendor text;
  v_prod_is_available boolean;
  v_prod_price_amount numeric;
  v_prod_price_currency_id bigint;
  
  v_listing_id bigint;
  v_global_stock_id bigint;
  v_sell_price_amount numeric;
  v_sell_price_currency_id bigint;
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
  v_display_qty_override integer;
  
  v_allocated_qty integer;
  v_other_reserved_qty integer;
  v_available_to_sell integer;
  
  v_existing_item_id bigint;
  v_existing_item_qty integer;
  v_target_qty integer;
  
  v_can_add_to_cart boolean;
  v_can_set_dropship_price boolean;
  v_customer_sell_price_amount numeric;
  v_customer_sell_price_currency_id bigint;
begin
  -- 1. Resolve / verify cart
  v_cart_res := public.get_or_create_shop_cart(p_shop_id);
  v_cart_id := (v_cart_res->'cart'->>'id')::bigint;
  
  select tenant_id, shop_type into v_tenant_id, v_shop_type from public.shops where id = p_shop_id;
  
  -- Check permission to add to cart
  select can_add_to_cart, can_set_dropship_price
  into v_can_add_to_cart, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(p_shop_id);
  
  if coalesce(v_can_add_to_cart, false) is not true then
    raise exception 'cart additions not allowed';
  end if;

  -- 2. Resolve product details
  select name, image_url, vendor_code, is_available, list_price_amount, list_price_currency_id
  into v_prod_name, v_prod_image, v_prod_vendor, v_prod_is_available, v_prod_price_amount, v_prod_price_currency_id
  from public.products
  where id = p_product_id;
  
  if v_prod_name is null or v_prod_is_available is not true then
    raise exception 'product not found or unavailable';
  end if;

  -- 3. If fixed_price or dropship, enforce allocation matching
  if v_shop_type in ('fixed_price', 'dropship') then
    if p_global_stock_allocation_id is null then
      raise exception 'global stock allocation required for this shop type';
    end if;

    select 
      l.id, l.global_stock_id, l.sell_price_amount, l.sell_price_currency_id,
      l.minimum_sell_price_amount, l.minimum_sell_price_currency_id, l.display_quantity_override,
      gsa.quantity
    into 
      v_listing_id, v_global_stock_id, v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id, v_display_qty_override,
      v_allocated_qty
    from public.shop_product_listings l
    join public.global_stock_allocations gsa on gsa.id = l.global_stock_allocation_id
    where l.shop_id = p_shop_id
      and l.global_stock_allocation_id = p_global_stock_allocation_id
      and l.product_id = p_product_id
      and l.is_active = true;

    if v_listing_id is null then
      raise exception 'active product listing not found on this shop';
    end if;

    -- Calculate current quantity in the cart for this allocation
    select id, quantity into v_existing_item_id, v_existing_item_qty
    from public.shop_cart_items
    where cart_id = v_cart_id
      and global_stock_allocation_id = p_global_stock_allocation_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;

    -- Calculate other reservations (excluding ours)
    select coalesce(sum(quantity), 0)
    into v_other_reserved_qty
    from public.shop_stock_reservations r
    where r.global_stock_allocation_id = p_global_stock_allocation_id
      and r.cart_item_id <> coalesce(v_existing_item_id, -1);

    v_available_to_sell := v_allocated_qty - v_other_reserved_qty;

    if v_target_qty > v_available_to_sell then
      raise exception 'insufficient stock: requested %, available %', v_target_qty, greatest(0, v_available_to_sell);
    end if;

    -- Handle dropship pricing
    if v_shop_type = 'dropship' then
      if coalesce(v_can_set_dropship_price, false) then
        v_customer_sell_price_amount := coalesce(p_customer_sell_price_amount, v_sell_price_amount);
        v_customer_sell_price_currency_id := coalesce(p_customer_sell_price_currency_id, v_sell_price_currency_id);
        
        -- Enforce minimum price floor if in the same currency
        if v_customer_sell_price_currency_id = v_min_sell_price_currency_id 
           and v_customer_sell_price_amount < v_min_sell_price_amount then
          raise exception 'price cannot be lower than minimum sell price';
        end if;
      else
        v_customer_sell_price_amount := v_sell_price_amount;
        v_customer_sell_price_currency_id := v_sell_price_currency_id;
      end if;
    end if;

  else
    -- Vendor catalog
    -- Enforce vendor catalog requirements
    -- Calculate current quantity in the cart for this product
    select id, quantity into v_existing_item_id, v_existing_item_qty
    from public.shop_cart_items
    where cart_id = v_cart_id
      and product_id = p_product_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;
  end if;

  -- 4. Upsert cart item
  if v_existing_item_id is not null then
    update public.shop_cart_items
    set 
      quantity = v_target_qty,
      customer_sell_price_amount = coalesce(v_customer_sell_price_amount, customer_sell_price_amount),
      customer_sell_price_currency_id = coalesce(v_customer_sell_price_currency_id, customer_sell_price_currency_id),
      updated_at = now()
    where id = v_existing_item_id;
  else
    insert into public.shop_cart_items (
      cart_id, product_id, global_stock_id, global_stock_allocation_id,
      quantity, minimum_quantity,
      unit_list_price_amount, unit_list_price_currency_id,
      unit_sell_price_amount, unit_sell_price_currency_id,
      unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
      customer_sell_price_amount, customer_sell_price_currency_id,
      name, image_url
    )
    values (
      v_cart_id, p_product_id, v_global_stock_id, p_global_stock_allocation_id,
      p_quantity, 1,
      v_prod_price_amount, v_prod_price_currency_id,
      v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      v_prod_name, v_prod_image
    );
  end if;

  return public.get_or_create_shop_cart(p_shop_id);
end;
$$;

grant execute on function public.add_to_shop_cart(bigint, bigint, bigint, integer, numeric, bigint) to authenticated;

-- =========================================================
-- 8. RPC: update_shop_cart_item_qty
-- =========================================================
create or replace function public.update_shop_cart_item_qty(
  p_cart_item_id bigint,
  p_quantity integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart_id bigint;
  v_shop_id bigint;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_global_stock_allocation_id bigint;
  v_allocated_qty integer;
  v_other_reserved_qty integer;
  v_available_to_sell integer;
begin
  if p_quantity <= 0 then
    return public.remove_shop_cart_item(p_cart_item_id);
  end if;

  select ci.cart_id, ci.global_stock_allocation_id, c.shop_id, c.tenant_id, s.shop_type
  into v_cart_id, v_global_stock_allocation_id, v_shop_id, v_tenant_id, v_shop_type
  from public.shop_cart_items ci
  join public.shop_carts c on c.id = ci.cart_id
  join public.shops s on s.id = c.shop_id
  where ci.id = p_cart_item_id;

  if v_cart_id is null then
    raise exception 'cart item not found';
  end if;

  -- Access verification via is_cart_owner RLS trigger fallback check
  if not public.is_cart_owner((select customer_group_id from public.shop_carts where id = v_cart_id), v_tenant_id) then
    raise exception 'access denied';
  end if;

  -- Verify stock if stock-backed
  if v_shop_type in ('fixed_price', 'dropship') and v_global_stock_allocation_id is not null then
    select quantity into v_allocated_qty
    from public.global_stock_allocations
    where id = v_global_stock_allocation_id;

    select coalesce(sum(quantity), 0)
    into v_other_reserved_qty
    from public.shop_stock_reservations r
    where r.global_stock_allocation_id = v_global_stock_allocation_id
      and r.cart_item_id <> p_cart_item_id;

    v_available_to_sell := v_allocated_qty - v_other_reserved_qty;

    if p_quantity > v_available_to_sell then
      raise exception 'insufficient stock: requested %, available %', p_quantity, greatest(0, v_available_to_sell);
    end if;
  end if;

  update public.shop_cart_items
  set quantity = p_quantity, updated_at = now()
  where id = p_cart_item_id;

  return public.get_or_create_shop_cart(v_shop_id);
end;
$$;

grant execute on function public.update_shop_cart_item_qty(bigint, integer) to authenticated;

-- =========================================================
-- 9. RPC: remove_shop_cart_item
-- =========================================================
create or replace function public.remove_shop_cart_item(p_cart_item_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart_id bigint;
  v_shop_id bigint;
  v_tenant_id bigint;
begin
  select ci.cart_id, c.shop_id, c.tenant_id
  into v_cart_id, v_shop_id, v_tenant_id
  from public.shop_cart_items ci
  join public.shop_carts c on c.id = ci.cart_id
  where ci.id = p_cart_item_id;

  if v_cart_id is null then
    raise exception 'cart item not found';
  end if;

  -- Access verification
  if not public.is_cart_owner((select customer_group_id from public.shop_carts where id = v_cart_id), v_tenant_id) then
    raise exception 'access denied';
  end if;

  delete from public.shop_cart_items where id = p_cart_item_id;

  return public.get_or_create_shop_cart(v_shop_id);
end;
$$;

grant execute on function public.remove_shop_cart_item(bigint) to authenticated;

-- =========================================================
-- 10. Update existing RPCs to subtract active reservations
-- =========================================================

-- Update list_shop_product_listings
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
    -- Subtract active reservations
    (gsa.quantity - coalesce((select sum(quantity)::integer from public.shop_stock_reservations where global_stock_allocation_id = gsa.id), 0))::integer as available_to_sell
  from public.shop_product_listings l
  join public.products p on p.id = l.product_id
  join public.global_stock_allocations gsa on gsa.id = l.global_stock_allocation_id
  where l.shop_id = p_shop_id
  order by p.name asc;
end;
$$;

grant execute on function public.list_shop_product_listings(bigint) to authenticated;

-- Update browse_shop_catalog to subtract reservations
create or replace function public.browse_shop_catalog(
  p_shop_slug text,
  p_search text default null,
  p_category text default null,
  p_brand text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_shop_id bigint;
  v_tenant_id bigint;
  v_shop_name text;
  v_shop_type public.shop_type_enum;
  v_vendor_code text;
  v_order_mode public.shop_order_mode_enum;
  v_is_negotiable boolean;
  v_show_stock_quantity boolean;
  v_default_currency_id bigint;
  v_is_active boolean;
  
  v_can_browse boolean;
  v_see_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;

  v_limit integer;
  v_offset integer;
  v_result jsonb;
begin
  -- Resolve the shop (slug unique per tenant)
  select 
    id, tenant_id, name, shop_type, vendor_code, order_mode, 
    is_negotiable, show_stock_quantity, default_currency_id, is_active
  into 
    v_shop_id, v_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active
  from public.shops
  where slug = p_shop_slug
    and tenant_id = public.current_tenant_id();

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  -- Resolve effective permissions
  select 
    can_browse, see_price, can_add_to_cart, can_place_order, 
    can_negotiate, can_view_quantity, can_set_dropship_price
  into 
    v_can_browse, v_see_price, v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  if v_shop_type = 'vendor_catalog' then
    execute format(
      $sql$
        with filtered as (
          select p.*
          from public.products p
          where p.vendor_code = $1
            and p.is_available = true
            and (p.tenant_id = $2 or p.parent_tenant_id = $2)
            and ($3 is null or trim($3) = '' or p.name ilike ('%%' || trim($2) || '%%') or p.product_code ilike ('%%' || trim($2) || '%%') or p.barcode ilike ('%%' || trim($2) || '%%'))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.category, '')) = lower(trim($4)))
            and ($5 is null or trim($5) = '' or lower(coalesce(p.brand, '')) = lower(trim($5)))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.name asc, f.id asc
          limit $6
          offset $7
        )
        select jsonb_build_object(
          'data',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'product_id', p.id,
                  'product_name', p.name,
                  'product_image_url', p.image_url,
                  'product_barcode', p.barcode,
                  'product_code', p.product_code,
                  'product_brand', p.brand,
                  'product_category', p.category,
                  'vendor_code', p.vendor_code,
                  'is_available', p.is_available,
                  'unit_price_amount', case when $8 then p.list_price_amount else null end,
                  'unit_price_currency_id', case when $8 then p.list_price_currency_id else null end,
                  'unit_price_currency_code', case when $8 then (select code from public.global_currencies where id = p.list_price_currency_id) else null end,
                  'unit_price_currency_symbol', case when $8 then (select symbol from public.global_currencies where id = p.list_price_currency_id) else null end,
                  'minimum_sell_price_amount', null,
                  'minimum_sell_price_currency_id', null,
                  'minimum_sell_price_currency_code', null,
                  'minimum_sell_price_currency_symbol', null,
                  'available_units', null,
                  'global_stock_allocation_id', null,
                  'global_stock_id', null
                )
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta',
          jsonb_build_object(
            'total', (select count(*) from filtered),
            'page', (($7 / $6) + 1),
            'page_size', $6,
            'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / $6::numeric))
          )
        )
      $sql$
    )
    into v_result
    using 
      v_vendor_code,
      v_tenant_id,
      p_search,
      p_category,
      p_brand,
      v_limit,
      v_offset,
      v_see_price;
  else
    -- fixed_price or dropship
    execute format(
      $sql$
        with filtered as (
          select 
            l.id as listing_id,
            l.global_stock_allocation_id,
            l.global_stock_id,
            l.sell_price_amount,
            l.sell_price_currency_id,
            l.minimum_sell_price_amount,
            l.minimum_sell_price_currency_id,
            l.show_quantity as listing_show_quantity,
            l.display_quantity_override,
            p.id as product_id,
            p.name as product_name,
            p.image_url as product_image_url,
            p.barcode as product_barcode,
            p.product_code as product_code,
            p.brand as product_brand,
            p.category as product_category,
            p.vendor_code as product_vendor_code,
            p.is_available as product_is_available,
            gsa.quantity as allocation_qty,
            (gsa.quantity - coalesce((select sum(quantity) from public.shop_stock_reservations where global_stock_allocation_id = gsa.id), 0)) as available_qty
          from public.shop_product_listings l
          join public.products p on p.id = l.product_id
          join public.global_stock_allocations gsa on gsa.id = l.global_stock_allocation_id
          where l.shop_id = $1
            and l.is_active = true
            and p.is_available = true
            and ($2 is null or trim($2) = '' or p.name ilike ('%%' || trim($2) || '%%') or p.product_code ilike ('%%' || trim($2) || '%%') or p.barcode ilike ('%%' || trim($2) || '%%'))
            and ($3 is null or trim($3) = '' or lower(coalesce(p.category, '')) = lower(trim($3)))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.brand, '')) = lower(trim($4)))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.product_name asc, f.listing_id asc
          limit $5
          offset $6
        )
        select jsonb_build_object(
          'data',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'product_id', p.product_id,
                  'product_name', p.product_name,
                  'product_image_url', p.product_image_url,
                  'product_barcode', p.product_barcode,
                  'product_code', p.product_code,
                  'product_brand', p.product_brand,
                  'product_category', p.product_category,
                  'vendor_code', p.product_vendor_code,
                  'is_available', p.product_is_available,
                  'unit_price_amount', case when $7 then p.sell_price_amount else null end,
                  'unit_price_currency_id', case when $7 then p.sell_price_currency_id else null end,
                  'unit_price_currency_code', case when $7 then (select code from public.global_currencies where id = p.sell_price_currency_id) else null end,
                  'unit_price_currency_symbol', case when $7 then (select symbol from public.global_currencies where id = p.sell_price_currency_id) else null end,
                  'minimum_sell_price_amount', case when $7 and $8 = 'dropship' then p.minimum_sell_price_amount else null end,
                  'minimum_sell_price_currency_id', case when $7 and $8 = 'dropship' then p.minimum_sell_price_currency_id else null end,
                  'minimum_sell_price_currency_code', case when $7 and $8 = 'dropship' then (select code from public.global_currencies where id = p.minimum_sell_price_currency_id) else null end,
                  'minimum_sell_price_currency_symbol', case when $7 and $8 = 'dropship' then (select symbol from public.global_currencies where id = p.minimum_sell_price_currency_id) else null end,
                  'available_units', case 
                    when not $9 or not coalesce(p.listing_show_quantity, $10) then null
                    when p.display_quantity_override is not null then p.display_quantity_override
                    else greatest(0, p.available_qty)
                  end,
                  'global_stock_allocation_id', p.global_stock_allocation_id,
                  'global_stock_id', p.global_stock_id
                )
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta',
          jsonb_build_object(
            'total', (select count(*) from filtered),
            'page', (($6 / $5) + 1),
            'page_size', $5,
            'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / $5::numeric))
          )
        )
      $sql$
    )
    into v_result
    using 
      v_shop_id,
      p_search,
      p_category,
      p_brand,
      v_limit,
      v_offset,
      v_see_price,
      v_shop_type,
      v_can_view_quantity,
      v_show_stock_quantity;
  end if;

  -- Add shop & permissions info to metadata
  v_result := jsonb_set(v_result, '{meta, shop}', jsonb_build_object(
    'id', v_shop_id,
    'name', v_shop_name,
    'slug', p_shop_slug,
    'shop_type', v_shop_type,
    'vendor_code', v_vendor_code,
    'order_mode', v_order_mode,
    'is_negotiable', v_is_negotiable,
    'show_stock_quantity', v_show_stock_quantity,
    'default_currency_id', v_default_currency_id,
    'is_active', v_is_active
  ));

  v_result := jsonb_set(v_result, '{meta, permissions}', jsonb_build_object(
    'can_browse', v_can_browse,
    'see_price', v_see_price,
    'can_add_to_cart', v_can_add_to_cart,
    'can_place_order', v_can_place_order,
    'can_negotiate', v_can_negotiate,
    'can_view_quantity', v_can_view_quantity,
    'can_set_dropship_price', v_can_set_dropship_price
  ));

  return v_result;
end;
$$;

grant execute on function public.browse_shop_catalog(text, text, text, text, integer, integer) to authenticated;

commit;

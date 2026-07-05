-- Migration: Shop Order Phase 7 — Orders & Negotiation
begin;

-- =========================================================
-- 1. Enum types
-- =========================================================
do $$ begin
  if not exists (select 1 from pg_type where typname = 'shop_order_status') then
    create type public.shop_order_status as enum (
      'draft',
      'submitted',
      'cancelled',
      'priced',
      'negotiating',
      'confirmed',
      'placed',
      'fulfilled'
    );
  end if;
end $$;

-- =========================================================
-- 2. Tables
-- =========================================================

-- shop_orders
create table if not exists public.shop_orders (
  id                      bigint generated always as identity primary key,
  tenant_id               bigint not null references public.tenants(id) on delete cascade,
  shop_id                 bigint not null references public.shops(id) on delete cascade,
  customer_group_id       bigint not null references public.customer_groups(id) on delete cascade,
  cart_id                 bigint references public.shop_carts(id) on delete set null,
  
  order_no                text not null,
  name                    text not null,
  
  shop_type_snapshot      public.shop_type_enum not null,
  order_mode_snapshot     public.shop_order_mode_enum not null,
  is_negotiable_snapshot  boolean not null default false,
  
  status                  public.shop_order_status not null default 'submitted',
  negotiate_round         integer not null default 0,
  
  -- costing / rates snapshots
  cargo_rate              numeric(12,4),
  conversion_rate         numeric(12,4),
  profit_rate             numeric(12,4),
  
  recipient_name          text,
  recipient_phone         text,
  shipping_address        text,
  billing_profile_id      bigint references public.billing_profiles(id) on delete set null,
  
  placed_at               timestamptz,
  fulfilled_at            timestamptz,
  global_invoice_id       bigint references public.global_invoices(id) on delete set null,
  created_by_email        text not null,
  
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create unique index if not exists shop_orders_order_no_unique_idx on public.shop_orders(tenant_id, order_no);

-- shop_order_items
create table if not exists public.shop_order_items (
  id                                  bigint generated always as identity primary key,
  order_id                            bigint not null references public.shop_orders(id) on delete cascade,
  product_id                          bigint not null references public.products(id) on delete cascade,
  global_stock_id                     bigint references public.global_stocks(id) on delete set null,
  global_stock_allocation_id          bigint references public.global_stock_allocations(id) on delete set null,
  
  name                                text not null,
  image_url                           text,
  quantity                            integer not null constraint shop_order_items_qty_positive check (quantity > 0),
  
  -- pricing snapshots / offers
  unit_list_price_amount              numeric(12,4),
  unit_list_price_currency_id         bigint references public.global_currencies(id),
  unit_sell_price_amount              numeric(12,4),
  unit_sell_price_currency_id         bigint references public.global_currencies(id),
  unit_minimum_sell_price_amount      numeric(12,4),
  unit_minimum_sell_price_currency_id bigint references public.global_currencies(id),
  customer_sell_price_amount          numeric(12,4),
  customer_sell_price_currency_id     bigint references public.global_currencies(id),
  
  customer_offer_amount               numeric(12,4),
  customer_offer_currency_id          bigint references public.global_currencies(id),
  staff_offer_amount                  numeric(12,4),
  staff_offer_currency_id             bigint references public.global_currencies(id),
  final_price_amount                  numeric(12,4),
  final_price_currency_id             bigint references public.global_currencies(id),
  
  ordered_quantity                    integer not null,
  delivered_quantity                  integer not null default 0,
  returned_quantity                   integer not null default 0,
  
  procurement_pulled                  boolean not null default false,
  
  created_at                          timestamptz not null default now(),
  updated_at                          timestamptz not null default now()
);

-- =========================================================
-- 3. Triggers for updated_at
-- =========================================================
drop trigger if exists trg_shop_orders_updated_at on public.shop_orders;
create trigger trg_shop_orders_updated_at
  before update on public.shop_orders
  for each row execute function public.set_shop_order_updated_at();

drop trigger if exists trg_shop_order_items_updated_at on public.shop_order_items;
create trigger trg_shop_order_items_updated_at
  before update on public.shop_order_items
  for each row execute function public.set_shop_order_updated_at();

-- =========================================================
-- 4. RLS Policies
-- =========================================================
alter table public.shop_orders enable row level security;
alter table public.shop_order_items enable row level security;

-- shop_orders policies
create policy "shop_orders_customer_owner"
  on public.shop_orders for all
  using (public.is_cart_owner(customer_group_id, tenant_id))
  with check (public.is_cart_owner(customer_group_id, tenant_id));

create policy "shop_orders_staff_all"
  on public.shop_orders for all
  using (public.is_tenant_staff(tenant_id))
  with check (public.is_tenant_staff(tenant_id));

-- shop_order_items policies
create policy "shop_order_items_customer_owner"
  on public.shop_order_items for all
  using (
    exists (
      select 1 from public.shop_orders o
      where o.id = order_id
        and public.is_cart_owner(o.customer_group_id, o.tenant_id)
    )
  )
  with check (
    exists (
      select 1 from public.shop_orders o
      where o.id = order_id
        and public.is_cart_owner(o.customer_group_id, o.tenant_id)
    )
  );

create policy "shop_order_items_staff_all"
  on public.shop_order_items for all
  using (
    exists (
      select 1 from public.shop_orders o
      where o.id = order_id
        and public.is_tenant_staff(o.tenant_id)
    )
  )
  with check (
    exists (
      select 1 from public.shop_orders o
      where o.id = order_id
        and public.is_tenant_staff(o.tenant_id)
    )
  );

grant select, insert, update, delete on table public.shop_orders to authenticated;
grant select, insert, update, delete on table public.shop_order_items to authenticated;

-- =========================================================
-- 5. Helper Function: get_pending_order_qty
-- =========================================================
create or replace function public.get_pending_order_qty(p_allocation_id bigint)
returns integer language sql security definer set search_path = public stable as $$
  select coalesce(sum(oi.quantity - oi.delivered_quantity)::integer, 0)
  from public.shop_order_items oi
  join public.shop_orders o on o.id = oi.order_id
  where oi.global_stock_allocation_id = p_allocation_id
    and o.status not in ('cancelled', 'fulfilled');
$$;

-- =========================================================
-- 6. RPC: submit_shop_order_from_cart
-- =========================================================
create or replace function public.submit_shop_order_from_cart(
  p_cart_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_billing_profile_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart public.shop_carts%rowtype;
  v_shop public.shops%rowtype;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_item_count integer;
  v_result jsonb;
begin
  -- 1. Fetch and verify cart
  select * into v_cart from public.shop_carts where id = p_cart_id and status = 'active';
  if v_cart.id is null then
    raise exception 'active cart not found';
  end if;

  -- 2. Verify ownership
  if not public.is_cart_owner(v_cart.customer_group_id, v_cart.tenant_id) then
    raise exception 'access denied';
  end if;

  -- 3. Fetch shop context
  select * into v_shop from public.shops where id = v_cart.shop_id;
  if v_shop.id is null or not v_shop.is_active then
    raise exception 'shop not found or inactive';
  end if;

  -- 4. Verify permission
  select can_place_order, can_negotiate
  into v_can_place_order, v_can_negotiate
  from public.get_shop_permissions_for_customer(v_shop.id);

  if coalesce(v_can_place_order, false) is not true then
    raise exception 'checkout not allowed for this customer group';
  end if;

  -- Verify cart has items
  select count(*) into v_item_count from public.shop_cart_items where cart_id = p_cart_id;
  if v_item_count = 0 then
    raise exception 'cart is empty';
  end if;

  -- 5. Determine order status based on shop_type × order_mode matrix
  if v_shop.shop_type = 'vendor_catalog' then
    if v_shop.order_mode <> 'procurement_intent' then
      raise exception 'invalid order mode for vendor catalog shop';
    end if;
    -- If shop and customer allow negotiation, start as negotiating, else submitted
    if v_shop.is_negotiable and coalesce(v_can_negotiate, false) then
      v_order_status := 'negotiating';
    else
      v_order_status := 'submitted';
    end if;
  else
    -- fixed_price or dropship
    if v_shop.order_mode = 'checkout_fixed' then
      v_order_status := 'confirmed'; -- Auto-confirms fixed price
    else
      v_order_status := 'submitted';
    end if;
  end if;

  -- 6. Generate order number
  v_order_no := 'ORD-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random() * 100000)::text, 5, '0');

  -- 7. Insert order
  insert into public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id,
    order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot,
    status, negotiate_round,
    recipient_name, recipient_phone, shipping_address, billing_profile_id,
    created_by_email
  )
  values (
    v_cart.tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id,
    v_order_no, 'Order for ' || p_recipient_name,
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable,
    v_order_status, case when v_order_status = 'negotiating' then 1 else 0 end,
    p_recipient_name, p_recipient_phone, p_shipping_address, p_billing_profile_id,
    public.current_user_email()
  )
  returning id into v_order_id;

  -- 8. Copy items and set pricing snapshots
  insert into public.shop_order_items (
    order_id, product_id, global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    ordered_quantity
  )
  select
    v_order_id, ci.product_id, ci.global_stock_id, ci.global_stock_allocation_id,
    ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    -- If dropship, customer_sell_price is their offer, otherwise null
    case when v_shop.shop_type = 'dropship' then ci.customer_sell_price_amount else null end,
    case when v_shop.shop_type = 'dropship' then ci.customer_sell_price_currency_id else null end,
    -- If auto-confirmed (fixed price), final price is sell price (or customer dropship price)
    case 
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, ci.unit_list_price_amount)
      else null 
    end,
    case 
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id, ci.unit_list_price_currency_id)
      else null 
    end,
    ci.quantity
  from public.shop_cart_items ci
  where ci.cart_id = p_cart_id;

  -- 9. Delete reservations to free them from cart-holding (replaced by order hold status)
  delete from public.shop_stock_reservations
  where cart_item_id in (select id from public.shop_cart_items where cart_id = p_cart_id);

  -- 10. Update cart status to converted
  update public.shop_carts
  set status = 'converted', updated_at = now()
  where id = p_cart_id;

  -- Build return payload
  select jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_order_status
  ) into v_result;

  return v_result;
end;
$$;

grant execute on function public.submit_shop_order_from_cart(bigint, text, text, text, bigint) to authenticated;

-- =========================================================
-- 7. RPC: staff_price_shop_order
-- =========================================================
create or replace function public.staff_price_shop_order(
  p_order_id bigint,
  p_items jsonb -- Array of objects: { id: bigint, staff_offer_amount: numeric, staff_offer_currency_id: bigint }
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_is_negotiable boolean;
  v_item record;
begin
  select tenant_id, is_negotiable_snapshot into v_tenant_id, v_is_negotiable from public.shop_orders where id = p_order_id;
  
  if v_tenant_id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_tenant_id) then
    raise exception 'access denied';
  end if;

  for v_item in select * from jsonb_to_recordset(p_items) as x(id bigint, staff_offer_amount numeric, staff_offer_currency_id bigint) loop
    update public.shop_order_items
    set
      staff_offer_amount = v_item.staff_offer_amount,
      staff_offer_currency_id = v_item.staff_offer_currency_id,
      final_price_amount = case when not v_is_negotiable then v_item.staff_offer_amount else final_price_amount end,
      final_price_currency_id = case when not v_is_negotiable then v_item.staff_offer_currency_id else final_price_currency_id end
    where id = v_item.id and order_id = p_order_id;
  end loop;

  update public.shop_orders
  set
    status = case when v_is_negotiable then 'negotiating'::public.shop_order_status else 'priced'::public.shop_order_status end,
    updated_at = now()
  where id = p_order_id;
end;
$$;

grant execute on function public.staff_price_shop_order(bigint, jsonb) to authenticated;

-- =========================================================
-- 8. RPC: customer_counter_offer
-- =========================================================
create or replace function public.customer_counter_offer(
  p_order_id bigint,
  p_items jsonb -- Array: { id: bigint, customer_offer_amount: numeric, customer_offer_currency_id: bigint }
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_cust_group_id bigint;
  v_item record;
begin
  select tenant_id, customer_group_id into v_tenant_id, v_cust_group_id from public.shop_orders where id = p_order_id;
  
  if v_tenant_id is null then
    raise exception 'order not found';
  end if;

  if not public.is_cart_owner(v_cust_group_id, v_tenant_id) then
    raise exception 'access denied';
  end if;

  for v_item in select * from jsonb_to_recordset(p_items) as x(id bigint, customer_offer_amount numeric, customer_offer_currency_id bigint) loop
    update public.shop_order_items
    set
      customer_offer_amount = v_item.customer_offer_amount,
      customer_offer_currency_id = v_item.customer_offer_currency_id
    where id = v_item.id and order_id = p_order_id;
  end loop;

  update public.shop_orders
  set
    status = 'negotiating',
    negotiate_round = negotiate_round + 1,
    updated_at = now()
  where id = p_order_id;
end;
$$;

grant execute on function public.customer_counter_offer(bigint, jsonb) to authenticated;

-- =========================================================
-- 9. RPC: staff_counter_offer
-- =========================================================
create or replace function public.staff_counter_offer(
  p_order_id bigint,
  p_items jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_item record;
begin
  select tenant_id into v_tenant_id from public.shop_orders where id = p_order_id;
  
  if v_tenant_id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_tenant_id) then
    raise exception 'access denied';
  end if;

  for v_item in select * from jsonb_to_recordset(p_items) as x(id bigint, staff_offer_amount numeric, staff_offer_currency_id bigint) loop
    update public.shop_order_items
    set
      staff_offer_amount = v_item.staff_offer_amount,
      staff_offer_currency_id = v_item.staff_offer_currency_id
    where id = v_item.id and order_id = p_order_id;
  end loop;

  update public.shop_orders
  set
    status = 'negotiating',
    updated_at = now()
  where id = p_order_id;
end;
$$;

grant execute on function public.staff_counter_offer(bigint, jsonb) to authenticated;

-- =========================================================
-- 10. RPC: confirm_shop_order
-- =========================================================
create or replace function public.confirm_shop_order(p_order_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_is_negotiable boolean;
begin
  select tenant_id, is_negotiable_snapshot into v_tenant_id, v_is_negotiable from public.shop_orders where id = p_order_id;
  
  if v_tenant_id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_tenant_id) then
    raise exception 'access denied';
  end if;

  -- Finalize pricing: set final price to staff offer or customer offer
  update public.shop_order_items
  set
    final_price_amount = coalesce(staff_offer_amount, customer_offer_amount, unit_sell_price_amount, unit_list_price_amount),
    final_price_currency_id = coalesce(staff_offer_currency_id, customer_offer_currency_id, unit_sell_price_currency_id, unit_list_price_currency_id)
  where order_id = p_order_id;

  update public.shop_orders
  set
    status = 'confirmed',
    updated_at = now()
  where id = p_order_id;
end;
$$;

grant execute on function public.confirm_shop_order(bigint) to authenticated;

-- =========================================================
-- 11. RPC: list_shop_orders_for_customer
-- =========================================================
create or replace function public.list_shop_orders_for_customer(
  p_shop_id bigint,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id bigint,
  tenant_id bigint,
  shop_id bigint,
  customer_group_id bigint,
  order_no text,
  name text,
  status public.shop_order_status,
  created_at timestamptz,
  updated_at timestamptz,
  item_count bigint,
  total_amount numeric
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_tenant_id bigint;
  v_cust_group_id bigint;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  
  -- Find group that belongs to the user and has permissions
  select cg.id
  into v_cust_group_id
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where cg.tenant_id = v_tenant_id
    and lower(trim(cgm.email)) = public.current_user_email()
    and cgm.is_active = true
    and cg.is_active = true
  limit 1;

  if v_cust_group_id is null then
    return;
  end if;

  return query
  select
    o.id,
    o.tenant_id,
    o.shop_id,
    o.customer_group_id,
    o.order_no,
    o.name,
    o.status,
    o.created_at,
    o.updated_at,
    (select count(*)::bigint from public.shop_order_items where order_id = o.id) as item_count,
    coalesce(
      (
        select sum(coalesce(final_price_amount, customer_offer_amount, unit_sell_price_amount, unit_list_price_amount) * quantity)
        from public.shop_order_items
        where order_id = o.id
      ),
      0
    )::numeric as total_amount
  from public.shop_orders o
  where o.shop_id = p_shop_id
    and o.customer_group_id = v_cust_group_id
  order by o.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;

grant execute on function public.list_shop_orders_for_customer(bigint, integer, integer) to authenticated;

-- =========================================================
-- 12. RPC: list_shop_orders_for_staff
-- =========================================================
create or replace function public.list_shop_orders_for_staff(
  p_tenant_id bigint,
  p_limit integer default 20,
  p_offset integer default 0,
  p_search text default null,
  p_status text default null
)
returns table (
  id bigint,
  tenant_id bigint,
  shop_id bigint,
  shop_name text,
  customer_group_id bigint,
  customer_group_name text,
  order_no text,
  name text,
  status public.shop_order_status,
  created_at timestamptz,
  updated_at timestamptz,
  item_count bigint,
  total_amount numeric
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  return query
  select
    o.id,
    o.tenant_id,
    o.shop_id,
    s.name as shop_name,
    o.customer_group_id,
    cg.name as customer_group_name,
    o.order_no,
    o.name,
    o.status,
    o.created_at,
    o.updated_at,
    (select count(*)::bigint from public.shop_order_items where order_id = o.id) as item_count,
    coalesce(
      (
        select sum(coalesce(final_price_amount, staff_offer_amount, customer_offer_amount, unit_sell_price_amount, unit_list_price_amount) * quantity)
        from public.shop_order_items
        where order_id = o.id
      ),
      0
    )::numeric as total_amount
  from public.shop_orders o
  join public.shops s on s.id = o.shop_id
  join public.customer_groups cg on cg.id = o.customer_group_id
  where o.tenant_id = p_tenant_id
    and (p_status is null or o.status::text = p_status)
    and (
      p_search is null 
      or o.order_no ilike ('%' || p_search || '%')
      or o.name ilike ('%' || p_search || '%')
      or s.name ilike ('%' || p_search || '%')
      or cg.name ilike ('%' || p_search || '%')
    )
  order by o.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;

grant execute on function public.list_shop_orders_for_staff(bigint, integer, integer, text, text) to authenticated;

-- =========================================================
-- 13. Update quantity computations to subtract pending orders
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
    -- Subtract active reservations + pending orders
    (gsa.quantity 
     - coalesce((select sum(quantity)::integer from public.shop_stock_reservations where global_stock_allocation_id = gsa.id), 0)
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

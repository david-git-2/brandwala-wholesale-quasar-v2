-- ============================================================
-- koba_carts + koba_cart_items + koba_orders + koba_order_items
-- Mirrors the brand-wala retail cart/order design.
-- Scoped to koba_products (uuid PK) and tenant-isolated via tenant_id.
-- ============================================================

begin;

-- ============================================================
-- SECTION 1 — CART TABLES
-- ============================================================

create table if not exists public.koba_carts (
  id          bigserial primary key,
  tenant_id   bigint      not null references public.tenants(id) on delete cascade,
  -- Cart is owned by a single user (identified by email, matching memberships pattern)
  user_email  text        not null,
  -- Optional market context (e.g. "GB", "BD") – matches brand-wala retail selectedMarketId
  market_id   text        null,
  status      text        not null default 'active'
    check (status in ('active', 'ordered', 'cleared')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  -- One active cart per user per market per tenant
  constraint uq_koba_carts_user_market unique (tenant_id, user_email, market_id)
);

create index if not exists koba_carts_tenant_idx     on public.koba_carts(tenant_id);
create index if not exists koba_carts_user_email_idx on public.koba_carts(user_email);
create index if not exists koba_carts_market_id_idx  on public.koba_carts(market_id);

drop trigger if exists trg_koba_carts_updated_at on public.koba_carts;
create trigger trg_koba_carts_updated_at
  before update on public.koba_carts
  for each row execute function public.set_updated_at();

-- ─── Cart Items ──────────────────────────────────────────────────────────────

create table if not exists public.koba_cart_items (
  id                    bigserial   primary key,
  cart_id               bigint      not null references public.koba_carts(id) on delete cascade,
  -- Snapshot of koba_products at add-time (UUID)
  koba_product_id       uuid        null references public.koba_products(id) on delete set null,

  -- Denormalised product snapshot (so cart survives product edits / deletes)
  product_id            text        not null,   -- source_id from koba_products
  product_code          text        null,
  barcode               text        null,
  name                  text        not null,
  brand                 text        null,
  image_url             text        null,
  case_size             integer     not null default 1 check (case_size >= 1),

  -- Pricing snapshot (GBP)
  unit_price_gbp        numeric(12, 2) null,
  commission            numeric(12, 2) null,
  commission_percentage numeric(5,  2) null,

  quantity              integer     not null default 1 check (quantity > 0),

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  -- One row per product per cart
  constraint uq_koba_cart_items_product unique (cart_id, product_id)
);

create index if not exists koba_cart_items_cart_id_idx on public.koba_cart_items(cart_id);
create index if not exists koba_cart_items_product_id_idx on public.koba_cart_items(product_id);

drop trigger if exists trg_koba_cart_items_updated_at on public.koba_cart_items;
create trigger trg_koba_cart_items_updated_at
  before update on public.koba_cart_items
  for each row execute function public.set_updated_at();

-- ============================================================
-- SECTION 2 — ORDER TABLES
-- ============================================================

-- Order status progression:
--   pending → confirmed → processing → shipped → delivered
--              (admin)    (admin)      (admin)   (admin)
-- Customer places order → 'pending'; admin progresses it.

do $$ begin
  if not exists (
    select 1 from pg_type where typname = 'koba_order_status'
  ) then
    create type public.koba_order_status as enum (
      'pending',      -- placed by customer, awaiting confirmation
      'confirmed',    -- accepted by admin
      'processing',   -- being packed / prepared
      'shipped',      -- dispatched
      'delivered',    -- received by customer
      'cancelled'     -- rejected or cancelled
    );
  end if;
end $$;

create table if not exists public.koba_orders (
  id          bigserial              primary key,
  tenant_id   bigint                 not null references public.tenants(id) on delete cascade,

  -- Who placed the order
  user_email  text                   not null,
  user_name   text                   null,
  market_id   text                   null,   -- "GB", "BD", etc.

  -- Shipping destination (from brand-wala retail checkout)
  shipping_name     text             null,
  shipping_phone    text             null,
  shipping_district text             null,
  shipping_thana    text             null,
  shipping_address  text             null,
  free_delivery     boolean          not null default false,

  -- Order-level totals (calculated at order creation)
  subtotal_gbp      numeric(12, 2)   null,   -- sum(unit_price_gbp * quantity)
  total_commission  numeric(12, 2)   null,   -- sum(commission * quantity)
  item_count        integer          not null default 0,

  status      public.koba_order_status not null default 'pending',

  -- Optional admin notes
  note        text                   null,

  created_at  timestamptz            not null default now(),
  updated_at  timestamptz            not null default now()
);

create index if not exists koba_orders_tenant_idx     on public.koba_orders(tenant_id);
create index if not exists koba_orders_user_email_idx on public.koba_orders(user_email);
create index if not exists koba_orders_status_idx     on public.koba_orders(status);
create index if not exists koba_orders_market_id_idx  on public.koba_orders(market_id);

drop trigger if exists trg_koba_orders_updated_at on public.koba_orders;
create trigger trg_koba_orders_updated_at
  before update on public.koba_orders
  for each row execute function public.set_updated_at();

-- ─── Order Items ─────────────────────────────────────────────────────────────

create table if not exists public.koba_order_items (
  id                    bigserial   primary key,
  order_id              bigint      not null references public.koba_orders(id) on delete cascade,

  -- Product snapshot (immutable after order is placed)
  product_id            text        not null,
  product_code          text        null,
  barcode               text        null,
  name                  text        not null,
  brand                 text        null,
  image_url             text        null,
  case_size             integer     not null default 1 check (case_size >= 1),

  -- Price at time of order
  unit_price_gbp        numeric(12, 2) null,
  commission            numeric(12, 2) null,
  commission_percentage numeric(5,  2) null,

  -- Quantities
  quantity              integer     not null default 1 check (quantity > 0),
  delivered_quantity    integer     not null default 0 check (delivered_quantity >= 0),

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists koba_order_items_order_id_idx   on public.koba_order_items(order_id);
create index if not exists koba_order_items_product_id_idx on public.koba_order_items(product_id);

drop trigger if exists trg_koba_order_items_updated_at on public.koba_order_items;
create trigger trg_koba_order_items_updated_at
  before update on public.koba_order_items
  for each row execute function public.set_updated_at();

-- ============================================================
-- SECTION 3 — RLS
-- ============================================================

alter table public.koba_carts       enable row level security;
alter table public.koba_cart_items  enable row level security;
alter table public.koba_orders      enable row level security;
alter table public.koba_order_items enable row level security;

-- Helper: user owns this cart row
create or replace function public.koba_cart_owner(p_cart_id bigint)
returns boolean
language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from public.koba_carts c
    where c.id = p_cart_id
      and lower(trim(c.user_email)) = public.current_user_email()
  ) or public.is_superadmin();
$$;

-- Helper: user owns the order row
create or replace function public.koba_order_owner(p_order_id bigint)
returns boolean
language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from public.koba_orders o
    where o.id = p_order_id
      and lower(trim(o.user_email)) = public.current_user_email()
  )
  or public.is_superadmin()
  or public.is_tenant_admin((
    select tenant_id from public.koba_orders where id = p_order_id
  ));
$$;

-- ── koba_carts ───────────────────────────────────────────────────────────────

drop policy if exists koba_carts_select on public.koba_carts;
create policy koba_carts_select on public.koba_carts for select to authenticated
  using (
    lower(trim(user_email)) = public.current_user_email()
    or public.is_superadmin()
    or public.is_tenant_admin(tenant_id)
  );

drop policy if exists koba_carts_insert on public.koba_carts;
create policy koba_carts_insert on public.koba_carts for insert to authenticated
  with check (
    lower(trim(user_email)) = public.current_user_email()
    or public.is_superadmin()
  );

drop policy if exists koba_carts_update on public.koba_carts;
create policy koba_carts_update on public.koba_carts for update to authenticated
  using (lower(trim(user_email)) = public.current_user_email() or public.is_superadmin())
  with check (lower(trim(user_email)) = public.current_user_email() or public.is_superadmin());

drop policy if exists koba_carts_delete on public.koba_carts;
create policy koba_carts_delete on public.koba_carts for delete to authenticated
  using (lower(trim(user_email)) = public.current_user_email() or public.is_superadmin());

-- ── koba_cart_items ──────────────────────────────────────────────────────────

drop policy if exists koba_cart_items_select on public.koba_cart_items;
create policy koba_cart_items_select on public.koba_cart_items for select to authenticated
  using (public.koba_cart_owner(cart_id));

drop policy if exists koba_cart_items_insert on public.koba_cart_items;
create policy koba_cart_items_insert on public.koba_cart_items for insert to authenticated
  with check (public.koba_cart_owner(cart_id));

drop policy if exists koba_cart_items_update on public.koba_cart_items;
create policy koba_cart_items_update on public.koba_cart_items for update to authenticated
  using (public.koba_cart_owner(cart_id))
  with check (public.koba_cart_owner(cart_id));

drop policy if exists koba_cart_items_delete on public.koba_cart_items;
create policy koba_cart_items_delete on public.koba_cart_items for delete to authenticated
  using (public.koba_cart_owner(cart_id));

-- ── koba_orders ──────────────────────────────────────────────────────────────

drop policy if exists koba_orders_select on public.koba_orders;
create policy koba_orders_select on public.koba_orders for select to authenticated
  using (public.koba_order_owner(id));

drop policy if exists koba_orders_insert on public.koba_orders;
create policy koba_orders_insert on public.koba_orders for insert to authenticated
  with check (
    lower(trim(user_email)) = public.current_user_email()
    or public.is_superadmin()
  );

drop policy if exists koba_orders_update on public.koba_orders;
create policy koba_orders_update on public.koba_orders for update to authenticated
  using (public.koba_order_owner(id))
  with check (public.koba_order_owner(id));

drop policy if exists koba_orders_delete on public.koba_orders;
create policy koba_orders_delete on public.koba_orders for delete to authenticated
  using (public.is_superadmin() or public.is_tenant_admin(tenant_id));

-- ── koba_order_items ─────────────────────────────────────────────────────────

drop policy if exists koba_order_items_select on public.koba_order_items;
create policy koba_order_items_select on public.koba_order_items for select to authenticated
  using (public.koba_order_owner(order_id));

drop policy if exists koba_order_items_insert on public.koba_order_items;
create policy koba_order_items_insert on public.koba_order_items for insert to authenticated
  with check (public.koba_order_owner(order_id));

drop policy if exists koba_order_items_update on public.koba_order_items;
create policy koba_order_items_update on public.koba_order_items for update to authenticated
  using (public.koba_order_owner(order_id))
  with check (public.koba_order_owner(order_id));

drop policy if exists koba_order_items_delete on public.koba_order_items;
create policy koba_order_items_delete on public.koba_order_items for delete to authenticated
  using (public.is_superadmin() or public.is_tenant_admin((
    select tenant_id from public.koba_orders where id = order_id
  )));

-- ============================================================
-- SECTION 4 — GRANTS
-- ============================================================

grant select, insert, update, delete on table public.koba_carts       to authenticated, service_role;
grant select, insert, update, delete on table public.koba_cart_items  to authenticated, service_role;
grant select, insert, update, delete on table public.koba_orders      to authenticated, service_role;
grant select, insert, update, delete on table public.koba_order_items to authenticated, service_role;

grant usage, select on sequence public.koba_carts_id_seq       to authenticated, service_role;
grant usage, select on sequence public.koba_cart_items_id_seq  to authenticated, service_role;
grant usage, select on sequence public.koba_orders_id_seq      to authenticated, service_role;
grant usage, select on sequence public.koba_order_items_id_seq to authenticated, service_role;

-- ============================================================
-- SECTION 5 — RPC: place_koba_order
-- Creates an order from the caller's active cart, then marks the cart 'ordered'.
-- ============================================================

drop function if exists public.place_koba_order(bigint, text, text, text, text, text, text, boolean);

create function public.place_koba_order(
  p_tenant_id       bigint,
  p_market_id       text    default null,
  p_shipping_name     text  default null,
  p_shipping_phone    text  default null,
  p_shipping_district text  default null,
  p_shipping_thana    text  default null,
  p_shipping_address  text  default null,
  p_free_delivery     boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email      text;
  v_cart_id    bigint;
  v_order_id   bigint;
  v_subtotal   numeric(12,2) := 0;
  v_commission numeric(12,2) := 0;
  v_count      integer       := 0;
begin
  v_email := public.current_user_email();
  if v_email is null or v_email = '' then
    raise exception 'not authenticated';
  end if;

  -- Resolve the active cart
  select id into v_cart_id
  from public.koba_carts
  where tenant_id  = p_tenant_id
    and lower(trim(user_email)) = v_email
    and market_id = p_market_id
    and status    = 'active'
  limit 1;

  if v_cart_id is null then
    raise exception 'no active cart found for this user';
  end if;

  -- Ensure cart has items
  select count(*) into v_count
  from public.koba_cart_items where cart_id = v_cart_id;

  if v_count = 0 then
    raise exception 'cart is empty';
  end if;

  -- Compute totals
  select
    coalesce(sum(coalesce(unit_price_gbp, 0) * quantity), 0),
    coalesce(sum(coalesce(commission,     0) * quantity), 0),
    count(*)
  into v_subtotal, v_commission, v_count
  from public.koba_cart_items
  where cart_id = v_cart_id;

  -- Create order header
  insert into public.koba_orders (
    tenant_id, user_email, market_id,
    shipping_name, shipping_phone, shipping_district,
    shipping_thana, shipping_address, free_delivery,
    subtotal_gbp, total_commission, item_count, status
  ) values (
    p_tenant_id, v_email, p_market_id,
    p_shipping_name, p_shipping_phone, p_shipping_district,
    p_shipping_thana, p_shipping_address, p_free_delivery,
    v_subtotal, v_commission, v_count, 'pending'
  )
  returning id into v_order_id;

  -- Copy cart items → order items
  insert into public.koba_order_items (
    order_id, product_id, product_code, barcode, name, brand, image_url,
    case_size, unit_price_gbp, commission, commission_percentage, quantity
  )
  select
    v_order_id, product_id, product_code, barcode, name, brand, image_url,
    case_size, unit_price_gbp, commission, commission_percentage, quantity
  from public.koba_cart_items
  where cart_id = v_cart_id;

  -- Mark cart as ordered (keep rows for history)
  update public.koba_carts
  set status = 'ordered'
  where id = v_cart_id;

  return jsonb_build_object(
    'order_id',    v_order_id,
    'item_count',  v_count,
    'subtotal_gbp', v_subtotal,
    'total_commission', v_commission,
    'status', 'pending'
  );
end;
$$;

grant execute on function public.place_koba_order(bigint, text, text, text, text, text, text, boolean)
  to authenticated, service_role;

-- ============================================================
-- SECTION 6 — RPC: get_koba_cart
-- Returns the active cart and all items for the current user.
-- ============================================================

drop function if exists public.get_koba_cart(bigint, text);

create function public.get_koba_cart(
  p_tenant_id bigint,
  p_market_id text default null
)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select jsonb_build_object(
    'cart',
    to_jsonb(c) - 'user_email',
    'items',
    coalesce(
      (
        select jsonb_agg(to_jsonb(ci) order by ci.id)
        from public.koba_cart_items ci
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    )
  )
  from public.koba_carts c
  where c.tenant_id  = p_tenant_id
    and lower(trim(c.user_email)) = public.current_user_email()
    and c.market_id  = p_market_id
    and c.status     = 'active'
  limit 1;
$$;

grant execute on function public.get_koba_cart(bigint, text)
  to authenticated, service_role;

-- ============================================================
-- SECTION 7 — RPC: list_koba_orders
-- Returns paginated orders for the current user (or all for admin).
-- ============================================================

drop function if exists public.list_koba_orders(bigint, text, integer, integer, text);

create function public.list_koba_orders(
  p_tenant_id  bigint,
  p_market_id  text    default null,
  p_page       integer default 1,
  p_page_size  integer default 20,
  p_status     text    default null
)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  with filtered as (
    select
      o.*,
      count(*) over() as total_count
    from public.koba_orders o
    where o.tenant_id = p_tenant_id
      and (
        lower(trim(o.user_email)) = public.current_user_email()
        or public.is_superadmin()
        or public.is_tenant_admin(p_tenant_id)
      )
      and (p_market_id is null or o.market_id = p_market_id)
      and (p_status    is null or o.status::text = p_status)
  ),
  paged as (
    select * from filtered
    order by created_at desc, id desc
    offset (greatest(coalesce(p_page, 1), 1) - 1) * greatest(coalesce(p_page_size, 20), 1)
    limit  greatest(coalesce(p_page_size, 20), 1)
  )
  select jsonb_build_object(
    'data',
    coalesce(jsonb_agg(to_jsonb(paged) - 'total_count'), '[]'::jsonb),
    'meta',
    jsonb_build_object(
      'total',       coalesce(max(paged.total_count), 0),
      'page',        greatest(coalesce(p_page, 1), 1),
      'page_size',   greatest(coalesce(p_page_size, 20), 1),
      'total_pages',
        case when coalesce(max(paged.total_count), 0) = 0 then 1
             else ceil(coalesce(max(paged.total_count), 0)::numeric
                       / greatest(coalesce(p_page_size, 20), 1))::int
        end
    )
  )
  from paged;
$$;

grant execute on function public.list_koba_orders(bigint, text, integer, integer, text)
  to authenticated, service_role;

-- ============================================================
-- TABLE COMMENTS
-- ============================================================

comment on table public.koba_carts       is 'Active shopping carts for Koba retail, one per user+market+tenant.';
comment on table public.koba_cart_items  is 'Line items in a koba cart. Stores full product snapshot for cart resilience.';
comment on table public.koba_orders      is 'Confirmed koba retail orders. Created from koba_carts via place_koba_order().';
comment on table public.koba_order_items is 'Immutable line-item snapshot of a koba order.';

commit;

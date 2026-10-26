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
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'koba_carts' and column_name = 'user_email'
  ) then
    execute 'create index if not exists koba_carts_user_email_idx on public.koba_carts(user_email)';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'koba_carts' and column_name = 'market_id'
  ) then
    execute 'create index if not exists koba_carts_market_id_idx on public.koba_carts(market_id)';
  end if;
end $$;

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
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'koba_orders' and column_name = 'user_email'
  ) then
    execute 'create index if not exists koba_orders_user_email_idx on public.koba_orders(user_email)';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'koba_orders' and column_name = 'market_id'
  ) then
    execute 'create index if not exists koba_orders_market_id_idx on public.koba_orders(market_id)';
  end if;
end $$;
create index if not exists koba_orders_status_idx     on public.koba_orders(status);

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
-- SECTION 3–5 — Legacy user_email RLS / RPCs
-- Skipped when carts already use customer_group_id (scaffold + …132249/…133817).
-- Those earlier migrations own the modern policies and RPCs.
-- ============================================================

do $legacy$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'koba_carts'
      and column_name = 'user_email'
  ) then
    raise notice 'koba_carts has no user_email — skipping legacy RLS/RPCs in 200000';
    return;
  end if;

  -- Legacy path: tables still have user_email (greenfield without prior migrate).
  -- Re-apply minimal ownership helpers + email-scoped policies from the original migration.
  execute $sql$
    alter table public.koba_carts       enable row level security;
    alter table public.koba_cart_items  enable row level security;
    alter table public.koba_orders      enable row level security;
    alter table public.koba_order_items enable row level security
  $sql$;

  execute $sql$
    create or replace function public.koba_cart_owner(p_cart_id bigint)
    returns boolean
    language sql security definer set search_path = public stable as $fn$
      select exists (
        select 1 from public.koba_carts c
        where c.id = p_cart_id
          and lower(trim(c.user_email)) = public.current_user_email()
      ) or public.is_superadmin();
    $fn$
  $sql$;

  execute $sql$
    create or replace function public.koba_order_owner(p_order_id bigint)
    returns boolean
    language sql security definer set search_path = public stable as $fn$
      select exists (
        select 1 from public.koba_orders o
        where o.id = p_order_id
          and lower(trim(o.user_email)) = public.current_user_email()
      )
      or public.is_superadmin()
      or public.is_tenant_admin((
        select tenant_id from public.koba_orders where id = p_order_id
      ));
    $fn$
  $sql$;

  -- Policies (drop + create)
  execute 'drop policy if exists koba_carts_select on public.koba_carts';
  execute $sql$
    create policy koba_carts_select on public.koba_carts for select to authenticated
      using (
        lower(trim(user_email)) = public.current_user_email()
        or public.is_superadmin()
        or public.is_tenant_admin(tenant_id)
      )
  $sql$;
  execute 'drop policy if exists koba_carts_insert on public.koba_carts';
  execute $sql$
    create policy koba_carts_insert on public.koba_carts for insert to authenticated
      with check (
        lower(trim(user_email)) = public.current_user_email()
        or public.is_superadmin()
      )
  $sql$;
  execute 'drop policy if exists koba_carts_update on public.koba_carts';
  execute $sql$
    create policy koba_carts_update on public.koba_carts for update to authenticated
      using (lower(trim(user_email)) = public.current_user_email() or public.is_superadmin())
      with check (lower(trim(user_email)) = public.current_user_email() or public.is_superadmin())
  $sql$;
  execute 'drop policy if exists koba_carts_delete on public.koba_carts';
  execute $sql$
    create policy koba_carts_delete on public.koba_carts for delete to authenticated
      using (lower(trim(user_email)) = public.current_user_email() or public.is_superadmin())
  $sql$;

  execute 'drop policy if exists koba_cart_items_select on public.koba_cart_items';
  execute $sql$
    create policy koba_cart_items_select on public.koba_cart_items for select to authenticated
      using (public.koba_cart_owner(cart_id))
  $sql$;
  execute 'drop policy if exists koba_cart_items_insert on public.koba_cart_items';
  execute $sql$
    create policy koba_cart_items_insert on public.koba_cart_items for insert to authenticated
      with check (public.koba_cart_owner(cart_id))
  $sql$;
  execute 'drop policy if exists koba_cart_items_update on public.koba_cart_items';
  execute $sql$
    create policy koba_cart_items_update on public.koba_cart_items for update to authenticated
      using (public.koba_cart_owner(cart_id))
      with check (public.koba_cart_owner(cart_id))
  $sql$;
  execute 'drop policy if exists koba_cart_items_delete on public.koba_cart_items';
  execute $sql$
    create policy koba_cart_items_delete on public.koba_cart_items for delete to authenticated
      using (public.koba_cart_owner(cart_id))
  $sql$;

  execute 'drop policy if exists koba_orders_select on public.koba_orders';
  execute $sql$
    create policy koba_orders_select on public.koba_orders for select to authenticated
      using (public.koba_order_owner(id))
  $sql$;
  execute 'drop policy if exists koba_orders_insert on public.koba_orders';
  execute $sql$
    create policy koba_orders_insert on public.koba_orders for insert to authenticated
      with check (
        lower(trim(user_email)) = public.current_user_email()
        or public.is_superadmin()
      )
  $sql$;
  execute 'drop policy if exists koba_orders_update on public.koba_orders';
  execute $sql$
    create policy koba_orders_update on public.koba_orders for update to authenticated
      using (public.koba_order_owner(id))
      with check (public.koba_order_owner(id))
  $sql$;
  execute 'drop policy if exists koba_orders_delete on public.koba_orders';
  execute $sql$
    create policy koba_orders_delete on public.koba_orders for delete to authenticated
      using (public.is_superadmin() or public.is_tenant_admin(tenant_id))
  $sql$;

  execute 'drop policy if exists koba_order_items_select on public.koba_order_items';
  execute $sql$
    create policy koba_order_items_select on public.koba_order_items for select to authenticated
      using (public.koba_order_owner(order_id))
  $sql$;
  execute 'drop policy if exists koba_order_items_insert on public.koba_order_items';
  execute $sql$
    create policy koba_order_items_insert on public.koba_order_items for insert to authenticated
      with check (public.koba_order_owner(order_id))
  $sql$;
  execute 'drop policy if exists koba_order_items_update on public.koba_order_items';
  execute $sql$
    create policy koba_order_items_update on public.koba_order_items for update to authenticated
      using (public.koba_order_owner(order_id))
      with check (public.koba_order_owner(order_id))
  $sql$;
  execute 'drop policy if exists koba_order_items_delete on public.koba_order_items';
  execute $sql$
    create policy koba_order_items_delete on public.koba_order_items for delete to authenticated
      using (public.is_superadmin() or public.is_tenant_admin((
        select tenant_id from public.koba_orders where id = order_id
      )))
  $sql$;
end;
$legacy$;

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

-- Legacy place_koba_order / get_koba_cart / list_koba_orders (user_email shape) intentionally
-- omitted when customer_group migrations already defined modern RPCs (…133817+).


-- ============================================================
-- TABLE COMMENTS
-- ============================================================

comment on table public.koba_carts       is 'Active shopping carts for Koba retail, one per user+market+tenant.';
comment on table public.koba_cart_items  is 'Line items in a koba cart. Stores full product snapshot for cart resilience.';
comment on table public.koba_orders      is 'Confirmed koba retail orders. Created from koba_carts via place_koba_order().';
comment on table public.koba_order_items is 'Immutable line-item snapshot of a koba order.';

commit;

-- Early scaffold so koba cart/order ALTER migrations (…132249 / …133817 / …)
-- can run before …200000 on a fresh local reset.
-- Creates the post–customer_group shape so …200000 legacy user_email indexes/RLS are skipped.
-- Safe on production: IF NOT EXISTS / idempotent.

do $$ begin
  if not exists (
    select 1 from pg_type where typname = 'koba_order_status'
  ) then
    create type public.koba_order_status as enum (
      'pending',
      'confirmed',
      'processing',
      'shipped',
      'delivered',
      'cancelled'
    );
  end if;
end $$;

create table if not exists public.koba_carts (
  id                 bigserial primary key,
  tenant_id          bigint not null references public.tenants(id) on delete cascade,
  customer_group_id  bigint null references public.customer_groups(id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create index if not exists koba_carts_tenant_idx on public.koba_carts(tenant_id);
create index if not exists koba_carts_customer_group_id_idx
  on public.koba_carts using btree (customer_group_id);

create table if not exists public.koba_cart_items (
  id                    bigserial   primary key,
  cart_id               bigint      not null references public.koba_carts(id) on delete cascade,
  koba_product_id       uuid        null,
  product_id            text        not null,
  product_code          text        null,
  barcode               text        null,
  name                  text        not null,
  brand                 text        null,
  image_url             text        null,
  case_size             integer     not null default 1 check (case_size >= 1),
  unit_price_gbp        numeric(12, 2) null,
  commission            numeric(12, 2) null,
  commission_percentage numeric(5,  2) null,
  quantity              integer     not null default 1 check (quantity > 0),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint uq_koba_cart_items_product unique (cart_id, product_id)
);

create index if not exists koba_cart_items_cart_id_idx on public.koba_cart_items(cart_id);
create index if not exists koba_cart_items_product_id_idx on public.koba_cart_items(product_id);

create table if not exists public.koba_orders (
  id          bigserial              primary key,
  tenant_id   bigint                 not null references public.tenants(id) on delete cascade,
  customer_group_id bigint null references public.customer_groups(id) on delete set null,
  user_name   text                   null,
  shipping_name     text             null,
  shipping_phone    text             null,
  shipping_district text             null,
  shipping_thana    text             null,
  shipping_address  text             null,
  free_delivery     boolean          not null default false,
  subtotal_gbp      numeric(12, 2)   null,
  total_commission  numeric(12, 2)   null,
  item_count        integer          not null default 0,
  status      public.koba_order_status not null default 'pending',
  note        text                   null,
  created_at  timestamptz            not null default now(),
  updated_at  timestamptz            not null default now()
);

create index if not exists koba_orders_tenant_idx on public.koba_orders(tenant_id);
create index if not exists koba_orders_customer_group_id_idx on public.koba_orders(customer_group_id);
create index if not exists koba_orders_status_idx on public.koba_orders(status);

create table if not exists public.koba_order_items (
  id                    bigserial   primary key,
  order_id              bigint      not null references public.koba_orders(id) on delete cascade,
  product_id            text        not null,
  product_code          text        null,
  barcode               text        null,
  name                  text        not null,
  brand                 text        null,
  image_url             text        null,
  case_size             integer     not null default 1 check (case_size >= 1),
  unit_price_gbp        numeric(12, 2) null,
  commission            numeric(12, 2) null,
  commission_percentage numeric(5,  2) null,
  quantity              integer     not null default 1 check (quantity > 0),
  delivered_quantity    integer     not null default 0 check (delivered_quantity >= 0),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists koba_order_items_order_id_idx   on public.koba_order_items(order_id);
create index if not exists koba_order_items_product_id_idx on public.koba_order_items(product_id);

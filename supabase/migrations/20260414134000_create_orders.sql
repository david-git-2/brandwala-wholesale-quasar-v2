begin;

-- =========================================================
-- STATUS ENUM
-- =========================================================

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'order_status'
  ) then
    create type public.order_status as enum (
      'customer_submit',
      'priced',
      'negotiate',
      'ordered',
      'placed'
    );
  end if;
end
$$;

-- =========================================================
-- ORDERS
-- =========================================================

create table if not exists public.orders (
  id bigserial primary key,
  name text not null,
  customer_group_id bigint not null,
  cargo_rate numeric(12, 4) null,
  conversion_rate numeric(12, 4) null,
  profit_rate numeric(12, 4) null,
  negotiate boolean not null default false,
  status public.order_status not null default 'customer_submit',
  store_id bigint null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint orders_customer_group_id_fkey
    foreign key (customer_group_id)
    references public.customer_groups (id)
    on delete cascade
);

create index if not exists orders_customer_group_id_idx
  on public.orders using btree (customer_group_id);

create index if not exists orders_status_idx
  on public.orders using btree (status);

create index if not exists orders_store_id_idx
  on public.orders using btree (store_id);

create index if not exists orders_name_idx
  on public.orders using btree (name);

drop trigger if exists trg_orders_set_updated_at on public.orders;
create trigger trg_orders_set_updated_at
before update on public.orders
for each row
execute function public.set_updated_at();

-- =========================================================
-- ORDER ITEMS
-- =========================================================

create table if not exists public.order_items (
  id bigserial primary key,
  order_id bigint not null,
  name text not null,
  image_url text null,
  price_gbp numeric(12, 2) null,
  cost_gbp numeric(12, 2) null,
  cost_bdt numeric(12, 2) null,
  first_offer_bdt numeric(12, 2) null,
  customer_offer_bdt numeric(12, 2) null,
  final_offer_bdt numeric(12, 2) null,
  product_weight numeric(12, 3) null,
  package_weight numeric(12, 3) null,
  minimum_quantity integer not null default 1,
  product_id bigint null,
  ordered_quantity integer not null default 0,
  delivered_quantity integer not null default 0,
  returned_quantity integer not null default 0,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint order_items_order_id_fkey
    foreign key (order_id)
    references public.orders (id)
    on delete cascade,

  constraint order_items_product_id_fkey
    foreign key (product_id)
    references public.products (id)
    on delete set null,

  constraint order_items_minimum_quantity_check
    check (minimum_quantity > 0),

  constraint order_items_ordered_quantity_check
    check (ordered_quantity >= 0),

  constraint order_items_delivered_quantity_check
    check (delivered_quantity >= 0),

  constraint order_items_returned_quantity_check
    check (returned_quantity >= 0)
);

create index if not exists order_items_order_id_idx
  on public.order_items using btree (order_id);

create index if not exists order_items_product_id_idx
  on public.order_items using btree (product_id);

create index if not exists order_items_name_idx
  on public.order_items using btree (name);

drop trigger if exists trg_order_items_set_updated_at on public.order_items;
create trigger trg_order_items_set_updated_at
before update on public.order_items
for each row
execute function public.set_updated_at();

-- =========================================================
-- RLS (loose)
-- =========================================================

alter table public.orders enable row level security;
alter table public.order_items enable row level security;

drop policy if exists orders_select on public.orders;
create policy orders_select
on public.orders
for select
to authenticated
using (true);

drop policy if exists orders_insert on public.orders;
create policy orders_insert
on public.orders
for insert
to authenticated
with check (true);

drop policy if exists orders_update on public.orders;
create policy orders_update
on public.orders
for update
to authenticated
using (true)
with check (true);

drop policy if exists orders_delete on public.orders;
create policy orders_delete
on public.orders
for delete
to authenticated
using (true);

drop policy if exists order_items_select on public.order_items;
create policy order_items_select
on public.order_items
for select
to authenticated
using (true);

drop policy if exists order_items_insert on public.order_items;
create policy order_items_insert
on public.order_items
for insert
to authenticated
with check (true);

drop policy if exists order_items_update on public.order_items;
create policy order_items_update
on public.order_items
for update
to authenticated
using (true)
with check (true);

drop policy if exists order_items_delete on public.order_items;
create policy order_items_delete
on public.order_items
for delete
to authenticated
using (true);

-- =========================================================
-- SQL PRIVILEGES
-- =========================================================

grant select, insert, update, delete on table public.orders to authenticated;
grant select, insert, update, delete on table public.order_items to authenticated;
grant usage, select on sequence public.orders_id_seq to authenticated;
grant usage, select on sequence public.order_items_id_seq to authenticated;

commit;

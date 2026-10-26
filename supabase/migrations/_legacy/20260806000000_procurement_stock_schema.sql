begin;

-- =========================================================
-- 1. Drop Dependents & Legacy Objects
-- =========================================================

-- Drop legacy functions that reference old stock/allocation tables
drop function if exists public.search_stock_network(bigint, text, text, integer, integer, text, text) cascade;
drop function if exists public.count_search_stock_network(bigint, text, text, text, text) cascade;
drop function if exists public.list_global_stock_for_tenant(bigint, text, text, bigint, boolean, integer, integer) cascade;
drop function if exists public.count_global_stock_for_tenant(bigint, text, text, bigint, boolean) cascade;
drop function if exists public.receive_shipment_to_global_stock(bigint) cascade;
drop function if exists public.receive_shipment_to_global_stock(bigint, jsonb) cascade;
drop function if exists public.upsert_child_stock_allocation(bigint, bigint, bigint, public.global_stock_status, integer, boolean) cascade;

-- Drop legacy views depending on global_stocks / allocations (if any exist)
-- (no direct views in the migration list, but cascading handles them safely)

-- Drop legacy tables
drop table if exists public.global_stock_allocations cascade;
drop table if exists public.child_tenant_stock_allocations cascade;
drop table if exists public.global_stock_quantities cascade;
drop table if exists public.global_stocks cascade;

-- Drop legacy enums if they exist
drop type if exists public.global_stock_status cascade;

-- =========================================================
-- 2. Create Enums
-- =========================================================

do $$
begin
  if not exists (select 1 from pg_type where typname = 'global_shipment_type') then
    create type public.global_shipment_type as enum ('domestic', 'international');
  end if;
  if not exists (select 1 from pg_type where typname = 'global_shipment_item_add_method') then
    create type public.global_shipment_item_add_method as enum ('order', 'costing', 'manual');
  end if;
end $$;

-- =========================================================
-- 3. Create Tables
-- =========================================================

-- global_shipments
create table public.global_shipments (
  id bigserial primary key,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  vendor_id bigint references public.vendors(id) on delete set null,
  name text not null,
  tenant_shipment_id int,
  type public.global_shipment_type not null default 'international',
  status text not null default 'Draft',
  shipment_purchase_currency_id bigint references public.global_currencies(id) on delete set null,
  shipment_cost_currency_id bigint references public.global_currencies(id) on delete set null,
  product_conversion_rate numeric not null default 1.0,
  cargo_conversion_rate numeric not null default 1.0,
  cargo_rate numeric not null default 0.0,
  received_weight numeric,
  transaction_rate numeric,
  stock_ready boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint global_shipments_name_not_blank check (length(trim(name)) > 0),
  constraint global_shipments_status_check check (status in (
    'Draft',
    'Order Placed',
    'Proforma Generated',
    'Payment Done',
    'Delivery Date Received',
    'Uk Warehouse Delivery Received',
    'Air Shipment Date Set',
    'Airport Arrival',
    'Airport Released',
    'Warehouse Received',
    'Ready Stock'
  ))
);

-- global_shipment_items
create table public.global_shipment_items (
  id bigserial primary key,
  shipment_id bigint not null references public.global_shipments(id) on delete cascade,
  product_id bigint references public.products(id) on delete set null,
  name text not null,
  ordered_quantity int not null check (ordered_quantity >= 0),
  image_url text,
  add_method public.global_shipment_item_add_method not null default 'manual',
  purchase_price numeric not null default 0.0,
  product_weight numeric not null default 0.0, -- grams
  package_weight numeric not null default 0.0, -- grams
  barcode text,
  product_code text,
  source_child_tenant_id bigint references public.tenants(id) on delete set null,
  source_type text,
  source_id bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint global_shipment_items_name_not_blank check (length(trim(name)) > 0)
);

-- global_stock_types
create table public.global_stock_types (
  id bigserial primary key,
  parent_tenant_id bigint references public.tenants(id) on delete cascade,
  description text not null,
  is_sellable boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint global_stock_types_desc_not_blank check (length(trim(description)) > 0)
);

-- global_stocks
create table public.global_stocks (
  id bigserial primary key,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  shipment_item_id bigint not null references public.global_shipment_items(id) on delete cascade,
  stock_type_id bigint not null references public.global_stock_types(id) on delete cascade,
  quantity int not null default 0 check (quantity >= 0),
  is_usable boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint global_stocks_unique unique (shipment_item_id, stock_type_id, is_usable)
);

-- global_stock_allocations
create table public.global_stock_allocations (
  id bigserial primary key,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  child_tenant_id bigint not null references public.tenants(id) on delete cascade,
  stock_id bigint not null references public.global_stocks(id) on delete cascade,
  quantity int not null default 0 check (quantity >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint global_stock_allocations_unique unique (child_tenant_id, stock_id)
);

-- =========================================================
-- 4. Create Triggers (set_updated_at)
-- =========================================================

create trigger trg_global_shipments_updated_at
before update on public.global_shipments
for each row execute function public.set_updated_at();

create trigger trg_global_shipment_items_updated_at
before update on public.global_shipment_items
for each row execute function public.set_updated_at();

create trigger trg_global_stock_types_updated_at
before update on public.global_stock_types
for each row execute function public.set_updated_at();

create trigger trg_global_stocks_updated_at
before update on public.global_stocks
for each row execute function public.set_updated_at();

create trigger trg_global_stock_allocations_updated_at
before update on public.global_stock_allocations
for each row execute function public.set_updated_at();

-- =========================================================
-- 5. Create Indexes
-- =========================================================

create index if not exists global_shipments_parent_tenant_idx on public.global_shipments(parent_tenant_id);
create index if not exists global_shipments_vendor_idx on public.global_shipments(vendor_id);
create index if not exists global_shipment_items_shipment_idx on public.global_shipment_items(shipment_id);
create index if not exists global_shipment_items_product_idx on public.global_shipment_items(product_id);
create index if not exists global_stock_types_parent_tenant_idx on public.global_stock_types(parent_tenant_id);
create index if not exists global_stocks_parent_tenant_idx on public.global_stocks(parent_tenant_id);
create index if not exists global_stocks_shipment_item_idx on public.global_stocks(shipment_item_id);
create index if not exists global_stocks_stock_type_idx on public.global_stocks(stock_type_id);
create index if not exists global_stock_allocations_parent_tenant_idx on public.global_stock_allocations(parent_tenant_id);
create index if not exists global_stock_allocations_child_tenant_idx on public.global_stock_allocations(child_tenant_id);
create index if not exists global_stock_allocations_stock_idx on public.global_stock_allocations(stock_id);

-- =========================================================
-- 6. Enable Row Level Security (RLS)
-- =========================================================

alter table public.global_shipments enable row level security;
alter table public.global_shipment_items enable row level security;
alter table public.global_stock_types enable row level security;
alter table public.global_stocks enable row level security;
alter table public.global_stock_allocations enable row level security;

-- =========================================================
-- 7. Define RLS Policies
-- =========================================================

-- global_shipments
create policy global_shipments_select on public.global_shipments
for select to authenticated
using (
  public.user_can_manage_parent_tenant(parent_tenant_id)
  or exists (
    select 1 from public.memberships m
    where m.tenant_id = global_shipments.parent_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

create policy global_shipments_all on public.global_shipments
for all to authenticated
using (public.user_can_manage_parent_tenant(parent_tenant_id))
with check (public.user_can_manage_parent_tenant(parent_tenant_id));

-- global_shipment_items
create policy global_shipment_items_select on public.global_shipment_items
for select to authenticated
using (
  exists (
    select 1 from public.global_shipments gs
    where gs.id = shipment_id
  )
);

create policy global_shipment_items_all on public.global_shipment_items
for all to authenticated
using (
  exists (
    select 1 from public.global_shipments gs
    where gs.id = shipment_id
      and public.user_can_manage_parent_tenant(gs.parent_tenant_id)
  )
)
with check (
  exists (
    select 1 from public.global_shipments gs
    where gs.id = shipment_id
      and public.user_can_manage_parent_tenant(gs.parent_tenant_id)
  )
);

-- global_stock_types
create policy global_stock_types_select on public.global_stock_types
for select to authenticated
using (true);

create policy global_stock_types_all on public.global_stock_types
for all to authenticated
using (
  public.is_superadmin()
  or parent_tenant_id is null
  or public.user_can_manage_parent_tenant(parent_tenant_id)
)
with check (
  public.is_superadmin()
  or parent_tenant_id is null
  or public.user_can_manage_parent_tenant(parent_tenant_id)
);

-- global_stocks
create policy global_stocks_select on public.global_stocks
for select to authenticated
using (
  public.user_can_manage_parent_tenant(parent_tenant_id)
  or exists (
    select 1 from public.memberships m
    where m.tenant_id = global_stocks.parent_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
  or exists (
    select 1 from public.global_stock_allocations a
    inner join public.memberships m on m.tenant_id = a.child_tenant_id
    where a.stock_id = global_stocks.id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

create policy global_stocks_all on public.global_stocks
for all to authenticated
using (public.user_can_manage_parent_tenant(parent_tenant_id))
with check (public.user_can_manage_parent_tenant(parent_tenant_id));

-- global_stock_allocations
create policy global_stock_allocations_select on public.global_stock_allocations
for select to authenticated
using (
  public.user_can_manage_parent_tenant(parent_tenant_id)
  or exists (
    select 1 from public.memberships m
    where m.tenant_id = child_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

create policy global_stock_allocations_all on public.global_stock_allocations
for all to authenticated
using (public.user_can_manage_parent_tenant(parent_tenant_id))
with check (public.user_can_manage_parent_tenant(parent_tenant_id));

-- =========================================================
-- 8. Table Grants
-- =========================================================

grant select, insert, update, delete on table public.global_shipments to authenticated;
grant select, insert, update, delete on table public.global_shipment_items to authenticated;
grant select, insert, update, delete on table public.global_stock_types to authenticated;
grant select, insert, update, delete on table public.global_stocks to authenticated;
grant select, insert, update, delete on table public.global_stock_allocations to authenticated;

grant usage, select on sequence public.global_shipments_id_seq to authenticated;
grant usage, select on sequence public.global_shipment_items_id_seq to authenticated;
grant usage, select on sequence public.global_stock_types_id_seq to authenticated;
grant usage, select on sequence public.global_stocks_id_seq to authenticated;
grant usage, select on sequence public.global_stock_allocations_id_seq to authenticated;

-- =========================================================
-- 9. Seed Default Stock Types
-- =========================================================

insert into public.global_stock_types (parent_tenant_id, description, is_sellable, sort_order)
values
  (null, 'Standard Sellable', true, 10),
  (null, 'Box Damage', false, 20),
  (null, 'Expired', false, 30),
  (null, 'Stolen', false, 40),
  (null, 'Reserved', false, 50)
on conflict do nothing;

commit;

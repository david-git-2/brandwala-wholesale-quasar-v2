begin;

create table if not exists public.inventory_items (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  source_type text not null check (source_type in ('manual', 'shipment')),
  source_id bigint null,
  name text not null,
  image_url text null,
  cost numeric(12,2) null check (cost is null or cost >= 0),
  manufacturing_date date null,
  expire_date date null,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint inventory_items_name_not_blank check (length(trim(name)) > 0)
);

create index if not exists inventory_items_tenant_id_idx
  on public.inventory_items (tenant_id);

create index if not exists inventory_items_source_idx
  on public.inventory_items (source_type, source_id);

create index if not exists inventory_items_status_idx
  on public.inventory_items (status);

create table if not exists public.inventory_stocks (
  id bigserial primary key,
  inventory_item_id bigint not null unique references public.inventory_items(id) on delete cascade,
  available_quantity integer not null default 0 check (available_quantity >= 0),
  reserved_quantity integer not null default 0 check (reserved_quantity >= 0),
  damaged_quantity integer not null default 0 check (damaged_quantity >= 0),
  stolen_quantity integer not null default 0 check (stolen_quantity >= 0),
  expired_quantity integer not null default 0 check (expired_quantity >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists inventory_stocks_inventory_item_id_idx
  on public.inventory_stocks (inventory_item_id);

create table if not exists public.inventory_movements (
  id bigserial primary key,
  inventory_item_id bigint not null references public.inventory_items(id) on delete cascade,
  type text not null check (
    type in (
      'received',
      'sold',
      'reserved',
      'unreserved',
      'damaged',
      'stolen',
      'expired',
      'adjustment'
    )
  ),
  quantity integer not null check (quantity > 0),
  previous_quantity integer not null check (previous_quantity >= 0),
  new_quantity integer not null check (new_quantity >= 0),
  note text null,
  created_by uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists inventory_movements_inventory_item_id_idx
  on public.inventory_movements (inventory_item_id);

create index if not exists inventory_movements_type_idx
  on public.inventory_movements (type);

create index if not exists inventory_movements_created_at_idx
  on public.inventory_movements (created_at desc);

drop trigger if exists trg_inventory_items_set_updated_at on public.inventory_items;
create trigger trg_inventory_items_set_updated_at
before update on public.inventory_items
for each row
execute function public.set_updated_at();

drop trigger if exists trg_inventory_stocks_set_updated_at on public.inventory_stocks;
create trigger trg_inventory_stocks_set_updated_at
before update on public.inventory_stocks
for each row
execute function public.set_updated_at();

alter table public.inventory_items enable row level security;
alter table public.inventory_stocks enable row level security;
alter table public.inventory_movements enable row level security;

-- inventory_items policies

drop policy if exists inventory_items_select on public.inventory_items;
create policy inventory_items_select
on public.inventory_items
for select
to authenticated
using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = inventory_items.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists inventory_items_insert on public.inventory_items;
create policy inventory_items_insert
on public.inventory_items
for insert
to authenticated
with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = inventory_items.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists inventory_items_update on public.inventory_items;
create policy inventory_items_update
on public.inventory_items
for update
to authenticated
using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = inventory_items.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
)
with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = inventory_items.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists inventory_items_delete on public.inventory_items;
create policy inventory_items_delete
on public.inventory_items
for delete
to authenticated
using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = inventory_items.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

-- inventory_stocks policies

drop policy if exists inventory_stocks_select on public.inventory_stocks;
create policy inventory_stocks_select
on public.inventory_stocks
for select
to authenticated
using (
  exists (
    select 1
    from public.inventory_items ii
    join public.memberships m on m.tenant_id = ii.tenant_id
    where ii.id = inventory_stocks.inventory_item_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists inventory_stocks_insert on public.inventory_stocks;
create policy inventory_stocks_insert
on public.inventory_stocks
for insert
to authenticated
with check (
  exists (
    select 1
    from public.inventory_items ii
    join public.memberships m on m.tenant_id = ii.tenant_id
    where ii.id = inventory_stocks.inventory_item_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists inventory_stocks_update on public.inventory_stocks;
create policy inventory_stocks_update
on public.inventory_stocks
for update
to authenticated
using (
  exists (
    select 1
    from public.inventory_items ii
    join public.memberships m on m.tenant_id = ii.tenant_id
    where ii.id = inventory_stocks.inventory_item_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
)
with check (
  exists (
    select 1
    from public.inventory_items ii
    join public.memberships m on m.tenant_id = ii.tenant_id
    where ii.id = inventory_stocks.inventory_item_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists inventory_stocks_delete on public.inventory_stocks;
create policy inventory_stocks_delete
on public.inventory_stocks
for delete
to authenticated
using (
  exists (
    select 1
    from public.inventory_items ii
    join public.memberships m on m.tenant_id = ii.tenant_id
    where ii.id = inventory_stocks.inventory_item_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

-- inventory_movements policies

drop policy if exists inventory_movements_select on public.inventory_movements;
create policy inventory_movements_select
on public.inventory_movements
for select
to authenticated
using (
  exists (
    select 1
    from public.inventory_items ii
    join public.memberships m on m.tenant_id = ii.tenant_id
    where ii.id = inventory_movements.inventory_item_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists inventory_movements_insert on public.inventory_movements;
create policy inventory_movements_insert
on public.inventory_movements
for insert
to authenticated
with check (
  exists (
    select 1
    from public.inventory_items ii
    join public.memberships m on m.tenant_id = ii.tenant_id
    where ii.id = inventory_movements.inventory_item_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists inventory_movements_update on public.inventory_movements;
create policy inventory_movements_update
on public.inventory_movements
for update
to authenticated
using (
  exists (
    select 1
    from public.inventory_items ii
    join public.memberships m on m.tenant_id = ii.tenant_id
    where ii.id = inventory_movements.inventory_item_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
)
with check (
  exists (
    select 1
    from public.inventory_items ii
    join public.memberships m on m.tenant_id = ii.tenant_id
    where ii.id = inventory_movements.inventory_item_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists inventory_movements_delete on public.inventory_movements;
create policy inventory_movements_delete
on public.inventory_movements
for delete
to authenticated
using (
  exists (
    select 1
    from public.inventory_items ii
    join public.memberships m on m.tenant_id = ii.tenant_id
    where ii.id = inventory_movements.inventory_item_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

grant select, insert, update, delete on table public.inventory_items to authenticated;
grant select, insert, update, delete on table public.inventory_stocks to authenticated;
grant select, insert, update, delete on table public.inventory_movements to authenticated;

grant usage, select on sequence public.inventory_items_id_seq to authenticated;
grant usage, select on sequence public.inventory_stocks_id_seq to authenticated;
grant usage, select on sequence public.inventory_movements_id_seq to authenticated;

commit;

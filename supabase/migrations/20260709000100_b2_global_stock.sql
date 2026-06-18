-- B2: global_stocks, quantities, allocations, business_parties, receive RPC
begin;

-- =========================================================
-- 1. Enums
-- =========================================================

do $$
begin
  if not exists (select 1 from pg_type where typname = 'global_stock_status') then
    create type public.global_stock_status as enum (
      'excellent',
      'box_less',
      'box_damage',
      'expired',
      'stolen',
      'reserved'
    );
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'global_source_module') then
    create type public.global_source_module as enum (
      'wholesale',
      'retail',
      'commerce'
    );
  end if;
end $$;

-- =========================================================
-- 2. global_stocks
-- =========================================================

create table if not exists public.global_stocks (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  cost numeric(12,2) not null default 0 check (cost >= 0),
  shipment_id bigint null references public.shipments(id) on delete set null,
  shipment_item_id bigint null references public.shipment_items(id) on delete set null,
  image_url text null,
  product_code text null,
  barcode text null,
  product_id bigint null references public.products(id) on delete set null,
  shipment_type text not null default 'international'
    check (shipment_type in ('local', 'international')),
  cost_currency text not null default 'BDT' check (cost_currency = 'BDT'),
  price_currency text not null default 'BDT' check (price_currency in ('BDT', 'GBP')),
  source_module public.global_source_module not null default 'wholesale',
  source_type text null check (source_type in ('manual', 'shipment', 'migration')),
  source_id bigint null,
  legacy_inventory_item_id bigint null,
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint global_stocks_name_not_blank check (length(trim(name)) > 0)
);

create index if not exists global_stocks_tenant_id_idx on public.global_stocks (tenant_id);
create index if not exists global_stocks_parent_tenant_id_idx on public.global_stocks (parent_tenant_id);
create index if not exists global_stocks_shipment_id_idx on public.global_stocks (shipment_id);
create index if not exists global_stocks_product_id_idx on public.global_stocks (product_id);
create index if not exists global_stocks_barcode_idx on public.global_stocks (barcode);

-- =========================================================
-- 3. global_stock_quantities
-- =========================================================

create table if not exists public.global_stock_quantities (
  id bigserial primary key,
  stock_id bigint not null references public.global_stocks(id) on delete cascade,
  status public.global_stock_status not null,
  quantity integer not null default 0 check (quantity >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint global_stock_quantities_unique unique (stock_id, status)
);

create index if not exists global_stock_quantities_stock_id_idx
  on public.global_stock_quantities (stock_id);

-- =========================================================
-- 4. child_tenant_stock_allocations
-- =========================================================

create table if not exists public.child_tenant_stock_allocations (
  id bigserial primary key,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  child_tenant_id bigint not null references public.tenants(id) on delete cascade,
  stock_id bigint not null references public.global_stocks(id) on delete cascade,
  status public.global_stock_status not null default 'excellent',
  quantity integer not null default 0 check (quantity >= 0),
  is_display_only boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint child_tenant_stock_allocations_unique unique (child_tenant_id, stock_id, status)
);

create index if not exists child_tenant_stock_allocations_parent_idx
  on public.child_tenant_stock_allocations (parent_tenant_id);
create index if not exists child_tenant_stock_allocations_child_idx
  on public.child_tenant_stock_allocations (child_tenant_id);

-- =========================================================
-- 5. business_parties
-- =========================================================

create table if not exists public.business_parties (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  phone text null,
  email text null,
  address text null,
  party_type text not null default 'customer'
    check (party_type in ('customer', 'recipient', 'ordered_by', 'other')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_parties_name_not_blank check (length(trim(name)) > 0)
);

create index if not exists business_parties_tenant_id_idx on public.business_parties (tenant_id);
create index if not exists business_parties_parent_tenant_id_idx on public.business_parties (parent_tenant_id);

-- =========================================================
-- 6. updated_at triggers
-- =========================================================

drop trigger if exists trg_global_stocks_set_updated_at on public.global_stocks;
create trigger trg_global_stocks_set_updated_at
before update on public.global_stocks
for each row execute function public.set_updated_at();

drop trigger if exists trg_global_stock_quantities_set_updated_at on public.global_stock_quantities;
create trigger trg_global_stock_quantities_set_updated_at
before update on public.global_stock_quantities
for each row execute function public.set_updated_at();

drop trigger if exists trg_child_tenant_stock_allocations_set_updated_at on public.child_tenant_stock_allocations;
create trigger trg_child_tenant_stock_allocations_set_updated_at
before update on public.child_tenant_stock_allocations
for each row execute function public.set_updated_at();

drop trigger if exists trg_business_parties_set_updated_at on public.business_parties;
create trigger trg_business_parties_set_updated_at
before update on public.business_parties
for each row execute function public.set_updated_at();

-- =========================================================
-- 7. RLS
-- =========================================================

alter table public.global_stocks enable row level security;
alter table public.global_stock_quantities enable row level security;
alter table public.child_tenant_stock_allocations enable row level security;
alter table public.business_parties enable row level security;

drop policy if exists global_stocks_select on public.global_stocks;
create policy global_stocks_select on public.global_stocks
for select to authenticated
using (
  public.user_can_manage_parent_tenant(parent_tenant_id)
  or exists (
    select 1
    from public.memberships m
    where m.tenant_id = global_stocks.parent_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
  or exists (
    select 1
    from public.child_tenant_stock_allocations a
    inner join public.memberships m on m.tenant_id = a.child_tenant_id
    where a.stock_id = global_stocks.id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists global_stocks_write on public.global_stocks;
create policy global_stocks_write on public.global_stocks
for all to authenticated
using (public.user_can_manage_parent_tenant(parent_tenant_id))
with check (public.user_can_manage_parent_tenant(parent_tenant_id));

drop policy if exists global_stock_quantities_select on public.global_stock_quantities;
create policy global_stock_quantities_select on public.global_stock_quantities
for select to authenticated
using (
  exists (
    select 1 from public.global_stocks gs
    where gs.id = global_stock_quantities.stock_id
  )
);

drop policy if exists global_stock_quantities_write on public.global_stock_quantities;
create policy global_stock_quantities_write on public.global_stock_quantities
for all to authenticated
using (
  exists (
    select 1 from public.global_stocks gs
    where gs.id = global_stock_quantities.stock_id
      and public.user_can_manage_parent_tenant(gs.parent_tenant_id)
  )
)
with check (
  exists (
    select 1 from public.global_stocks gs
    where gs.id = global_stock_quantities.stock_id
      and public.user_can_manage_parent_tenant(gs.parent_tenant_id)
  )
);

drop policy if exists child_tenant_stock_allocations_select on public.child_tenant_stock_allocations;
create policy child_tenant_stock_allocations_select on public.child_tenant_stock_allocations
for select to authenticated
using (
  public.user_can_manage_parent_tenant(parent_tenant_id)
  or exists (
    select 1 from public.memberships m
    where m.tenant_id = child_tenant_stock_allocations.child_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists child_tenant_stock_allocations_write on public.child_tenant_stock_allocations;
create policy child_tenant_stock_allocations_write on public.child_tenant_stock_allocations
for all to authenticated
using (public.user_can_manage_parent_tenant(parent_tenant_id))
with check (public.user_can_manage_parent_tenant(parent_tenant_id));

drop policy if exists business_parties_select on public.business_parties;
create policy business_parties_select on public.business_parties
for select to authenticated
using (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = business_parties.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
  or public.user_can_manage_parent_tenant(parent_tenant_id)
);

drop policy if exists business_parties_write on public.business_parties;
create policy business_parties_write on public.business_parties
for all to authenticated
using (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = business_parties.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
)
with check (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = business_parties.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

-- =========================================================
-- 8. receive_shipment_to_global_stock
-- =========================================================

create or replace function public.receive_shipment_to_global_stock(
  p_shipment_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shipment public.shipments;
  v_item record;
  v_stock_id bigint;
  v_cost numeric(12,2);
  v_split jsonb;
  v_split_type text;
  v_split_qty integer;
  v_status public.global_stock_status;
  v_created_count integer := 0;
  v_parent_tenant_id bigint;
begin
  select * into v_shipment
  from public.shipments
  where id = p_shipment_id;

  if v_shipment.id is null then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_shipment.tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_shipment.inventory_added is true then
    raise exception 'shipment already received to stock';
  end if;

  v_parent_tenant_id := v_shipment.tenant_id;

  for v_item in
    select *
    from public.shipment_items
    where shipment_id = p_shipment_id
  loop
    v_cost := coalesce(v_item.cost_bdt, 0);

    insert into public.global_stocks (
      tenant_id,
      parent_tenant_id,
      name,
      cost,
      shipment_id,
      shipment_item_id,
      image_url,
      product_code,
      barcode,
      product_id,
      shipment_type,
      price_currency,
      source_module,
      source_type,
      source_id
    )
    values (
      v_parent_tenant_id,
      v_parent_tenant_id,
      coalesce(nullif(trim(v_item.name), ''), 'Unnamed item'),
      v_cost,
      p_shipment_id,
      v_item.id,
      v_item.image_url,
      v_item.product_code,
      v_item.barcode,
      v_item.product_id,
      coalesce(v_shipment.shipment_type, 'international'),
      case when coalesce(v_shipment.shipment_type, 'international') = 'international' then 'GBP' else 'BDT' end,
      'wholesale',
      'shipment',
      v_item.id
    )
    returning id into v_stock_id;

    if v_item.receiving_splits is not null and jsonb_typeof(v_item.receiving_splits) = 'array' then
      for v_split in select * from jsonb_array_elements(v_item.receiving_splits)
      loop
        v_split_type := lower(trim(coalesce(v_split->>'type', 'excellent')));
        v_split_qty := greatest(coalesce((v_split->>'qty')::integer, 0), 0);
        if v_split_qty = 0 then
          continue;
        end if;

        v_status := case v_split_type
          when 'boxless' then 'box_less'::public.global_stock_status
          when 'box_less' then 'box_less'::public.global_stock_status
          when 'box_damage' then 'box_damage'::public.global_stock_status
          when 'expired' then 'expired'::public.global_stock_status
          when 'stolen' then 'stolen'::public.global_stock_status
          when 'reserved' then 'reserved'::public.global_stock_status
          else 'excellent'::public.global_stock_status
        end;

        insert into public.global_stock_quantities (stock_id, status, quantity)
        values (v_stock_id, v_status, v_split_qty)
        on conflict (stock_id, status)
        do update set quantity = global_stock_quantities.quantity + excluded.quantity;
      end loop;
    else
      insert into public.global_stock_quantities (stock_id, status, quantity)
      values (v_stock_id, 'excellent', greatest(coalesce(v_item.quantity, 0), 0))
      on conflict (stock_id, status)
      do update set quantity = global_stock_quantities.quantity + excluded.quantity;
    end if;

    v_created_count := v_created_count + 1;
  end loop;

  update public.shipments
  set inventory_added = true,
      status = coalesce(nullif(trim(status), ''), 'Added to Inventory')
  where id = p_shipment_id;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'stocks_created', v_created_count
  );
end;
$$;

grant execute on function public.receive_shipment_to_global_stock(bigint) to authenticated;

-- =========================================================
-- 9. list_global_stock_for_tenant
-- =========================================================

create or replace function public.list_global_stock_for_tenant(
  p_tenant_id bigint,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id bigint,
  tenant_id bigint,
  parent_tenant_id bigint,
  name text,
  cost numeric,
  shipment_id bigint,
  product_id bigint,
  barcode text,
  product_code text,
  image_url text,
  excellent_qty integer,
  box_less_qty integer,
  box_damage_qty integer,
  expired_qty integer,
  stolen_qty integer,
  reserved_qty integer,
  total_qty integer
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_parent_id bigint;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  return query
  select
    gs.id,
    gs.tenant_id,
    gs.parent_tenant_id,
    gs.name,
    gs.cost,
    gs.shipment_id,
    gs.product_id,
    gs.barcode,
    gs.product_code,
    gs.image_url,
    coalesce(sum(q.quantity) filter (where q.status = 'excellent'), 0)::integer as excellent_qty,
    coalesce(sum(q.quantity) filter (where q.status = 'box_less'), 0)::integer as box_less_qty,
    coalesce(sum(q.quantity) filter (where q.status = 'box_damage'), 0)::integer as box_damage_qty,
    coalesce(sum(q.quantity) filter (where q.status = 'expired'), 0)::integer as expired_qty,
    coalesce(sum(q.quantity) filter (where q.status = 'stolen'), 0)::integer as stolen_qty,
    coalesce(sum(q.quantity) filter (where q.status = 'reserved'), 0)::integer as reserved_qty,
    coalesce(sum(q.quantity), 0)::integer as total_qty
  from public.global_stocks gs
  left join public.global_stock_quantities q on q.stock_id = gs.id
  where gs.parent_tenant_id = v_parent_id
    and gs.status = 'active'
    and (
      p_tenant_id = v_parent_id
      or exists (
        select 1
        from public.child_tenant_stock_allocations a
        where a.stock_id = gs.id
          and a.child_tenant_id = p_tenant_id
          and a.quantity > 0
      )
    )
    and (
      p_search is null
      or trim(p_search) = ''
      or gs.name ilike '%' || trim(p_search) || '%'
      or coalesce(gs.barcode, '') ilike '%' || trim(p_search) || '%'
      or coalesce(gs.product_code, '') ilike '%' || trim(p_search) || '%'
    )
  group by gs.id
  order by gs.id desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

grant execute on function public.list_global_stock_for_tenant(bigint, text, integer, integer) to authenticated;

-- =========================================================
-- 10. upsert_child_stock_allocation
-- =========================================================

create or replace function public.upsert_child_stock_allocation(
  p_parent_tenant_id bigint,
  p_child_tenant_id bigint,
  p_stock_id bigint,
  p_status public.global_stock_status default 'excellent',
  p_quantity integer default 0,
  p_is_display_only boolean default true
)
returns public.child_tenant_stock_allocations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.child_tenant_stock_allocations;
  v_parent_qty integer;
begin
  if not public.user_can_manage_parent_tenant(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if not exists (
    select 1 from public.tenants
    where id = p_child_tenant_id and parent_id = p_parent_tenant_id
  ) then
    raise exception 'child tenant does not belong to parent';
  end if;

  if not exists (
    select 1 from public.global_stocks
    where id = p_stock_id and parent_tenant_id = p_parent_tenant_id
  ) then
    raise exception 'stock not found for parent tenant';
  end if;

  select coalesce(q.quantity, 0) into v_parent_qty
  from public.global_stock_quantities q
  where q.stock_id = p_stock_id and q.status = p_status;

  if p_quantity > coalesce(v_parent_qty, 0) then
    raise exception 'allocation exceeds parent quantity';
  end if;

  insert into public.child_tenant_stock_allocations (
    parent_tenant_id,
    child_tenant_id,
    stock_id,
    status,
    quantity,
    is_display_only
  )
  values (
    p_parent_tenant_id,
    p_child_tenant_id,
    p_stock_id,
    p_status,
    greatest(coalesce(p_quantity, 0), 0),
    coalesce(p_is_display_only, true)
  )
  on conflict (child_tenant_id, stock_id, status)
  do update set
    quantity = excluded.quantity,
    is_display_only = excluded.is_display_only
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.upsert_child_stock_allocation(bigint, bigint, bigint, public.global_stock_status, integer, boolean) to authenticated;

commit;

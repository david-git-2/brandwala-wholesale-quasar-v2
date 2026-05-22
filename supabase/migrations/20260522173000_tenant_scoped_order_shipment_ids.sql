begin;

-- Per-tenant counters used to generate tenant-scoped sequence numbers.
create table if not exists public.tenant_scoped_counters (
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  scope text not null,
  last_value bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tenant_scoped_counters_pkey primary key (tenant_id, scope),
  constraint tenant_scoped_counters_scope_check check (scope in ('shipment', 'order')),
  constraint tenant_scoped_counters_last_value_check check (last_value >= 0)
);

create index if not exists tenant_scoped_counters_scope_idx
  on public.tenant_scoped_counters (scope);

drop trigger if exists trg_tenant_scoped_counters_set_updated_at on public.tenant_scoped_counters;
create trigger trg_tenant_scoped_counters_set_updated_at
before update on public.tenant_scoped_counters
for each row
execute function public.set_updated_at();

create or replace function public.next_tenant_scoped_counter(
  p_tenant_id bigint,
  p_scope text
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_next bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if p_scope not in ('shipment', 'order') then
    raise exception 'invalid scope: %', p_scope;
  end if;

  insert into public.tenant_scoped_counters (tenant_id, scope, last_value)
  values (p_tenant_id, p_scope, 1)
  on conflict (tenant_id, scope)
  do update
    set last_value = public.tenant_scoped_counters.last_value + 1
  returning last_value into v_next;

  return v_next;
end;
$$;

grant execute on function public.next_tenant_scoped_counter(bigint, text)
to authenticated;

-- -------------------------
-- Shipments tenant-scoped id
-- -------------------------
alter table public.shipments
  add column if not exists tenant_shipment_id bigint;

with numbered as (
  select
    s.id,
    row_number() over (partition by s.tenant_id order by s.created_at, s.id) as scoped_id
  from public.shipments s
)
update public.shipments s
set tenant_shipment_id = numbered.scoped_id
from numbered
where s.id = numbered.id
  and s.tenant_shipment_id is null;

alter table public.shipments
  alter column tenant_shipment_id set not null;

create unique index if not exists shipments_tenant_id_tenant_shipment_id_uidx
  on public.shipments (tenant_id, tenant_shipment_id);

create index if not exists shipments_tenant_shipment_id_idx
  on public.shipments (tenant_shipment_id);

create or replace function public.assign_tenant_shipment_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.tenant_id is null then
    raise exception 'tenant_id is required for shipments';
  end if;

  if tg_op = 'UPDATE' and new.tenant_id <> old.tenant_id then
    raise exception 'changing shipment tenant_id is not allowed';
  end if;

  if new.tenant_shipment_id is null then
    new.tenant_shipment_id := public.next_tenant_scoped_counter(new.tenant_id, 'shipment');
  end if;

  return new;
end;
$$;

drop trigger if exists trg_assign_tenant_shipment_id on public.shipments;
create trigger trg_assign_tenant_shipment_id
before insert or update on public.shipments
for each row
execute function public.assign_tenant_shipment_id();

-- ----------------------
-- Orders tenant-scoped id
-- ----------------------
alter table public.orders
  add column if not exists tenant_id bigint,
  add column if not exists tenant_order_id bigint;

update public.orders o
set tenant_id = cg.tenant_id
from public.customer_groups cg
where cg.id = o.customer_group_id
  and o.tenant_id is null;

-- Guard against legacy data mismatch.
do $$
begin
  if exists (
    select 1
    from public.orders o
    join public.customer_groups cg
      on cg.id = o.customer_group_id
    where o.tenant_id <> cg.tenant_id
  ) then
    raise exception 'orders.tenant_id has mismatched tenant against customer_group_id';
  end if;

  if exists (
    select 1
    from public.orders o
    where o.tenant_id is null
  ) then
    raise exception 'orders.tenant_id backfill failed for one or more rows';
  end if;
end
$$;

alter table public.orders
  alter column tenant_id set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'orders_tenant_id_fkey'
      and conrelid = 'public.orders'::regclass
  ) then
    alter table public.orders
      add constraint orders_tenant_id_fkey
      foreign key (tenant_id)
      references public.tenants(id)
      on delete cascade;
  end if;
end
$$;

with numbered as (
  select
    o.id,
    row_number() over (partition by o.tenant_id order by o.created_at, o.id) as scoped_id
  from public.orders o
)
update public.orders o
set tenant_order_id = numbered.scoped_id
from numbered
where o.id = numbered.id
  and o.tenant_order_id is null;

alter table public.orders
  alter column tenant_order_id set not null;

create index if not exists orders_tenant_id_idx
  on public.orders (tenant_id);

create unique index if not exists orders_tenant_id_tenant_order_id_uidx
  on public.orders (tenant_id, tenant_order_id);

create index if not exists orders_tenant_order_id_idx
  on public.orders (tenant_order_id);

create or replace function public.assign_order_tenant_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
begin
  select cg.tenant_id
  into v_tenant_id
  from public.customer_groups cg
  where cg.id = new.customer_group_id;

  if v_tenant_id is null then
    raise exception 'customer_group_id % is invalid or has no tenant', new.customer_group_id;
  end if;

  if tg_op = 'UPDATE' and old.tenant_id is not null and old.tenant_id <> v_tenant_id then
    raise exception 'changing order across tenants is not allowed';
  end if;

  new.tenant_id := v_tenant_id;

  if new.tenant_order_id is null then
    new.tenant_order_id := public.next_tenant_scoped_counter(new.tenant_id, 'order');
  end if;

  return new;
end;
$$;

drop trigger if exists trg_assign_order_tenant_fields on public.orders;
create trigger trg_assign_order_tenant_fields
before insert or update on public.orders
for each row
execute function public.assign_order_tenant_fields();

-- Sync counters to current max after backfill.
insert into public.tenant_scoped_counters (tenant_id, scope, last_value)
select s.tenant_id, 'shipment'::text, max(s.tenant_shipment_id)
from public.shipments s
group by s.tenant_id
on conflict (tenant_id, scope)
do update
set last_value = greatest(public.tenant_scoped_counters.last_value, excluded.last_value);

insert into public.tenant_scoped_counters (tenant_id, scope, last_value)
select o.tenant_id, 'order'::text, max(o.tenant_order_id)
from public.orders o
group by o.tenant_id
on conflict (tenant_id, scope)
do update
set last_value = greatest(public.tenant_scoped_counters.last_value, excluded.last_value);

commit;

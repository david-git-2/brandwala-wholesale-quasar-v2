begin;

create table if not exists public.shipment_inventory_accounting (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  shipment_id bigint not null references public.shipments(id) on delete cascade,
  usable_quantity integer not null default 0,
  damaged_quantity integer not null default 0,
  stolen_quantity integer not null default 0,
  expired_quantity integer not null default 0,
  usable_cost_total numeric(14, 2) not null default 0,
  damaged_cost_total numeric(14, 2) not null default 0,
  stolen_cost_total numeric(14, 2) not null default 0,
  expired_cost_total numeric(14, 2) not null default 0,
  inventory_cost_total numeric(14, 2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shipment_inventory_accounting_unique unique (tenant_id, shipment_id)
);

create index if not exists shipment_inventory_accounting_tenant_id_idx
  on public.shipment_inventory_accounting (tenant_id);

create index if not exists shipment_inventory_accounting_shipment_id_idx
  on public.shipment_inventory_accounting (shipment_id);

drop trigger if exists trg_shipment_inventory_accounting_set_updated_at on public.shipment_inventory_accounting;
create trigger trg_shipment_inventory_accounting_set_updated_at
before update on public.shipment_inventory_accounting
for each row
execute function public.set_updated_at();

create or replace function public.refresh_shipment_inventory_accounting(
  p_tenant_id bigint,
  p_shipment_id bigint default null
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rows integer := 0;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if not (
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Not allowed to refresh shipment inventory accounting for this tenant.';
  end if;

  insert into public.shipment_inventory_accounting (
    tenant_id,
    shipment_id,
    usable_quantity,
    damaged_quantity,
    stolen_quantity,
    expired_quantity,
    usable_cost_total,
    damaged_cost_total,
    stolen_cost_total,
    expired_cost_total,
    inventory_cost_total
  )
  select
    s.tenant_id,
    s.id as shipment_id,
    coalesce(sum(greatest(
      0,
      coalesce(ist.available_quantity, 0)
      - coalesce(ist.reserved_quantity, 0)
      - coalesce(ist.damaged_quantity, 0)
      - coalesce(ist.stolen_quantity, 0)
      - coalesce(ist.expired_quantity, 0)
    )), 0)::integer as usable_quantity,
    coalesce(sum(coalesce(ist.damaged_quantity, 0)), 0)::integer as damaged_quantity,
    coalesce(sum(coalesce(ist.stolen_quantity, 0)), 0)::integer as stolen_quantity,
    coalesce(sum(coalesce(ist.expired_quantity, 0)), 0)::integer as expired_quantity,
    coalesce(sum(coalesce(ii.cost, 0) * greatest(
      0,
      coalesce(ist.available_quantity, 0)
      - coalesce(ist.reserved_quantity, 0)
      - coalesce(ist.damaged_quantity, 0)
      - coalesce(ist.stolen_quantity, 0)
      - coalesce(ist.expired_quantity, 0)
    )), 0)::numeric(14, 2) as usable_cost_total,
    coalesce(sum(coalesce(ii.cost, 0) * coalesce(ist.damaged_quantity, 0)), 0)::numeric(14, 2) as damaged_cost_total,
    coalesce(sum(coalesce(ii.cost, 0) * coalesce(ist.stolen_quantity, 0)), 0)::numeric(14, 2) as stolen_cost_total,
    coalesce(sum(coalesce(ii.cost, 0) * coalesce(ist.expired_quantity, 0)), 0)::numeric(14, 2) as expired_cost_total,
    (
      coalesce(sum(coalesce(ii.cost, 0) * greatest(
        0,
        coalesce(ist.available_quantity, 0)
        - coalesce(ist.reserved_quantity, 0)
        - coalesce(ist.damaged_quantity, 0)
        - coalesce(ist.stolen_quantity, 0)
        - coalesce(ist.expired_quantity, 0)
      )), 0)
      + coalesce(sum(coalesce(ii.cost, 0) * coalesce(ist.damaged_quantity, 0)), 0)
      + coalesce(sum(coalesce(ii.cost, 0) * coalesce(ist.stolen_quantity, 0)), 0)
      + coalesce(sum(coalesce(ii.cost, 0) * coalesce(ist.expired_quantity, 0)), 0)
    )::numeric(14, 2) as inventory_cost_total
  from public.shipments s
  left join public.shipment_items si
    on si.shipment_id = s.id
  left join public.inventory_items ii
    on ii.tenant_id = s.tenant_id
    and ii.source_type = 'shipment'
    and ii.source_id = si.id
  left join public.inventory_stocks ist
    on ist.inventory_item_id = ii.id
  where s.tenant_id = p_tenant_id
    and (p_shipment_id is null or s.id = p_shipment_id)
  group by s.tenant_id, s.id
  on conflict (tenant_id, shipment_id)
  do update
  set
    usable_quantity = excluded.usable_quantity,
    damaged_quantity = excluded.damaged_quantity,
    stolen_quantity = excluded.stolen_quantity,
    expired_quantity = excluded.expired_quantity,
    usable_cost_total = excluded.usable_cost_total,
    damaged_cost_total = excluded.damaged_cost_total,
    stolen_cost_total = excluded.stolen_cost_total,
    expired_cost_total = excluded.expired_cost_total,
    inventory_cost_total = excluded.inventory_cost_total,
    updated_at = now();

  get diagnostics v_rows = row_count;
  return v_rows;
end;
$$;

grant execute on function public.refresh_shipment_inventory_accounting(bigint, bigint)
to authenticated;

alter table public.shipment_inventory_accounting enable row level security;

drop policy if exists shipment_inventory_accounting_select on public.shipment_inventory_accounting;
create policy shipment_inventory_accounting_select
on public.shipment_inventory_accounting
for select
to authenticated
using (
  public.is_superadmin()
  or exists (
    select 1
    from public.memberships m
    where m.tenant_id = shipment_inventory_accounting.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists shipment_inventory_accounting_insert on public.shipment_inventory_accounting;
create policy shipment_inventory_accounting_insert
on public.shipment_inventory_accounting
for insert
to authenticated
with check (
  public.is_superadmin()
  or exists (
    select 1
    from public.memberships m
    where m.tenant_id = shipment_inventory_accounting.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists shipment_inventory_accounting_update on public.shipment_inventory_accounting;
create policy shipment_inventory_accounting_update
on public.shipment_inventory_accounting
for update
to authenticated
using (
  public.is_superadmin()
  or exists (
    select 1
    from public.memberships m
    where m.tenant_id = shipment_inventory_accounting.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
)
with check (
  public.is_superadmin()
  or exists (
    select 1
    from public.memberships m
    where m.tenant_id = shipment_inventory_accounting.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists shipment_inventory_accounting_delete on public.shipment_inventory_accounting;
create policy shipment_inventory_accounting_delete
on public.shipment_inventory_accounting
for delete
to authenticated
using (
  public.is_superadmin()
  or exists (
    select 1
    from public.memberships m
    where m.tenant_id = shipment_inventory_accounting.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

grant select, insert, update, delete on table public.shipment_inventory_accounting to authenticated;
grant usage, select on sequence public.shipment_inventory_accounting_id_seq to authenticated;

commit;

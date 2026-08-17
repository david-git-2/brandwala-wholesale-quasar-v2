-- Phase 1: shipment cost entries + landed_cost_bdt stamp (alter in place).
-- v2: doc/v2/shipment/schema.md

begin;

-- ---------------------------------------------------------------------------
-- 1. Enum for cost entry types
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'global_shipment_cost_type') then
    create type public.global_shipment_cost_type as enum (
      'product',
      'cargo',
      'duty',
      'insurance',
      'labor',
      'washing',
      'transport',
      'handling'
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. global_shipment_cost_entries
-- ---------------------------------------------------------------------------
create table if not exists public.global_shipment_cost_entries (
  id bigint generated always as identity primary key,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  shipment_id bigint not null references public.global_shipments(id) on delete cascade,
  cost_type public.global_shipment_cost_type not null,
  amount numeric not null check (amount >= 0),
  currency_id bigint references public.global_currencies(id) on delete set null,
  exchange_rate numeric not null default 1.0 check (exchange_rate > 0),
  payment_source text,
  entity_type text,
  entity_id bigint,
  allocation text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint global_shipment_cost_entries_payment_source_check
    check (payment_source is null or payment_source in ('cash', 'credit', 'wallet'))
);

create index if not exists global_shipment_cost_entries_shipment_idx
  on public.global_shipment_cost_entries (shipment_id);
create index if not exists global_shipment_cost_entries_parent_tenant_idx
  on public.global_shipment_cost_entries (parent_tenant_id);
create index if not exists global_shipment_cost_entries_type_idx
  on public.global_shipment_cost_entries (shipment_id, cost_type);

drop trigger if exists trg_global_shipment_cost_entries_updated_at on public.global_shipment_cost_entries;
create trigger trg_global_shipment_cost_entries_updated_at
  before update on public.global_shipment_cost_entries
  for each row execute function public.set_updated_at();

alter table public.global_shipment_cost_entries enable row level security;

drop policy if exists global_shipment_cost_entries_select on public.global_shipment_cost_entries;
create policy global_shipment_cost_entries_select on public.global_shipment_cost_entries
for select to authenticated
using (
  public.user_can_manage_parent_tenant(parent_tenant_id)
  or exists (
    select 1
    from public.memberships m
    where m.tenant_id = global_shipment_cost_entries.parent_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists global_shipment_cost_entries_all on public.global_shipment_cost_entries;
create policy global_shipment_cost_entries_all on public.global_shipment_cost_entries
for all to authenticated
using (public.user_can_manage_parent_tenant(parent_tenant_id))
with check (public.user_can_manage_parent_tenant(parent_tenant_id));

grant select, insert, update, delete on table public.global_shipment_cost_entries to authenticated;
grant usage, select on sequence public.global_shipment_cost_entries_id_seq to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Alter global_shipment_items + global_shipments (additive)
-- ---------------------------------------------------------------------------
alter table public.global_shipment_items
  add column if not exists landed_cost_bdt numeric;

comment on column public.global_shipment_items.landed_cost_bdt is
  'Authoritative per-unit landed BDT. Written only by finalize/revision stamp RPCs. Null while draft.';

alter table public.global_shipments
  add column if not exists assigned_child_tenant_id bigint references public.tenants(id) on delete set null;

create index if not exists global_shipments_assigned_child_idx
  on public.global_shipments (assigned_child_tenant_id)
  where assigned_child_tenant_id is not null;

-- Block client writes to landed_cost_bdt unless stamp RPC sets session flag
create or replace function public.trg_global_shipment_items_guard_landed_cost()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE'
     and new.landed_cost_bdt is distinct from old.landed_cost_bdt
     and coalesce(current_setting('app.allow_landed_cost_stamp', true), '') is distinct from '1'
  then
    raise exception 'landed_cost_bdt is stamp-only; use finalize/revise RPCs';
  end if;
  if tg_op = 'INSERT'
     and new.landed_cost_bdt is not null
     and coalesce(current_setting('app.allow_landed_cost_stamp', true), '') is distinct from '1'
  then
    raise exception 'landed_cost_bdt is stamp-only; use finalize/revise RPCs';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_global_shipment_items_guard_landed_cost on public.global_shipment_items;
create trigger trg_global_shipment_items_guard_landed_cost
  before insert or update on public.global_shipment_items
  for each row execute function public.trg_global_shipment_items_guard_landed_cost();

-- ---------------------------------------------------------------------------
-- 4. Ensure day-one product+cargo entries from header rates (idempotent)
-- ---------------------------------------------------------------------------
create or replace function public.ensure_global_shipment_cost_entries_from_header(p_shipment_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_goods numeric;
  v_cargo_amt numeric;
  v_cargo_kg numeric;
  v_pack_kg numeric;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if exists (
    select 1 from public.global_shipment_cost_entries e where e.shipment_id = p_shipment_id
  ) then
    return;
  end if;

  select coalesce(sum(gsi.purchase_price * gsi.ordered_quantity), 0)
  into v_goods
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  if v_ship.purchase_invoice_total is not null and v_ship.purchase_invoice_total > 0 then
    v_goods := v_ship.purchase_invoice_total;
  end if;

  select coalesce(sum(
    ((coalesce(gsi.product_weight, 0) + coalesce(gsi.package_weight, 0)) * gsi.ordered_quantity) / 1000.0
  ), 0)
  into v_pack_kg
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  v_cargo_kg := case
    when v_ship.received_weight is not null and v_ship.received_weight > 0 then v_ship.received_weight
    else v_pack_kg
  end;

  if v_ship.cargo_invoice_total is not null and v_ship.cargo_invoice_total > 0 then
    v_cargo_amt := v_ship.cargo_invoice_total;
  else
    v_cargo_amt := v_cargo_kg * coalesce(v_ship.cargo_rate, 0);
  end if;

  insert into public.global_shipment_cost_entries (
    parent_tenant_id, shipment_id, cost_type, amount, currency_id, exchange_rate, metadata
  ) values (
    v_ship.parent_tenant_id,
    p_shipment_id,
    'product',
    greatest(v_goods, 0),
    v_ship.shipment_purchase_currency_id,
    coalesce(nullif(v_ship.product_conversion_rate, 0), 1.0),
    jsonb_build_object('source', 'header_backfill')
  );

  insert into public.global_shipment_cost_entries (
    parent_tenant_id, shipment_id, cost_type, amount, currency_id, exchange_rate, metadata
  ) values (
    v_ship.parent_tenant_id,
    p_shipment_id,
    'cargo',
    greatest(v_cargo_amt, 0),
    v_ship.shipment_cost_currency_id,
    coalesce(nullif(v_ship.cargo_conversion_rate, 0), 1.0),
    jsonb_build_object('source', 'header_backfill')
  );
end;
$$;

revoke all on function public.ensure_global_shipment_cost_entries_from_header(bigint) from public;
grant execute on function public.ensure_global_shipment_cost_entries_from_header(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Stamp helper (from cost entries — parity with landedCost.ts / v2 schema §3)
-- ---------------------------------------------------------------------------
create or replace function public.stamp_global_shipment_landed_costs(p_shipment_id bigint)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_product_amount numeric := 0;
  v_cargo_amount numeric := 0;
  v_goods_bdt numeric := 0;
  v_cargo_bdt numeric := 0;
  v_blended numeric := 1;
  v_pack_kg numeric := 0;
  v_cargo_kg numeric := 0;
  v_updated integer := 0;
  r record;
  v_line_gross numeric;
  v_line_cargo_share numeric;
  v_unit_base numeric;
  v_landed numeric;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  select
    coalesce(sum(amount) filter (where cost_type = 'product'), 0),
    coalesce(sum(amount * exchange_rate) filter (where cost_type = 'product'), 0),
    coalesce(sum(amount) filter (where cost_type = 'cargo'), 0),
    coalesce(sum(amount * exchange_rate) filter (where cost_type = 'cargo'), 0)
  into v_product_amount, v_goods_bdt, v_cargo_amount, v_cargo_bdt
  from public.global_shipment_cost_entries
  where shipment_id = p_shipment_id;

  if (v_product_amount + v_cargo_amount) > 0 then
    v_blended := (v_goods_bdt + v_cargo_bdt) / (v_product_amount + v_cargo_amount);
  elsif v_ship.type = 'international' then
    v_blended := (
      coalesce(nullif(v_ship.product_conversion_rate, 0), 1)
      + coalesce(nullif(v_ship.cargo_conversion_rate, 0), 1)
    ) / 2.0;
  else
    v_blended := 1;
  end if;

  select coalesce(sum(
    ((coalesce(gsi.product_weight, 0) + coalesce(gsi.package_weight, 0)) * gsi.ordered_quantity) / 1000.0
  ), 0)
  into v_pack_kg
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  v_cargo_kg := case
    when v_ship.received_weight is not null and v_ship.received_weight > 0 then v_ship.received_weight
    else v_pack_kg
  end;

  perform set_config('app.allow_landed_cost_stamp', '1', true);

  for r in
    select *
    from public.global_shipment_items
    where shipment_id = p_shipment_id
  loop
    v_line_gross := (
      (coalesce(r.product_weight, 0) + coalesce(r.package_weight, 0)) * r.ordered_quantity
    ) / 1000.0;

    if v_pack_kg > 0 then
      v_line_cargo_share := (v_line_gross / v_pack_kg) * v_cargo_amount;
    elsif (select coalesce(sum(ordered_quantity), 0) from public.global_shipment_items where shipment_id = p_shipment_id) > 0 then
      v_line_cargo_share := (r.ordered_quantity::numeric
        / (select sum(ordered_quantity) from public.global_shipment_items where shipment_id = p_shipment_id)
      ) * v_cargo_amount;
    else
      v_line_cargo_share := 0;
    end if;

    if r.ordered_quantity > 0 then
      v_unit_base := coalesce(r.purchase_price, 0) + (v_line_cargo_share / r.ordered_quantity);
    else
      v_unit_base := coalesce(r.purchase_price, 0);
    end if;

    if v_ship.type = 'domestic' then
      v_landed := v_unit_base;
    else
      v_landed := v_unit_base * v_blended;
    end if;

    update public.global_shipment_items
    set landed_cost_bdt = round(v_landed::numeric, 4)
    where id = r.id;

    v_updated := v_updated + 1;
  end loop;

  return v_updated;
end;
$$;

revoke all on function public.stamp_global_shipment_landed_costs(bigint) from public;
grant execute on function public.stamp_global_shipment_landed_costs(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Backfill: entries for all shipments; stamp Ready Stock
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in select id from public.global_shipments
  loop
    perform public.ensure_global_shipment_cost_entries_from_header(r.id);
  end loop;

  for r in select id from public.global_shipments where stock_ready = true
  loop
    perform public.stamp_global_shipment_landed_costs(r.id);
  end loop;
end $$;

commit;

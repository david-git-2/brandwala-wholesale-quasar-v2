-- B5: global_accounting_ledger, rollups, legacy stock migration
begin;

create table if not exists public.global_accounting_ledger (
  id bigserial primary key,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  sold_in_tenant_id bigint null references public.tenants(id) on delete set null,
  global_invoice_id bigint null references public.global_invoices(id) on delete set null,
  global_invoice_item_id bigint null references public.global_invoice_items(id) on delete set null,
  global_stock_id bigint null references public.global_stocks(id) on delete set null,
  shipment_id bigint null references public.shipments(id) on delete set null,
  shipment_item_id bigint null references public.shipment_items(id) on delete set null,
  product_id bigint null references public.products(id) on delete set null,
  quantity numeric(12,3) not null default 0,
  return_quantity numeric(12,3) not null default 0,
  return_amount numeric(12,2) not null default 0,
  cost_amount numeric(12,2) not null default 0,
  sell_price_amount numeric(12,2) not null default 0,
  total_cost_amount numeric(12,2) not null default 0,
  total_sell_amount numeric(12,2) not null default 0,
  gross_profit_amount numeric(12,2) not null default 0,
  is_charge boolean not null default false,
  charge_type public.invoice_charge_type null,
  status text not null default 'due' check (status in ('due', 'paid')),
  entry_date date not null default current_date,
  note text null,
  created_by uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists global_accounting_ledger_parent_idx on public.global_accounting_ledger (parent_tenant_id);
create index if not exists global_accounting_ledger_tenant_idx on public.global_accounting_ledger (tenant_id);
create index if not exists global_accounting_ledger_invoice_idx on public.global_accounting_ledger (global_invoice_id);

create table if not exists public.global_shipment_accounting (
  id bigserial primary key,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  shipment_id bigint not null references public.shipments(id) on delete cascade,
  buy_cost_total numeric(12,2) not null default 0,
  sell_total numeric(12,2) not null default 0,
  gross_profit_total numeric(12,2) not null default 0,
  refreshed_at timestamptz not null default now(),
  constraint global_shipment_accounting_unique unique (tenant_id, shipment_id)
);

create table if not exists public.global_invoice_accounting (
  id bigserial primary key,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  global_invoice_id bigint not null references public.global_invoices(id) on delete cascade,
  subtotal_amount numeric(12,2) not null default 0,
  charge_total numeric(12,2) not null default 0,
  discount_amount numeric(12,2) not null default 0,
  total_amount numeric(12,2) not null default 0,
  gross_profit_total numeric(12,2) not null default 0,
  refreshed_at timestamptz not null default now(),
  constraint global_invoice_accounting_unique unique (global_invoice_id)
);

drop trigger if exists trg_global_accounting_ledger_set_updated_at on public.global_accounting_ledger;
create trigger trg_global_accounting_ledger_set_updated_at
before update on public.global_accounting_ledger
for each row execute function public.set_updated_at();

alter table public.global_accounting_ledger enable row level security;
alter table public.global_shipment_accounting enable row level security;
alter table public.global_invoice_accounting enable row level security;

drop policy if exists global_accounting_ledger_select on public.global_accounting_ledger;
create policy global_accounting_ledger_select on public.global_accounting_ledger
for select to authenticated
using (
  public.user_can_manage_parent_tenant(parent_tenant_id)
  or exists (
    select 1 from public.memberships m
    where m.tenant_id = global_accounting_ledger.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists global_accounting_ledger_write on public.global_accounting_ledger;
create policy global_accounting_ledger_write on public.global_accounting_ledger
for all to authenticated
using (public.user_can_manage_parent_tenant(parent_tenant_id))
with check (public.user_can_manage_parent_tenant(parent_tenant_id));

drop policy if exists global_shipment_accounting_select on public.global_shipment_accounting;
create policy global_shipment_accounting_select on public.global_shipment_accounting
for select to authenticated using (public.user_can_manage_parent_tenant(parent_tenant_id));

drop policy if exists global_invoice_accounting_select on public.global_invoice_accounting;
create policy global_invoice_accounting_select on public.global_invoice_accounting
for select to authenticated
using (
  public.user_can_manage_parent_tenant(parent_tenant_id)
  or exists (
    select 1 from public.memberships m
    where m.tenant_id = global_invoice_accounting.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

-- Migrate legacy inventory_items -> global_stocks (one-time, idempotent via legacy_inventory_item_id)
create or replace function public.migrate_legacy_inventory_to_global_stock(
  p_tenant_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
  v_stock_id bigint;
  v_parent_id bigint;
  v_migrated integer := 0;
begin
  for v_item in
    select ii.*
    from public.inventory_items ii
    where (p_tenant_id is null or ii.tenant_id = p_tenant_id)
      and not exists (
        select 1 from public.global_stocks gs
        where gs.legacy_inventory_item_id = ii.id
      )
  loop
    v_parent_id := public.resolve_parent_tenant_id(v_item.tenant_id);

    insert into public.global_stocks (
      tenant_id,
      parent_tenant_id,
      name,
      cost,
      image_url,
      product_code,
      barcode,
      product_id,
      source_module,
      source_type,
      source_id,
      legacy_inventory_item_id
    )
    values (
      v_parent_id,
      v_parent_id,
      v_item.name,
      coalesce(v_item.cost, 0),
      v_item.image_url,
      v_item.product_code,
      v_item.barcode,
      v_item.product_id,
      'wholesale',
      coalesce(v_item.source_type, 'migration'),
      v_item.source_id,
      v_item.id
    )
    returning id into v_stock_id;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'excellent', coalesce(s.available_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.available_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'box_less', coalesce(s.open_box_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.open_box_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'expired', coalesce(s.expired_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.expired_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'stolen', coalesce(s.stolen_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.stolen_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    v_migrated := v_migrated + 1;
  end loop;

  return jsonb_build_object('migrated_count', v_migrated);
end;
$$;

grant execute on function public.migrate_legacy_inventory_to_global_stock(bigint) to authenticated;

create or replace function public.refresh_global_shipment_accounting(
  p_parent_tenant_id bigint,
  p_shipment_id bigint
)
returns public.global_shipment_accounting
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.global_shipment_accounting;
  v_buy numeric(12,2);
  v_sell numeric(12,2);
  v_profit numeric(12,2);
begin
  if not public.user_can_manage_parent_tenant(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  select
    coalesce(sum(l.total_cost_amount), 0),
    coalesce(sum(l.total_sell_amount), 0),
    coalesce(sum(l.gross_profit_amount), 0)
  into v_buy, v_sell, v_profit
  from public.global_accounting_ledger l
  where l.parent_tenant_id = p_parent_tenant_id
    and l.shipment_id = p_shipment_id;

  insert into public.global_shipment_accounting (
    parent_tenant_id,
    tenant_id,
    shipment_id,
    buy_cost_total,
    sell_total,
    gross_profit_total
  )
  values (
    p_parent_tenant_id,
    p_parent_tenant_id,
    p_shipment_id,
    v_buy,
    v_sell,
    v_profit
  )
  on conflict (tenant_id, shipment_id)
  do update set
    buy_cost_total = excluded.buy_cost_total,
    sell_total = excluded.sell_total,
    gross_profit_total = excluded.gross_profit_total,
    refreshed_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.refresh_global_shipment_accounting(bigint, bigint) to authenticated;

create or replace function public.refresh_global_invoice_accounting(
  p_global_invoice_id bigint
)
returns public.global_invoice_accounting
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_row public.global_invoice_accounting;
  v_charge_total numeric(12,2);
  v_profit numeric(12,2);
begin
  select * into v_invoice from public.global_invoices where id = p_global_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;

  select coalesce(sum(amount), 0) into v_charge_total
  from public.invoice_charge_lines
  where invoice_id = p_global_invoice_id;

  select coalesce(sum(gross_profit_amount), 0) into v_profit
  from public.global_accounting_ledger
  where global_invoice_id = p_global_invoice_id;

  insert into public.global_invoice_accounting (
    parent_tenant_id,
    tenant_id,
    global_invoice_id,
    subtotal_amount,
    charge_total,
    discount_amount,
    total_amount,
    gross_profit_total
  )
  values (
    v_invoice.parent_tenant_id,
    v_invoice.tenant_id,
    p_global_invoice_id,
    v_invoice.subtotal_amount,
    v_charge_total,
    v_invoice.discount_amount,
    v_invoice.total_amount + v_charge_total,
    v_profit
  )
  on conflict (global_invoice_id)
  do update set
    subtotal_amount = excluded.subtotal_amount,
    charge_total = excluded.charge_total,
    discount_amount = excluded.discount_amount,
    total_amount = excluded.total_amount,
    gross_profit_total = excluded.gross_profit_total,
    refreshed_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.refresh_global_invoice_accounting(bigint) to authenticated;

create or replace function public.list_global_accounting_ledger(
  p_parent_tenant_id bigint,
  p_tenant_id bigint default null,
  p_limit integer default 100,
  p_offset integer default 0
)
returns setof public.global_accounting_ledger
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.user_can_manage_parent_tenant(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  select *
  from public.global_accounting_ledger l
  where l.parent_tenant_id = p_parent_tenant_id
    and (p_tenant_id is null or l.tenant_id = p_tenant_id)
  order by l.entry_date desc, l.id desc
  limit greatest(coalesce(p_limit, 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

grant execute on function public.list_global_accounting_ledger(bigint, bigint, integer, integer) to authenticated;

-- Post ledger entry when global invoice item is added (trigger-style via RPC extension)
create or replace function public.post_global_invoice_item_to_ledger(
  p_invoice_item_id bigint
)
returns public.global_accounting_ledger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.global_invoice_items;
  v_invoice public.global_invoices;
  v_row public.global_accounting_ledger;
begin
  select * into v_item from public.global_invoice_items where id = p_invoice_item_id;
  if v_item.id is null then raise exception 'invoice item not found'; end if;

  select * into v_invoice from public.global_invoices where id = v_item.invoice_id;

  insert into public.global_accounting_ledger (
    parent_tenant_id,
    tenant_id,
    sold_in_tenant_id,
    global_invoice_id,
    global_invoice_item_id,
    global_stock_id,
    product_id,
    quantity,
    cost_amount,
    sell_price_amount,
    total_cost_amount,
    total_sell_amount,
    gross_profit_amount,
    status,
    entry_date,
    note
  )
  values (
    v_invoice.parent_tenant_id,
    v_invoice.tenant_id,
    v_invoice.sold_in_tenant_id,
    v_invoice.id,
    v_item.id,
    v_item.global_stock_id,
    v_item.product_id,
    v_item.quantity,
    v_item.cost_amount,
    v_item.sell_price_amount,
    v_item.cost_amount * v_item.quantity,
    v_item.sell_price_amount * v_item.quantity,
    (v_item.sell_price_amount - v_item.cost_amount) * v_item.quantity,
    case when v_invoice.payment_status = 'paid' then 'paid' else 'due' end,
    current_date,
    'Global invoice item'
  )
  returning * into v_row;

  perform public.refresh_global_invoice_accounting(v_invoice.id);

  return v_row;
end;
$$;

grant execute on function public.post_global_invoice_item_to_ledger(bigint) to authenticated;

commit;

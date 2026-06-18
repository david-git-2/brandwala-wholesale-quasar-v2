-- B4: global_invoices, items, returns, charge lines, fresh-insert RPCs
begin;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'global_invoice_type') then
    create type public.global_invoice_type as enum ('retail', 'wholesale');
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'invoice_charge_type') then
    create type public.invoice_charge_type as enum (
      'cod',
      'packing',
      'print',
      'delivery',
      'other'
    );
  end if;
end $$;

create table if not exists public.global_invoices (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  invoice_no text not null,
  invoice_type public.global_invoice_type not null default 'wholesale',
  source_module public.global_source_module not null default 'wholesale',
  payment_status text not null default 'due' check (payment_status in ('due', 'partially_paid', 'paid')),
  invoice_date date not null default current_date,
  due_date date null,
  subtotal_amount numeric(12,2) not null default 0 check (subtotal_amount >= 0),
  discount_amount numeric(12,2) not null default 0 check (discount_amount >= 0),
  total_amount numeric(12,2) not null default 0 check (total_amount >= 0),
  paid_amount numeric(12,2) not null default 0 check (paid_amount >= 0),
  due_amount numeric(12,2) not null default 0 check (due_amount >= 0),
  ordered_by_party_id bigint null references public.business_parties(id) on delete set null,
  recipient_party_id bigint null references public.business_parties(id) on delete set null,
  customer_group_id bigint null references public.customer_groups(id) on delete set null,
  sold_in_tenant_id bigint null references public.tenants(id) on delete set null,
  note text null,
  created_by uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, invoice_no)
);

create index if not exists global_invoices_tenant_id_idx on public.global_invoices (tenant_id);
create index if not exists global_invoices_parent_tenant_id_idx on public.global_invoices (parent_tenant_id);

create table if not exists public.global_invoice_items (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  invoice_id bigint not null references public.global_invoices(id) on delete cascade,
  global_stock_id bigint not null references public.global_stocks(id) on delete restrict,
  product_id bigint null references public.products(id) on delete set null,
  name_snapshot text not null,
  barcode_snapshot text null,
  product_code_snapshot text null,
  quantity numeric(12,3) not null check (quantity > 0),
  cost_amount numeric(12,2) not null default 0 check (cost_amount >= 0),
  sell_price_amount numeric(12,2) not null default 0 check (sell_price_amount >= 0),
  line_discount_amount numeric(12,2) not null default 0 check (line_discount_amount >= 0),
  line_tax_amount numeric(12,2) not null default 0 check (line_tax_amount >= 0),
  line_total_amount numeric(12,2) not null default 0 check (line_total_amount >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists global_invoice_items_invoice_id_idx on public.global_invoice_items (invoice_id);
create index if not exists global_invoice_items_global_stock_id_idx on public.global_invoice_items (global_stock_id);

create table if not exists public.global_return_items (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  invoice_id bigint not null references public.global_invoices(id) on delete cascade,
  invoice_item_id bigint not null references public.global_invoice_items(id) on delete cascade,
  global_stock_id bigint not null references public.global_stocks(id) on delete restrict,
  quantity numeric(12,3) not null check (quantity > 0),
  return_amount numeric(12,2) not null default 0 check (return_amount >= 0),
  note text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.invoice_charge_lines (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  invoice_id bigint not null references public.global_invoices(id) on delete cascade,
  charge_type public.invoice_charge_type not null,
  amount numeric(12,2) not null default 0 check (amount >= 0),
  posted_to_ledger boolean not null default false,
  note text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists invoice_charge_lines_invoice_id_idx on public.invoice_charge_lines (invoice_id);

alter table public.invoice_charge_lines
  drop constraint if exists invoice_charge_lines_invoice_charge_unique;

alter table public.invoice_charge_lines
  add constraint invoice_charge_lines_invoice_charge_unique unique (invoice_id, charge_type);

drop trigger if exists trg_global_invoices_set_updated_at on public.global_invoices;
create trigger trg_global_invoices_set_updated_at
before update on public.global_invoices
for each row execute function public.set_updated_at();

drop trigger if exists trg_global_invoice_items_set_updated_at on public.global_invoice_items;
create trigger trg_global_invoice_items_set_updated_at
before update on public.global_invoice_items
for each row execute function public.set_updated_at();

drop trigger if exists trg_global_return_items_set_updated_at on public.global_return_items;
create trigger trg_global_return_items_set_updated_at
before update on public.global_return_items
for each row execute function public.set_updated_at();

drop trigger if exists trg_invoice_charge_lines_set_updated_at on public.invoice_charge_lines;
create trigger trg_invoice_charge_lines_set_updated_at
before update on public.invoice_charge_lines
for each row execute function public.set_updated_at();

alter table public.global_invoices enable row level security;
alter table public.global_invoice_items enable row level security;
alter table public.global_return_items enable row level security;
alter table public.invoice_charge_lines enable row level security;

drop policy if exists global_invoices_select on public.global_invoices;
create policy global_invoices_select on public.global_invoices
for select to authenticated
using (
  public.user_can_manage_parent_tenant(parent_tenant_id)
  or exists (
    select 1 from public.memberships m
    where m.tenant_id = global_invoices.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists global_invoices_write on public.global_invoices;
create policy global_invoices_write on public.global_invoices
for all to authenticated
using (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = global_invoices.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
  or public.user_can_manage_parent_tenant(parent_tenant_id)
)
with check (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = global_invoices.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
  or public.user_can_manage_parent_tenant(parent_tenant_id)
);

drop policy if exists global_invoice_items_all on public.global_invoice_items;
create policy global_invoice_items_all on public.global_invoice_items
for all to authenticated
using (
  exists (select 1 from public.global_invoices gi where gi.id = global_invoice_items.invoice_id)
)
with check (
  exists (select 1 from public.global_invoices gi where gi.id = global_invoice_items.invoice_id)
);

drop policy if exists global_return_items_all on public.global_return_items;
create policy global_return_items_all on public.global_return_items
for all to authenticated
using (true) with check (true);

drop policy if exists invoice_charge_lines_all on public.invoice_charge_lines;
create policy invoice_charge_lines_all on public.invoice_charge_lines
for all to authenticated
using (true) with check (true);

create or replace function public.create_global_invoice(
  p_tenant_id bigint,
  p_invoice_no text,
  p_invoice_type public.global_invoice_type default 'wholesale',
  p_source_module public.global_source_module default 'wholesale',
  p_customer_group_id bigint default null,
  p_ordered_by_party_id bigint default null,
  p_recipient_party_id bigint default null,
  p_note text default null
)
returns public.global_invoices
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.global_invoices;
  v_parent_id bigint;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'not allowed';
  end if;

  insert into public.global_invoices (
    tenant_id,
    parent_tenant_id,
    invoice_no,
    invoice_type,
    source_module,
    customer_group_id,
    ordered_by_party_id,
    recipient_party_id,
    sold_in_tenant_id,
    note,
    due_amount
  )
  values (
    p_tenant_id,
    v_parent_id,
    trim(p_invoice_no),
    coalesce(p_invoice_type, 'wholesale'),
    coalesce(p_source_module, 'wholesale'),
    p_customer_group_id,
    p_ordered_by_party_id,
    p_recipient_party_id,
    p_tenant_id,
    nullif(trim(coalesce(p_note, '')), ''),
    0
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.create_global_invoice(bigint, text, public.global_invoice_type, public.global_source_module, bigint, bigint, bigint, text) to authenticated;

create or replace function public.add_global_invoice_item(
  p_invoice_id bigint,
  p_global_stock_id bigint,
  p_quantity numeric,
  p_sell_price_amount numeric,
  p_line_discount_amount numeric default 0
)
returns public.global_invoice_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_stock public.global_stocks;
  v_row public.global_invoice_items;
  v_line_total numeric(12,2);
  v_status public.global_stock_status := 'excellent';
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;

  select * into v_stock from public.global_stocks where id = p_global_stock_id;
  if v_stock.id is null then raise exception 'stock not found'; end if;

  if v_stock.parent_tenant_id <> v_invoice.parent_tenant_id then
    raise exception 'stock does not belong to invoice parent tenant';
  end if;

  v_line_total := greatest((p_quantity * p_sell_price_amount) - coalesce(p_line_discount_amount, 0), 0);

  insert into public.global_invoice_items (
    tenant_id,
    parent_tenant_id,
    invoice_id,
    global_stock_id,
    product_id,
    name_snapshot,
    barcode_snapshot,
    product_code_snapshot,
    quantity,
    cost_amount,
    sell_price_amount,
    line_discount_amount,
    line_total_amount
  )
  values (
    v_invoice.tenant_id,
    v_invoice.parent_tenant_id,
    p_invoice_id,
    p_global_stock_id,
    v_stock.product_id,
    v_stock.name,
    v_stock.barcode,
    v_stock.product_code,
    p_quantity,
    v_stock.cost,
    p_sell_price_amount,
    coalesce(p_line_discount_amount, 0),
    v_line_total
  )
  returning * into v_row;

  update public.global_stock_quantities
  set quantity = greatest(quantity - ceil(p_quantity)::integer, 0)
  where stock_id = p_global_stock_id and status = v_status;

  update public.global_invoices gi
  set
    subtotal_amount = gi.subtotal_amount + v_line_total,
    total_amount = gi.subtotal_amount + v_line_total - gi.discount_amount,
    due_amount = greatest((gi.subtotal_amount + v_line_total - gi.discount_amount) - gi.paid_amount, 0)
  where gi.id = p_invoice_id;

  return v_row;
end;
$$;

grant execute on function public.add_global_invoice_item(bigint, bigint, numeric, numeric, numeric) to authenticated;

create or replace function public.upsert_invoice_charge_line(
  p_invoice_id bigint,
  p_charge_type public.invoice_charge_type,
  p_amount numeric,
  p_note text default null
)
returns public.invoice_charge_lines
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_row public.invoice_charge_lines;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;

  insert into public.invoice_charge_lines (
    tenant_id,
    parent_tenant_id,
    invoice_id,
    charge_type,
    amount,
    note
  )
  values (
    v_invoice.tenant_id,
    v_invoice.parent_tenant_id,
    p_invoice_id,
    p_charge_type,
    greatest(coalesce(p_amount, 0), 0),
    nullif(trim(coalesce(p_note, '')), '')
  )
  on conflict do nothing
  returning * into v_row;

  if v_row.id is null then
    update public.invoice_charge_lines
    set amount = greatest(coalesce(p_amount, 0), 0),
        note = nullif(trim(coalesce(p_note, '')), '')
    where invoice_id = p_invoice_id and charge_type = p_charge_type
    returning * into v_row;
  end if;

  return v_row;
end;
$$;

grant execute on function public.upsert_invoice_charge_line(bigint, public.invoice_charge_type, numeric, text) to authenticated;

commit;

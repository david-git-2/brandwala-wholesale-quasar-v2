-- =========================================================
-- Thrift Module schema + triggers + RLS + RPC automation
-- =========================================================

begin;

-- -------------------------
-- 1. Custom Enum Types
-- -------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'thrift_section') then
    create type public.thrift_section as enum ('MALE', 'FEMALE', 'UNISEX', 'KIDS', 'HOME');
  end if;

  if not exists (select 1 from pg_type where typname = 'thrift_condition') then
    create type public.thrift_condition as enum ('NEW_WITH_TAGS', 'EXCELLENT', 'GOOD', 'FAIR');
  end if;

  if not exists (select 1 from pg_type where typname = 'thrift_stock_type') then
    create type public.thrift_stock_type as enum ('SINGLE', 'BULK');
  end if;

  if not exists (select 1 from pg_type where typname = 'thrift_stock_status') then
    create type public.thrift_stock_status as enum ('AVAILABLE', 'OUT_OF_STOCK', 'DAMAGED', 'STOLEN');
  end if;

  if not exists (select 1 from pg_type where typname = 'thrift_transaction_method') then
    create type public.thrift_transaction_method as enum ('CASH', 'CARD', 'MOBILE_BANKING', 'COD');
  end if;

  if not exists (select 1 from pg_type where typname = 'thrift_delivery_status') then
    create type public.thrift_delivery_status as enum ('PENDING', 'SHIPPED', 'DELIVERED', 'RETURNED', 'PARTIALLY_RETURNED');
  end if;

  if not exists (select 1 from pg_type where typname = 'thrift_payment_status') then
    create type public.thrift_payment_status as enum ('UNPAID', 'PAID', 'REFUNDED');
  end if;

  if not exists (select 1 from pg_type where typname = 'thrift_item_status') then
    create type public.thrift_item_status as enum ('SOLD', 'RETURNED');
  end if;

  if not exists (select 1 from pg_type where typname = 'thrift_return_action') then
    create type public.thrift_return_action as enum ('RESTOCK', 'WRITE_OFF');
  end if;

  if not exists (select 1 from pg_type where typname = 'thrift_ledger_type') then
    create type public.thrift_ledger_type as enum ('REVENUE', 'EXPENSE', 'REFUND', 'LOSS');
  end if;

  if not exists (select 1 from pg_type where typname = 'thrift_ledger_source') then
    create type public.thrift_ledger_source as enum ('INVOICE', 'SHIPMENT', 'OPERATIONAL');
  end if;
end
$$;

-- -------------------------
-- 2. Core Tables
-- -------------------------

create table if not exists public.thrift_categories (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  description text null,
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint thrift_categories_name_tenant_unique unique (tenant_id, name)
);

create table if not exists public.thrift_types (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  description text null,
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint thrift_types_name_tenant_unique unique (tenant_id, name)
);

create table if not exists public.thrift_shelves (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  location_bay text null,
  shelf_code text not null,
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint thrift_shelves_code_tenant_unique unique (tenant_id, shelf_code)
);

create table if not exists public.thrift_stocks (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  shipment_id bigint not null references public.shipments(id) on delete cascade,
  name text not null,
  brand_name text null,
  category_id bigint not null references public.thrift_categories(id),
  type_id bigint not null references public.thrift_types(id),
  section public.thrift_section not null,
  shelf_id bigint not null references public.thrift_shelves(id),
  color text not null,
  size text not null,
  condition public.thrift_condition not null,
  sku text not null,
  stock_type public.thrift_stock_type not null default 'SINGLE',
  quantity integer not null default 1 check (quantity >= 0),
  weight_gm integer null check (weight_gm >= 0),
  status public.thrift_stock_status not null default 'AVAILABLE',
  note text null,
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint thrift_stocks_sku_tenant_unique unique (tenant_id, sku)
);

create table if not exists public.thrift_stock_images (
  id bigserial primary key,
  stock_id bigint not null references public.thrift_stocks(id) on delete cascade,
  image_url text not null,
  is_primary boolean not null default false,
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.thrift_pricings (
  id bigserial primary key,
  stock_id bigint not null unique references public.thrift_stocks(id) on delete cascade,
  cost_of_goods_sold numeric(12, 2) not null default 0.00 check (cost_of_goods_sold >= 0),
  target_price numeric(12, 2) not null default 0.00 check (target_price >= 0),
  listed_price numeric(12, 2) not null default 0.00 check (listed_price >= 0),
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.thrift_invoices (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  invoice_number text not null,
  recipient_name text not null,
  address text not null,
  phone text not null,
  transaction_method public.thrift_transaction_method not null,
  delivery_status public.thrift_delivery_status not null default 'PENDING',
  payment_status public.thrift_payment_status not null default 'UNPAID',
  cod_charge numeric(12, 2) not null default 0.00 check (cod_charge >= 0),
  packing_charge numeric(12, 2) not null default 0.00 check (packing_charge >= 0),
  invoice_print_charge numeric(12, 2) not null default 0.00 check (invoice_print_charge >= 0),
  shipping_charge_customer numeric(12, 2) not null default 0.00 check (shipping_charge_customer >= 0),
  total_invoice_amount numeric(12, 2) not null default 0.00 check (total_invoice_amount >= 0),
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint thrift_invoices_number_tenant_unique unique (tenant_id, invoice_number)
);

create table if not exists public.thrift_invoice_items (
  id bigserial primary key,
  invoice_id bigint not null references public.thrift_invoices(id) on delete cascade,
  stock_id bigint not null references public.thrift_stocks(id),
  quantity integer not null check (quantity > 0),
  sold_price numeric(12, 2) not null default 0.00 check (sold_price >= 0),
  platform_fees numeric(12, 2) not null default 0.00 check (platform_fees >= 0),
  shipping_cost_paid_by_shop numeric(12, 2) not null default 0.00 check (shipping_cost_paid_by_shop >= 0),
  item_status public.thrift_item_status not null default 'SOLD',
  return_reason text null,
  return_cost_charged_to_customer numeric(12, 2) not null default 0.00 check (return_cost_charged_to_customer >= 0),
  return_cost_paid_by_shop numeric(12, 2) not null default 0.00 check (return_cost_paid_by_shop >= 0),
  return_action public.thrift_return_action null,
  net_profit numeric(12, 2) not null default 0.00,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.thrift_accounting_ledger (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  type public.thrift_ledger_type not null,
  source public.thrift_ledger_source not null,
  reference_id bigint not null,
  amount numeric(12, 2) not null check (amount >= 0),
  date timestamptz not null default now(),
  inserted_by text not null,
  note text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- -------------------------
-- 3. Triggers for updated_at
-- -------------------------

create trigger trg_thrift_categories_updated_at
before update on public.thrift_categories
for each row execute function public.set_updated_at();

create trigger trg_thrift_types_updated_at
before update on public.thrift_types
for each row execute function public.set_updated_at();

create trigger trg_thrift_shelves_updated_at
before update on public.thrift_shelves
for each row execute function public.set_updated_at();

create trigger trg_thrift_stocks_updated_at
before update on public.thrift_stocks
for each row execute function public.set_updated_at();

create trigger trg_thrift_stock_images_updated_at
before update on public.thrift_stock_images
for each row execute function public.set_updated_at();

create trigger trg_thrift_pricings_updated_at
before update on public.thrift_pricings
for each row execute function public.set_updated_at();

create trigger trg_thrift_invoices_updated_at
before update on public.thrift_invoices
for each row execute function public.set_updated_at();

create trigger trg_thrift_invoice_items_updated_at
before update on public.thrift_invoice_items
for each row execute function public.set_updated_at();

create trigger trg_thrift_accounting_ledger_updated_at
before update on public.thrift_accounting_ledger
for each row execute function public.set_updated_at();

-- -------------------------
-- 4. Calculation Trigger Functions & Triggers
-- -------------------------

-- Net Profit Calculation Trigger
create or replace function public.calculate_thrift_item_net_profit()
returns trigger
language plpgsql
security definer
as $$
declare
  v_cogs numeric(12, 2);
begin
  select coalesce(cost_of_goods_sold, 0.00) into v_cogs
  from public.thrift_pricings
  where stock_id = new.stock_id;

  if not found then
    v_cogs := 0.00;
  end if;

  new.net_profit := (new.sold_price - v_cogs) * new.quantity 
                    - new.platform_fees 
                    - new.shipping_cost_paid_by_shop;

  return new;
end;
$$;

create trigger trg_thrift_invoice_items_profit
before insert or update on public.thrift_invoice_items
for each row execute function public.calculate_thrift_item_net_profit();

-- Total Invoice Amount Calculation Trigger
create or replace function public.calculate_thrift_invoice_total()
returns trigger
language plpgsql
security definer
as $$
declare
  v_invoice_id bigint;
begin
  if tg_op = 'DELETE' then
    v_invoice_id := old.invoice_id;
  else
    v_invoice_id := new.invoice_id;
  end if;

  update public.thrift_invoices
  set total_invoice_amount = coalesce((
    select sum(sold_price * quantity)
    from public.thrift_invoice_items
    where invoice_id = v_invoice_id
  ), 0.00) 
  + cod_charge 
  + packing_charge 
  + invoice_print_charge 
  + shipping_charge_customer
  where id = v_invoice_id;

  return null;
end;
$$;

create trigger trg_thrift_invoice_items_total
after insert or update or delete on public.thrift_invoice_items
for each row execute function public.calculate_thrift_invoice_total();

-- Stock Loss Auto-Ledger Trigger
create or replace function public.log_thrift_stock_loss_ledger()
returns trigger
language plpgsql
security definer
as $$
declare
  v_cogs numeric(12, 2);
begin
  if (new.status in ('DAMAGED'::public.thrift_stock_status, 'STOLEN'::public.thrift_stock_status))
     and (old.status is null or old.status <> new.status) then
     
    select coalesce(cost_of_goods_sold, 0.00) into v_cogs
    from public.thrift_pricings
    where stock_id = new.id;

    if v_cogs > 0 then
      insert into public.thrift_accounting_ledger (
        tenant_id,
        type,
        source,
        reference_id,
        amount,
        inserted_by,
        note
      )
      values (
        new.tenant_id,
        'LOSS'::public.thrift_ledger_type,
        'SHIPMENT'::public.thrift_ledger_source,
        new.shipment_id,
        v_cogs * new.quantity,
        new.inserted_by,
        'Auto-logged loss for stock item status set to ' || new.status || ' (SKU: ' || new.sku || ')'
      );
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_thrift_stock_loss_ledger
after update on public.thrift_stocks
for each row execute function public.log_thrift_stock_loss_ledger();

-- -------------------------
-- 5. "Mark as Sold" RPC
-- -------------------------

create or replace function public.mark_thrift_items_as_sold(
  p_tenant_id bigint,
  p_invoice_number text,
  p_recipient_name text,
  p_address text,
  p_phone text,
  p_transaction_method public.thrift_transaction_method,
  p_cod_charge numeric,
  p_packing_charge numeric,
  p_invoice_print_charge numeric,
  p_shipping_charge_customer numeric,
  p_inserted_by text,
  p_items jsonb
)
returns bigint
language plpgsql
security definer
as $$
declare
  v_invoice_id bigint;
  v_item jsonb;
  v_stock_id bigint;
  v_qty integer;
  v_sold_price numeric(12,2);
  v_platform_fees numeric(12,2);
  v_ship_paid_by_shop numeric(12,2);
  v_available_qty integer;
  v_total_ship_paid_by_shop numeric(12,2) := 0.00;
begin
  -- 1. Insert Invoice
  insert into public.thrift_invoices (
    tenant_id,
    invoice_number,
    recipient_name,
    address,
    phone,
    transaction_method,
    cod_charge,
    packing_charge,
    invoice_print_charge,
    shipping_charge_customer,
    inserted_by
  )
  values (
    p_tenant_id,
    p_invoice_number,
    p_recipient_name,
    p_address,
    p_phone,
    p_transaction_method,
    p_cod_charge,
    p_packing_charge,
    p_invoice_print_charge,
    p_shipping_charge_customer,
    p_inserted_by
  )
  returning id into v_invoice_id;

  -- 2. Process items
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_stock_id := (v_item->>'stock_id')::bigint;
    v_qty := (v_item->>'quantity')::integer;
    v_sold_price := (v_item->>'sold_price')::numeric;
    v_platform_fees := coalesce((v_item->>'platform_fees')::numeric, 0.00);
    v_ship_paid_by_shop := coalesce((v_item->>'shipping_cost_paid_by_shop')::numeric, 0.00);

    v_total_ship_paid_by_shop := v_total_ship_paid_by_shop + v_ship_paid_by_shop;

    -- Qty validation
    select quantity into v_available_qty
    from public.thrift_stocks
    where id = v_stock_id and tenant_id = p_tenant_id;

    if v_available_qty < v_qty then
      raise exception 'Insufficient stock for stock ID %', v_stock_id;
    end if;

    -- Add item to invoice
    insert into public.thrift_invoice_items (
      invoice_id,
      stock_id,
      quantity,
      sold_price,
      platform_fees,
      shipping_cost_paid_by_shop,
      item_status
    )
    values (
      v_invoice_id,
      v_stock_id,
      v_qty,
      v_sold_price,
      v_platform_fees,
      v_ship_paid_by_shop,
      'SOLD'::public.thrift_item_status
    );

    -- Deduct stock qty
    update public.thrift_stocks
    set 
      quantity = quantity - v_qty,
      status = case when (quantity - v_qty) = 0 then 'OUT_OF_STOCK'::public.thrift_stock_status else status end,
      updated_at = now()
    where id = v_stock_id;
  end loop;

  -- 3. Log Revenue (accrual basis)
  insert into public.thrift_accounting_ledger (
    tenant_id,
    type,
    source,
    reference_id,
    amount,
    inserted_by,
    note
  )
  select 
    p_tenant_id,
    'REVENUE'::public.thrift_ledger_type,
    'INVOICE'::public.thrift_ledger_source,
    v_invoice_id,
    total_invoice_amount,
    p_inserted_by,
    'Auto-logged revenue from Thrift Invoice #' || invoice_number
  from public.thrift_invoices
  where id = v_invoice_id;

  -- 4. Log Shipping Expense (if applicable)
  if v_total_ship_paid_by_shop > 0 then
    insert into public.thrift_accounting_ledger (
      tenant_id,
      type,
      source,
      reference_id,
      amount,
      inserted_by,
      note
    )
    values (
      p_tenant_id,
      'EXPENSE'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      v_invoice_id,
      v_total_ship_paid_by_shop,
      p_inserted_by,
      'Auto-logged shipping cost absorbed by shop for Invoice #' || p_invoice_number
    );
  end if;

  return v_invoice_id;
end;
$$;

-- -------------------------
-- 6. Row Level Security Policies
-- -------------------------

alter table public.thrift_categories enable row level security;
alter table public.thrift_types enable row level security;
alter table public.thrift_shelves enable row level security;
alter table public.thrift_stocks enable row level security;
alter table public.thrift_stock_images enable row level security;
alter table public.thrift_pricings enable row level security;
alter table public.thrift_invoices enable row level security;
alter table public.thrift_invoice_items enable row level security;
alter table public.thrift_accounting_ledger enable row level security;

-- Category policies
create policy select_thrift_categories on public.thrift_categories for select to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_categories.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true));
create policy write_thrift_categories on public.thrift_categories for all to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_categories.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true and m.role in ('admin', 'staff')));

-- Type policies
create policy select_thrift_types on public.thrift_types for select to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_types.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true));
create policy write_thrift_types on public.thrift_types for all to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_types.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true and m.role in ('admin', 'staff')));

-- Shelf policies
create policy select_thrift_shelves on public.thrift_shelves for select to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_shelves.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true));
create policy write_thrift_shelves on public.thrift_shelves for all to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_shelves.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true and m.role in ('admin', 'staff')));

-- Stock policies
create policy select_thrift_stocks on public.thrift_stocks for select to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_stocks.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true));
create policy write_thrift_stocks on public.thrift_stocks for all to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_stocks.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true and m.role in ('admin', 'staff')));

-- Images policies
create policy select_thrift_stock_images on public.thrift_stock_images for select to authenticated
  using (exists (select 1 from public.thrift_stocks s join public.memberships m on m.tenant_id = s.tenant_id where s.id = thrift_stock_images.stock_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true));
create policy write_thrift_stock_images on public.thrift_stock_images for all to authenticated
  using (exists (select 1 from public.thrift_stocks s join public.memberships m on m.tenant_id = s.tenant_id where s.id = thrift_stock_images.stock_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true and m.role in ('admin', 'staff')));

-- Pricing policies
create policy select_thrift_pricings on public.thrift_pricings for select to authenticated
  using (exists (select 1 from public.thrift_stocks s join public.memberships m on m.tenant_id = s.tenant_id where s.id = thrift_pricings.stock_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true));
create policy write_thrift_pricings on public.thrift_pricings for all to authenticated
  using (exists (select 1 from public.thrift_stocks s join public.memberships m on m.tenant_id = s.tenant_id where s.id = thrift_pricings.stock_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true and m.role in ('admin', 'staff')));

-- Invoice policies
create policy select_thrift_invoices on public.thrift_invoices for select to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_invoices.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true));
create policy write_thrift_invoices on public.thrift_invoices for all to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_invoices.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true and m.role in ('admin', 'staff')));

-- Item policies
create policy select_thrift_invoice_items on public.thrift_invoice_items for select to authenticated
  using (exists (select 1 from public.thrift_invoices i join public.memberships m on m.tenant_id = i.tenant_id where i.id = thrift_invoice_items.invoice_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true));
create policy write_thrift_invoice_items on public.thrift_invoice_items for all to authenticated
  using (exists (select 1 from public.thrift_invoices i join public.memberships m on m.tenant_id = i.tenant_id where i.id = thrift_invoice_items.invoice_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true and m.role in ('admin', 'staff')));

-- Ledger policies
create policy select_thrift_ledger on public.thrift_accounting_ledger for select to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_accounting_ledger.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true));
create policy write_thrift_ledger on public.thrift_accounting_ledger for all to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_accounting_ledger.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true and m.role in ('admin', 'staff')));

-- -------------------------
-- 7. Grants & Sequence Permissions
-- -------------------------

grant select, insert, update, delete on table public.thrift_categories to authenticated;
grant select, insert, update, delete on table public.thrift_types to authenticated;
grant select, insert, update, delete on table public.thrift_shelves to authenticated;
grant select, insert, update, delete on table public.thrift_stocks to authenticated;
grant select, insert, update, delete on table public.thrift_stock_images to authenticated;
grant select, insert, update, delete on table public.thrift_pricings to authenticated;
grant select, insert, update, delete on table public.thrift_invoices to authenticated;
grant select, insert, update, delete on table public.thrift_invoice_items to authenticated;
grant select, insert, update, delete on table public.thrift_accounting_ledger to authenticated;

grant usage, select on sequence public.thrift_categories_id_seq to authenticated;
grant usage, select on sequence public.thrift_types_id_seq to authenticated;
grant usage, select on sequence public.thrift_shelves_id_seq to authenticated;
grant usage, select on sequence public.thrift_stocks_id_seq to authenticated;
grant usage, select on sequence public.thrift_stock_images_id_seq to authenticated;
grant usage, select on sequence public.thrift_pricings_id_seq to authenticated;
grant usage, select on sequence public.thrift_invoices_id_seq to authenticated;
grant usage, select on sequence public.thrift_invoice_items_id_seq to authenticated;
grant usage, select on sequence public.thrift_accounting_ledger_id_seq to authenticated;

grant execute on function public.mark_thrift_items_as_sold(bigint, text, text, text, text, public.thrift_transaction_method, numeric, numeric, numeric, numeric, text, jsonb) to authenticated;

commit;

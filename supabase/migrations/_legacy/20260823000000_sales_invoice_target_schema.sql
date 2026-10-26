begin;

-- =========================================================
-- 1. Drop existing invoicing functions/RPCs
-- =========================================================
drop function if exists public.trg_invoice_charge_lines_block_wholesale() cascade;
drop function if exists public.create_global_invoice(bigint, text, public.global_invoice_type, public.global_source_module, bigint, bigint, bigint, text) cascade;
drop function if exists public.create_global_invoice(bigint, text, public.global_invoice_type, public.global_source_module, bigint, bigint, bigint, bigint, text) cascade;
drop function if exists public.create_global_invoice(bigint, text, public.global_invoice_type, public.global_source_module, bigint, bigint, bigint, bigint, text, public.retail_billing_mode) cascade;
drop function if exists public.add_global_invoice_item(bigint, bigint, numeric, numeric, numeric) cascade;
drop function if exists public.add_global_invoice_item(bigint, bigint, numeric, numeric, numeric, numeric) cascade;
drop function if exists public.upsert_invoice_charge_line(bigint, public.invoice_charge_type, numeric, text) cascade;
drop function if exists public.recompute_global_invoice_totals(bigint) cascade;
drop function if exists public.recompute_global_invoice_payment_status(bigint) cascade;
drop function if exists public.create_billing_profile_payment_with_allocations(bigint, bigint, numeric, date, text, text, text, jsonb) cascade;
drop function if exists public.record_recipient_invoice_collection(bigint, numeric, date, text, text, text) cascade;
drop function if exists public.create_middle_man_payout(bigint, numeric, date, text, text, text) cascade;
drop function if exists public.add_global_return_item(bigint, bigint, numeric, numeric, numeric, numeric, text) cascade;

-- =========================================================
-- 2. Drop existing invoicing tables
-- =========================================================
drop table if exists public.global_return_items cascade;
drop table if exists public.invoice_charge_lines cascade;
drop table if exists public.global_invoice_items cascade;
drop table if exists public.global_invoices cascade;
drop table if exists public.recipient_profiles cascade;

-- =========================================================
-- 3. Re-create / alter types
-- =========================================================
drop type if exists public.global_invoice_type cascade;
create type public.global_invoice_type as enum ('wholesale', 'retail', 'dropship');

drop type if exists public.global_invoice_status cascade;
create type public.global_invoice_status as enum ('draft', 'posted', 'voided');

drop type if exists public.global_fulfillment_status cascade;
create type public.global_fulfillment_status as enum ('pending', 'packed', 'shipped', 'delivered');

drop type if exists public.retail_billing_mode cascade;
create type public.retail_billing_mode as enum ('account', 'direct');

drop type if exists public.collection_source_type cascade;
create type public.collection_source_type as enum ('billing_profile', 'recipient');

-- =========================================================
-- 4. Create recipient_profiles
-- =========================================================
create table public.recipient_profiles (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  address text not null,
  phone text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index recipient_profiles_tenant_id_idx on public.recipient_profiles(tenant_id);
create index recipient_profiles_name_idx on public.recipient_profiles(name);

-- =========================================================
-- 5. Create global_invoices
-- =========================================================
create table public.global_invoices (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  invoice_no text not null,
  invoice_type public.global_invoice_type not null default 'wholesale',
  invoice_date date not null default current_date,
  retail_billing_mode public.retail_billing_mode null,
  invoice_status public.global_invoice_status not null default 'draft',
  fulfillment_status public.global_fulfillment_status not null default 'pending',
  billing_profile_id bigint null references public.billing_profiles(id) on delete restrict,
  recipient_profile_id bigint null references public.recipient_profiles(id) on delete restrict,
  recipient_name text null,
  recipient_phone text null,
  recipient_address text null,
  collection_source public.collection_source_type not null,
  due_date date null,
  payment_status text not null default 'due' check (payment_status in ('due', 'partially_paid', 'paid')),
  total_amount numeric(12,2) not null default 0 check (total_amount >= 0),
  due_amount numeric(12,2) not null default 0 check (due_amount >= 0),
  paid_amount numeric(12,2) not null default 0 check (paid_amount >= 0),
  subtotal_amount numeric(12,2) not null default 0 check (subtotal_amount >= 0),
  discount_amount numeric(12,2) not null default 0 check (discount_amount >= 0),
  face_subtotal_amount numeric(12,2) not null default 0 check (face_subtotal_amount >= 0),
  accounting_subtotal_amount numeric(12,2) not null default 0 check (accounting_subtotal_amount >= 0),
  middle_man_payout_amount numeric(12,2) not null default 0 check (middle_man_payout_amount >= 0),
  middle_man_payout_status text not null default 'pending' check (middle_man_payout_status in ('pending', 'paid')),
  shipping_charge numeric(12,2) not null default 0 check (shipping_charge >= 0),
  cod_charge numeric(12,2) not null default 0 check (cod_charge >= 0),
  courier_collected_amount numeric(12,2) not null default 0 check (courier_collected_amount >= 0),
  wrapping_charge numeric(12,2) not null default 0 check (wrapping_charge >= 0),
  print_charge numeric(12,2) not null default 0 check (print_charge >= 0),
  note text null,
  created_by uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, invoice_no)
);

create index global_invoices_tenant_id_idx on public.global_invoices (tenant_id);
create index global_invoices_parent_tenant_id_idx on public.global_invoices (parent_tenant_id);
create index global_invoices_billing_profile_id_idx on public.global_invoices (billing_profile_id);
create index global_invoices_recipient_profile_id_idx on public.global_invoices (recipient_profile_id);

-- =========================================================
-- 6. Create global_invoice_items
-- =========================================================
create table public.global_invoice_items (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  invoice_id bigint not null references public.global_invoices(id) on delete cascade,
  global_stock_id bigint not null references public.global_stocks(id) on delete restrict,
  shipment_item_id bigint null references public.global_shipment_items(id) on delete set null,
  product_id bigint null references public.products(id) on delete set null,
  name_snapshot text not null,
  barcode_snapshot text null,
  product_code_snapshot text null,
  quantity numeric(12,3) not null check (quantity > 0),
  unit_cost_price numeric(12,2) not null default 0 check (unit_cost_price >= 0),
  sell_price_amount numeric(12,2) not null default 0 check (sell_price_amount >= 0),
  recipient_price_amount numeric(12,2) not null default 0 check (recipient_price_amount >= 0),
  line_discount_amount numeric(12,2) not null default 0 check (line_discount_amount >= 0),
  line_total_amount numeric(12,2) not null default 0 check (line_total_amount >= 0),
  line_face_total_amount numeric(12,2) not null default 0 check (line_face_total_amount >= 0),
  return_quantity numeric(12,3) not null default 0 check (return_quantity >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint global_invoice_items_return_qty_check check (return_quantity <= quantity)
);

create index global_invoice_items_invoice_id_idx on public.global_invoice_items (invoice_id);
create index global_invoice_items_global_stock_id_idx on public.global_invoice_items (global_stock_id);

-- =========================================================
-- 7. Create global_return_items
-- =========================================================
create table public.global_return_items (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  invoice_id bigint not null references public.global_invoices(id) on delete cascade,
  invoice_item_id bigint not null references public.global_invoice_items(id) on delete cascade,
  global_stock_id bigint not null references public.global_stocks(id) on delete restrict,
  quantity numeric(12,3) not null check (quantity > 0),
  return_face_amount numeric(12,2) not null default 0 check (return_face_amount >= 0),
  return_accounting_amount numeric(12,2) not null default 0 check (return_accounting_amount >= 0),
  return_charge_amount numeric(12,2) not null default 0 check (return_charge_amount >= 0),
  note text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index global_return_items_invoice_id_idx on public.global_return_items (invoice_id);
create index global_return_items_invoice_item_id_idx on public.global_return_items (invoice_item_id);

-- =========================================================
-- 8. Restore downstream Foreign Keys dropped by CASCADE
-- =========================================================
alter table public.global_accounting_ledger
  add constraint global_accounting_ledger_global_invoice_id_fkey
  foreign key (global_invoice_id) references public.global_invoices(id) on delete set null,
  add constraint global_accounting_ledger_global_invoice_item_id_fkey
  foreign key (global_invoice_item_id) references public.global_invoice_items(id) on delete set null;

alter table public.global_invoice_accounting
  add constraint global_invoice_accounting_global_invoice_id_fkey
  foreign key (global_invoice_id) references public.global_invoices(id) on delete cascade;

alter table public.payment_allocations
  add constraint payment_allocations_global_invoice_id_fkey
  foreign key (global_invoice_id) references public.global_invoices(id) on delete cascade;

-- =========================================================
-- 9. Trigger validations & update timestamps
-- =========================================================
create or replace function public.trg_validate_global_invoice_profiles()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.billing_profile_id is not null then
    if not exists (
      select 1 from public.billing_profiles bp
      where bp.id = new.billing_profile_id and bp.tenant_id = new.tenant_id
    ) then
      raise exception 'Billing profile tenant_id must match invoice tenant_id';
    end if;
  end if;

  if new.recipient_profile_id is not null then
    if not exists (
      select 1 from public.recipient_profiles rp
      where rp.id = new.recipient_profile_id and rp.tenant_id = new.tenant_id
    ) then
      raise exception 'Recipient profile tenant_id must match invoice tenant_id';
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_validate_global_invoice_profiles_insert_update
before insert or update on public.global_invoices
for each row execute function public.trg_validate_global_invoice_profiles();

create trigger trg_recipient_profiles_set_updated_at
before update on public.recipient_profiles
for each row execute function public.set_updated_at();

create trigger trg_global_invoices_set_updated_at
before update on public.global_invoices
for each row execute function public.set_updated_at();

create trigger trg_global_invoice_items_set_updated_at
before update on public.global_invoice_items
for each row execute function public.set_updated_at();

create trigger trg_global_return_items_set_updated_at
before update on public.global_return_items
for each row execute function public.set_updated_at();

-- =========================================================
-- 10. RLS configurations
-- =========================================================
alter table public.recipient_profiles enable row level security;
alter table public.global_invoices enable row level security;
alter table public.global_invoice_items enable row level security;
alter table public.global_return_items enable row level security;

create policy recipient_profiles_select on public.recipient_profiles
for select to authenticated
using (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = recipient_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

create policy recipient_profiles_write on public.recipient_profiles
for all to authenticated
using (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = recipient_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
)
with check (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = recipient_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

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

create policy global_invoice_items_all on public.global_invoice_items
for all to authenticated
using (
  exists (select 1 from public.global_invoices gi where gi.id = global_invoice_items.invoice_id)
)
with check (
  exists (select 1 from public.global_invoices gi where gi.id = global_invoice_items.invoice_id)
);

create policy global_return_items_all on public.global_return_items
for all to authenticated
using (
  exists (select 1 from public.global_invoices gi where gi.id = global_return_items.invoice_id)
)
with check (
  exists (select 1 from public.global_invoices gi where gi.id = global_return_items.invoice_id)
);

-- =========================================================
-- 11. Billing Profiles RLS Refresh
-- =========================================================
drop policy if exists billing_profiles_select on public.billing_profiles;
drop policy if exists billing_profiles_insert on public.billing_profiles;
drop policy if exists billing_profiles_update on public.billing_profiles;
drop policy if exists billing_profiles_delete on public.billing_profiles;

create policy billing_profiles_select on public.billing_profiles
for select to authenticated
using (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = billing_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

create policy billing_profiles_write on public.billing_profiles
for all to authenticated
using (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = billing_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
)
with check (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = billing_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

-- =========================================================
-- 12. Table grants
-- =========================================================
grant select, insert, update, delete on table public.recipient_profiles to authenticated;
grant usage, select on sequence public.recipient_profiles_id_seq to authenticated;

grant select, insert, update, delete on table public.global_invoices to authenticated;
grant usage, select on sequence public.global_invoices_id_seq to authenticated;

grant select, insert, update, delete on table public.global_invoice_items to authenticated;
grant usage, select on sequence public.global_invoice_items_id_seq to authenticated;

grant select, insert, update, delete on table public.global_return_items to authenticated;
grant usage, select on sequence public.global_return_items_id_seq to authenticated;

commit;

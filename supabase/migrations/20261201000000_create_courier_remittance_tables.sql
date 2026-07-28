-- Migration: Create courier_remittance_batches and courier_remittance_items tables with RLS policies

begin;

-- 1. Create courier_remittance_batches table
create table if not exists public.courier_remittance_batches (
  id bigint generated always as identity primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  courier_service_id uuid not null references public.courier_services(id) on delete restrict,
  batch_no text not null,
  bank_trx_id text,
  payment_date date not null default current_date,
  gross_cod_amount numeric(12,2) not null default 0.00 check (gross_cod_amount >= 0),
  courier_charges_amount numeric(12,2) not null default 0.00 check (courier_charges_amount >= 0),
  net_deposited_amount numeric(12,2) not null default 0.00 check (net_deposited_amount >= 0),
  allocated_amount numeric(12,2) not null default 0.00 check (allocated_amount >= 0),
  variance_amount numeric(12,2) not null default 0.00,
  status text not null default 'draft' check (status in ('draft', 'posted', 'voided')),
  note text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  posted_at timestamptz,
  posted_by uuid references auth.users(id) on delete set null,

  constraint uq_tenant_courier_batch_no unique (tenant_id, courier_service_id, batch_no)
);

-- 2. Create courier_remittance_items table
create table if not exists public.courier_remittance_items (
  id bigint generated always as identity primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  batch_id bigint not null references public.courier_remittance_batches(id) on delete cascade,
  shop_order_id bigint references public.shop_orders(id) on delete set null,
  global_invoice_id bigint references public.global_invoices(id) on delete set null,
  tracking_number text,
  awb_number text,
  cod_collected_amount numeric(12,2) not null default 0.00 check (cod_collected_amount >= 0),
  courier_charge_amount numeric(12,2) not null default 0.00 check (courier_charge_amount >= 0),
  net_remitted_amount numeric(12,2) not null default 0.00 check (net_remitted_amount >= 0),
  status text not null default 'matched' check (status in ('matched', 'unmatched', 'processed', 'error')),
  error_message text,
  created_at timestamptz not null default now()
);

-- 3. Create Indexes for performance
create index if not exists idx_courier_remittance_batches_tenant on public.courier_remittance_batches(tenant_id);
create index if not exists idx_courier_remittance_batches_courier on public.courier_remittance_batches(courier_service_id);
create index if not exists idx_courier_remittance_batches_status on public.courier_remittance_batches(tenant_id, status);

create index if not exists idx_courier_remittance_items_batch on public.courier_remittance_items(batch_id);
create index if not exists idx_courier_remittance_items_tenant on public.courier_remittance_items(tenant_id);
create index if not exists idx_courier_remittance_items_order on public.courier_remittance_items(shop_order_id);
create index if not exists idx_courier_remittance_items_invoice on public.courier_remittance_items(global_invoice_id);
create index if not exists idx_courier_remittance_items_tracking on public.courier_remittance_items(tracking_number);

-- 4. Enable Row Level Security (RLS)
alter table public.courier_remittance_batches enable row level security;
alter table public.courier_remittance_items enable row level security;

-- 5. Set Table Permissions & Grants
revoke all on table public.courier_remittance_batches from anon, public;
revoke all on table public.courier_remittance_items from anon, public;

grant select, insert, update, delete on table public.courier_remittance_batches to authenticated;
grant select, insert, update, delete on table public.courier_remittance_items to authenticated;

grant all on table public.courier_remittance_batches to service_role;
grant all on table public.courier_remittance_items to service_role;

-- 6. Define RLS Isolation Policies
drop policy if exists courier_remittance_batches_tenant_isolation on public.courier_remittance_batches;
create policy courier_remittance_batches_tenant_isolation on public.courier_remittance_batches
  for all to authenticated
  using (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = courier_remittance_batches.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  )
  with check (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = courier_remittance_batches.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  );

drop policy if exists courier_remittance_items_tenant_isolation on public.courier_remittance_items;
create policy courier_remittance_items_tenant_isolation on public.courier_remittance_items
  for all to authenticated
  using (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = courier_remittance_items.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  )
  with check (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = courier_remittance_items.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  );

commit;

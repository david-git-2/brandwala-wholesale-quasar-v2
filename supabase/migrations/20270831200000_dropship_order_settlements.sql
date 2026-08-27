-- Migration: Dropship management settlement tables (DROPSHIP_MANAGEMENT.md §5)

begin;

-- Enums
do $$ begin
  create type public.dropship_settlement_status as enum ('draft', 'confirmed');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.dropship_settlement_charge_type as enum ('delivery', 'print', 'packing', 'return', 'cod');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.dropship_settlement_charge_payer as enum ('recipient', 'merchant', 'company');
exception when duplicate_object then null;
end $$;

-- Header table (1 row per order)
create table if not exists public.dropship_order_settlements (
  id bigint generated always as identity primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  shop_order_id bigint not null unique references public.shop_orders(id) on delete cascade,
  billing_profile_id bigint references public.billing_profiles(id) on delete set null,
  currency_id bigint references public.global_currencies(id) on delete set null,
  calculated_cod_amount numeric(15,2) not null default 0,
  collected_cod_amount numeric(15,2) not null default 0,
  reseller_purchase_cost numeric(15,2) not null default 0,
  discount_company_pay numeric(15,2) not null default 0,
  return_reason_note text,
  total_cost numeric(15,2),
  reseller_profit numeric(15,2),
  company_profit numeric(15,2),
  status public.dropship_settlement_status not null default 'draft',
  confirmed_at timestamptz,
  confirmed_by uuid,
  courier_cod_booked_at timestamptz,
  remittance_at timestamptz,
  merchant_payout_at timestamptz,
  wallet_ledger_batch_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_dropship_order_settlements_tenant
  on public.dropship_order_settlements (tenant_id);

-- Charge lines
create table if not exists public.dropship_settlement_charge_lines (
  id bigint generated always as identity primary key,
  settlement_id bigint not null references public.dropship_order_settlements(id) on delete cascade,
  charge_type public.dropship_settlement_charge_type not null,
  amount numeric(15,2) not null default 0,
  payer public.dropship_settlement_charge_payer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (settlement_id, charge_type)
);

create index if not exists idx_dropship_settlement_charge_lines_settlement
  on public.dropship_settlement_charge_lines (settlement_id);

-- updated_at triggers
drop trigger if exists trg_dropship_order_settlements_set_updated_at on public.dropship_order_settlements;
create trigger trg_dropship_order_settlements_set_updated_at
  before update on public.dropship_order_settlements
  for each row execute function public.set_updated_at();

drop trigger if exists trg_dropship_settlement_charge_lines_set_updated_at on public.dropship_settlement_charge_lines;
create trigger trg_dropship_settlement_charge_lines_set_updated_at
  before update on public.dropship_settlement_charge_lines
  for each row execute function public.set_updated_at();

-- RLS
alter table public.dropship_order_settlements enable row level security;
alter table public.dropship_settlement_charge_lines enable row level security;

drop policy if exists dropship_order_settlements_staff_all on public.dropship_order_settlements;
create policy dropship_order_settlements_staff_all on public.dropship_order_settlements
  using (public.is_tenant_staff(tenant_id))
  with check (public.is_tenant_staff(tenant_id));

drop policy if exists dropship_settlement_charge_lines_staff_all on public.dropship_settlement_charge_lines;
create policy dropship_settlement_charge_lines_staff_all on public.dropship_settlement_charge_lines
  using (
    exists (
      select 1 from public.dropship_order_settlements s
      where s.id = settlement_id and public.is_tenant_staff(s.tenant_id)
    )
  )
  with check (
    exists (
      select 1 from public.dropship_order_settlements s
      where s.id = settlement_id and public.is_tenant_staff(s.tenant_id)
    )
  );

commit;

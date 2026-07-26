-- Migration: Create billing_profile_wallet_ledger table for Unified Billing Profile Wallet

begin;

create table if not exists public.billing_profile_wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  billing_profile_id bigint not null references public.billing_profiles(id) on delete cascade,
  
  transaction_type text not null check (transaction_type in (
    'invoice_billed',      -- (-) Debt incurred from wholesale/dropship invoice
    'payment_received',    -- (+) Payment received from customer/billing profile
    'dropship_profit',     -- (+) Profit credited from dropship sale
    'dropship_return_fee', -- (-) Charge for return/refusal fees
    'payout_paid',         -- (-) Cash/bank payout paid out to billing profile
    'adjustment'           -- (+/-) Manual or system adjustment
  )),
  
  amount numeric(12,2) not null check (amount >= 0),
  balance_after numeric(12,2) not null,
  reference_id text,
  shop_order_id bigint references public.shop_orders(id) on delete set null,
  global_invoice_id bigint references public.global_invoices(id) on delete set null,
  reference_notes text,
  created_by uuid,
  created_at timestamptz not null default now()
);

-- Indices
create index if not exists idx_billing_profile_wallet_ledger_tenant_profile 
  on public.billing_profile_wallet_ledger(tenant_id, billing_profile_id);

create index if not exists idx_billing_profile_wallet_ledger_created_at 
  on public.billing_profile_wallet_ledger(created_at);

-- RLS & Grants
alter table public.billing_profile_wallet_ledger enable row level security;

revoke all on table public.billing_profile_wallet_ledger from anon;
revoke all on table public.billing_profile_wallet_ledger from public;

grant select on table public.billing_profile_wallet_ledger to authenticated;
grant all on table public.billing_profile_wallet_ledger to service_role;

drop policy if exists billing_profile_wallet_ledger_select on public.billing_profile_wallet_ledger;

create policy billing_profile_wallet_ledger_select
  on public.billing_profile_wallet_ledger
  for select
  to authenticated
  using (
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = billing_profile_wallet_ledger.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  );

commit;

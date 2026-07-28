-- Migration: Create universal_wallet_ledger table and record_ledger_transaction RPC
-- Phase 1 of Universal Wallet Ledger Architecture

begin;

create table if not exists public.universal_wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  entity_type text not null check (entity_type in ('customer', 'vendor', 'courier', 'middleman', 'tenant')),
  entity_id bigint not null,
  type text not null check (type in ('credit', 'debit')),
  amount numeric(15,4) not null check (amount >= 0),
  currency_code text not null default 'BDT',
  exchange_rate numeric(15,6) not null default 1.000000 check (exchange_rate > 0),
  base_amount numeric(15,4) not null check (base_amount >= 0),
  balance_after numeric(15,4) not null,
  source_type text not null check (source_type in ('shop_order', 'vendor_purchase', 'payout', 'adjustment')),
  source_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Indices
create index if not exists idx_universal_wallet_ledger_lookup
  on public.universal_wallet_ledger (tenant_id, entity_type, entity_id, created_at desc, id desc);

create index if not exists idx_universal_wallet_ledger_source
  on public.universal_wallet_ledger (source_type, source_id);

-- RLS & Grants
alter table public.universal_wallet_ledger enable row level security;

revoke all on table public.universal_wallet_ledger from anon;
revoke all on table public.universal_wallet_ledger from public;

grant select on table public.universal_wallet_ledger to authenticated;
grant all on table public.universal_wallet_ledger to service_role;

drop policy if exists universal_wallet_ledger_select on public.universal_wallet_ledger;

create policy universal_wallet_ledger_select
  on public.universal_wallet_ledger
  for select
  to authenticated
  using (
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = universal_wallet_ledger.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  );

-- RPC for atomic ledger insertion and balance calculation
create or replace function public.record_ledger_transaction(
  p_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_type text,
  p_amount numeric,
  p_currency_code text default 'BDT',
  p_exchange_rate numeric default 1.000000,
  p_source_type text default 'adjustment',
  p_source_id text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns public.universal_wallet_ledger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prev_balance numeric(15,4) := 0.0000;
  v_base_amount numeric(15,4) := 0.0000;
  v_balance_after numeric(15,4) := 0.0000;
  v_new_row public.universal_wallet_ledger;
begin
  if p_tenant_id is null then
    raise exception 'Tenant ID is required';
  end if;

  if p_entity_type is null or p_entity_type not in ('customer', 'vendor', 'courier', 'middleman', 'tenant') then
    raise exception 'Invalid or missing entity_type: %', p_entity_type;
  end if;

  if p_entity_id is null then
    raise exception 'Entity ID is required';
  end if;

  if p_type is null or p_type not in ('credit', 'debit') then
    raise exception 'Invalid transaction type: % (must be credit or debit)', p_type;
  end if;

  if coalesce(p_amount, -1) < 0 then
    raise exception 'Amount must be non-negative';
  end if;

  -- Authorization check
  if auth.role() <> 'service_role' and not public.is_superadmin() then
    if not exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    ) then
      raise exception 'Permission denied: Staff or Admin role required for tenant %', p_tenant_id;
    end if;
  end if;

  -- Calculate base amount
  v_base_amount := round(p_amount * coalesce(p_exchange_rate, 1.000000), 4);

  -- Fetch running balance with FOR UPDATE locking
  select balance_after into v_prev_balance
  from public.universal_wallet_ledger
  where tenant_id = p_tenant_id
    and entity_type = p_entity_type
    and entity_id = p_entity_id
  order by created_at desc, id desc
  limit 1
  for update;

  v_prev_balance := coalesce(v_prev_balance, 0.0000);

  if p_type = 'credit' then
    v_balance_after := v_prev_balance + v_base_amount;
  else
    v_balance_after := v_prev_balance - v_base_amount;
  end if;

  insert into public.universal_wallet_ledger (
    tenant_id,
    entity_type,
    entity_id,
    type,
    amount,
    currency_code,
    exchange_rate,
    base_amount,
    balance_after,
    source_type,
    source_id,
    metadata
  )
  values (
    p_tenant_id,
    p_entity_type,
    p_entity_id,
    p_type,
    p_amount,
    coalesce(p_currency_code, 'BDT'),
    coalesce(p_exchange_rate, 1.000000),
    v_base_amount,
    v_balance_after,
    coalesce(p_source_type, 'adjustment'),
    p_source_id,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning * into v_new_row;

  return v_new_row;
end;
$$;

grant execute on function public.record_ledger_transaction(bigint, text, bigint, text, numeric, text, numeric, text, text, jsonb) to authenticated;
grant execute on function public.record_ledger_transaction(bigint, text, bigint, text, numeric, text, numeric, text, text, jsonb) to service_role;

commit;

-- Migration: Backfill billing_profile_wallet_ledger into universal_wallet_ledger (Phase 2)
-- Date: 2026-07-28

begin;

-- Backfill legacy billing_profile_wallet_ledger into universal_wallet_ledger for entity_type = 'middleman'
-- Only insert rows that haven't been migrated yet to ensure idempotency.
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
  metadata,
  created_at
)
select
  l.tenant_id,
  'middleman' as entity_type,
  l.billing_profile_id as entity_id,
  case
    when l.transaction_type in ('dropship_profit', 'payment_received', 'adjustment') then 'credit'
    else 'debit'
  end as type,
  l.amount,
  'BDT' as currency_code,
  1.000000 as exchange_rate,
  l.amount as base_amount,
  l.balance_after,
  case
    when l.shop_order_id is not null then 'shop_order'
    when l.transaction_type = 'payout' then 'payout'
    else 'adjustment'
  end as source_type,
  coalesce(l.shop_order_id::text, l.reference_id, l.id::text) as source_id,
  jsonb_build_object(
    'purpose', 'backfill_legacy_billing_profile_ledger',
    'legacy_ledger_id', l.id,
    'legacy_transaction_type', l.transaction_type,
    'reference_notes', l.reference_notes
  ) as metadata,
  l.created_at
from public.billing_profile_wallet_ledger l
where not exists (
  select 1 from public.universal_wallet_ledger u
  where u.tenant_id = l.tenant_id
    and u.entity_type = 'middleman'
    and u.entity_id = l.billing_profile_id
    and u.metadata->>'legacy_ledger_id' = l.id::text
);

commit;

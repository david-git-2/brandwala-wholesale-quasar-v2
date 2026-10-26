-- Normalize legacy dropship merchant wallet entries to dropship_profit model.
-- Uses in-place ledger fixes + balance recalc (record_ledger_transaction cannot overdraft past CHECK).

begin;

-- 1) merchant_funds_held credits that match reseller_profit → relabel only
update public.universal_wallet_ledger u
set metadata = coalesce(u.metadata, '{}'::jsonb) || jsonb_build_object(
  'transaction_type', 'dropship_profit',
  'label', 'Dropship profit earned',
  'section', 'payout_earned',
  'migration', '20270910130100_dropship_wallet_ledger_normalize_backfill'
)
from public.shop_orders o
join public.dropship_order_settlements s on s.shop_order_id = o.id
where u.source_type = 'shop_order'
  and u.source_id = o.id::text
  and u.entity_type = 'customer'
  and u.entity_id = o.billing_profile_id
  and u.type = 'credit'
  and coalesce(u.metadata->>'transaction_type', '') = 'merchant_funds_held'
  and abs(u.amount - coalesce(s.reseller_profit, 0)) < 0.01;

-- 2) invoice_collection credits → correct amount + relabel to dropship_profit
update public.universal_wallet_ledger u
set
  amount = coalesce(s.reseller_profit, 0),
  base_amount = coalesce(s.reseller_profit, 0),
  metadata = coalesce(u.metadata, '{}'::jsonb) || jsonb_build_object(
    'transaction_type', 'dropship_profit',
    'label', 'Dropship profit earned',
    'section', 'payout_earned',
    'migration', '20270910130100_dropship_wallet_ledger_normalize_backfill'
  )
from public.shop_orders o
join public.dropship_order_settlements s on s.shop_order_id = o.id
where u.source_type = 'shop_order'
  and u.source_id = o.id::text
  and u.entity_type = 'customer'
  and u.entity_id = o.billing_profile_id
  and u.type = 'credit'
  and coalesce(u.metadata->>'transaction_type', '') = 'invoice_collection';

-- 3) Recalculate running balance_after per merchant wallet book
with ordered as (
  select
    u.id,
    sum(case when u.type = 'credit' then u.amount else -u.amount end)
      over (
        partition by u.parent_tenant_id, u.entity_type, u.entity_id
        order by u.created_at asc, u.id asc
      ) as running_balance
  from public.universal_wallet_ledger u
  where u.entity_type = 'customer'
)
update public.universal_wallet_ledger u
set balance_after = o.running_balance
from ordered o
where u.id = o.id;

-- 4) Sync wallet_accounts.available_balance from ledger net
update public.wallet_accounts wa
set
  available_balance = coalesce(src.net_balance, 0),
  updated_at = now()
from (
  select
    u.parent_tenant_id,
    u.entity_type,
    u.entity_id,
    u.currency_code,
    sum(case when u.type = 'credit' then u.amount else -u.amount end) as net_balance
  from public.universal_wallet_ledger u
  group by u.parent_tenant_id, u.entity_type, u.entity_id, u.currency_code
) src
where wa.parent_tenant_id = src.parent_tenant_id
  and wa.entity_type = src.entity_type
  and wa.entity_id = src.entity_id
  and wa.currency_code = src.currency_code;

commit;

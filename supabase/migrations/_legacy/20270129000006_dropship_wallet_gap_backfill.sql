-- Migration: Dropship Wallet P3 Implementation A — Backfill and Drift Check SQL
-- Must run after P0A–P0C + P2 (UWL + invoice_billed contract already exist).

begin;

-- ============================================================================
-- 1. Backfill missing invoice_billed UWL debit (aligned with ensure_dropship_invoice_billed_entry)
-- ============================================================================
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
  i.tenant_id,
  'customer' as entity_type,
  i.billing_profile_id as entity_id,
  'debit' as type,
  i.total_amount as amount,
  'BDT'::text as currency_code,
  1.000000 as exchange_rate,
  i.total_amount as base_amount,
  0.00 as balance_after,
  'shop_order' as source_type,
  i.invoice_no as source_id,
  jsonb_build_object(
    'section', 'receivable',
    'transaction_type', 'invoice_billed',
    'label', 'Invoice Billed',
    'invoice_no', i.invoice_no,
    'invoice_id', i.id,
    'backfill', true
  ) as metadata,
  i.created_at
from public.global_invoices i
where i.invoice_type = 'dropship'
  and i.invoice_status = 'posted'
  and i.billing_profile_id is not null
  and i.total_amount > 0
  and not exists (
    select 1 from public.universal_wallet_ledger u
    where u.tenant_id = i.tenant_id
      and u.entity_type = 'customer'
      and u.entity_id = i.billing_profile_id
      and u.source_type = 'shop_order'
      and u.metadata->>'transaction_type' = 'invoice_billed'
      and (u.metadata->>'invoice_id' = i.id::text or u.source_id = i.invoice_no)
  );

-- ============================================================================
-- 2. Backfill missing courier remittance UWL entry for remitted shop orders
--    (no public.couriers table — entity_id 0 + courier_service_id in metadata)
-- ============================================================================
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
  o.tenant_id,
  'courier' as entity_type,
  0::bigint as entity_id,
  'debit' as type,
  coalesce(o.cod_collect_amount, 0.00) as amount,
  'BDT'::text as currency_code,
  1.000000 as exchange_rate,
  coalesce(o.cod_collect_amount, 0.00) as base_amount,
  0.00 as balance_after,
  'shop_order' as source_type,
  o.id::text as source_id,
  jsonb_build_object(
    'purpose', 'courier_remittance',
    'order_no', o.order_no,
    'remittance_ref', o.courier_remittance_ref,
    'courier_service_id', o.courier_service_id,
    'backfill', true
  ) as metadata,
  coalesce(o.updated_at, o.created_at)
from public.shop_orders o
where o.shop_type_snapshot = 'dropship'
  and o.status = 'payment_received'
  and o.courier_remittance_ref is not null
  and coalesce(o.cod_collect_amount, 0.00) > 0
  and not exists (
    select 1 from public.universal_wallet_ledger u
    where u.tenant_id = o.tenant_id
      and u.entity_type = 'courier'
      and u.source_type = 'shop_order'
      and u.source_id = o.id::text
      and u.metadata->>'purpose' = 'courier_remittance'
  );

-- ============================================================================
-- 3. Backfill/Flag mixed customer vs middleman profit entries
-- ============================================================================
update public.universal_wallet_ledger
set
  entity_type = 'middleman',
  metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('transition_handled', true, 'previous_entity_type', 'customer')
where entity_type = 'customer'
  and source_type = 'shop_order'
  and metadata->>'transaction_type' = 'dropship_profit';

-- ============================================================================
-- 4. Canonicalize inconsistent source_id shapes (order_no -> order_id string)
-- ============================================================================
update public.universal_wallet_ledger u
set
  source_id = o.id::text,
  metadata = coalesce(u.metadata, '{}'::jsonb) || jsonb_build_object('canonicalized_from_order_no', u.source_id)
from public.shop_orders o
where u.source_type = 'shop_order'
  and u.source_id = o.order_no
  and u.tenant_id = o.tenant_id
  and coalesce(u.metadata->>'transaction_type', '') <> 'invoice_billed';

commit;

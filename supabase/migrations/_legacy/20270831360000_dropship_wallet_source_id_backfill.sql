-- Canonicalize dropship invoice_billed wallet rows: source_id = order id (not invoice_no).
-- Fixes 22P02 when legacy rows used INV-DS-* in universal_wallet_ledger.source_id.

begin;

update public.universal_wallet_ledger u
set
  source_id = o.id::text,
  metadata = coalesce(u.metadata, '{}'::jsonb) || jsonb_build_object('order_id', o.id)
from public.shop_orders o
join public.global_invoices i on i.id = o.global_invoice_id
where u.source_type = 'shop_order'
  and u.source_id = i.invoice_no
  and o.shop_type_snapshot = 'dropship'
  and coalesce(u.metadata->>'transaction_type', '') = 'invoice_billed';

commit;

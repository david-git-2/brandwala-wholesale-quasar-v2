begin;

-- =========================================================
-- Phase 6: Retire legacy ledger write and rollup functions
-- =========================================================

-- Drop the deprecated write helper that posted to global_accounting_ledger
drop function if exists public.post_global_invoice_item_to_ledger(bigint) cascade;

-- Drop the legacy shipment accounting rollup refresher
drop function if exists public.refresh_global_shipment_accounting(bigint, bigint) cascade;

commit;

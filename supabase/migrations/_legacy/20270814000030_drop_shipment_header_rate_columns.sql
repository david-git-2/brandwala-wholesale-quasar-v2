-- Phase 7: Drop header rate columns from global_shipments
-- Spec: doc/procurement_stock/task.md Phase 7 · shipment/schema.md
-- All landed cost rates now live strictly in global_shipment_cost_entries.

begin;

-- ---------------------------------------------------------------------------
-- 1. Drop trigger / helper functions that updated header rate columns
-- ---------------------------------------------------------------------------

drop trigger if exists trg_recalculate_shipment_transaction_rate on public.global_shipments;
drop function if exists public.recalculate_shipment_transaction_rate();
drop function if exists public.update_global_shipment_field(bigint, text, text);

-- ---------------------------------------------------------------------------
-- 2. Drop header rate columns from global_shipments
-- ---------------------------------------------------------------------------

alter table public.global_shipments
  drop column if exists product_conversion_rate,
  drop column if exists cargo_conversion_rate,
  drop column if exists cargo_rate,
  drop column if exists transaction_rate;

commit;

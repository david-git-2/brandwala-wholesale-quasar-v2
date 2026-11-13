-- Legacy money kernel deprecation (money-spine-v2).
-- Apply via backend:schema:sync when cutover blockers in docs/features/bills_pays/00-gaps.md are cleared.
-- Phase 1: comments + revoke client DML. Phase 2: DROP (uncomment bottom).

COMMENT ON TABLE public.cashbook_entries IS
  'DEPRECATED money-spine-v2: parallel ledger; drop after cutover. See docs/features/bills/spec.md#legacy-cutover';

COMMENT ON TABLE public.pay_allocations IS
  'DEPRECATED money-spine-v2: replaced by bill_settlements; drop after cutover.';

COMMENT ON TABLE public.pay_instruments IS
  'DEPRECATED money-spine-v2: drop after cheque meta on pays; see 06-legacy-drop.md';

COMMENT ON TABLE public.money_purposes IS
  'DEPRECATED money-spine-v2: replaced by pays.kind + bill_kind_registry; drop after cutover.';

COMMENT ON TABLE public.invoice_write_offs IS
  'DEPRECATED money-spine-v2: use bills.written_off_amount; backfill 07-backfill-cutover.sql.';

COMMENT ON TABLE public.sales_invoice_counters IS
  'DEPRECATED money-spine-v2: use invoice_no_counters when v2 counter table exists.';

REVOKE INSERT, UPDATE, DELETE ON public.pay_allocations FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.cashbook_entries FROM authenticated;

-- Phase 2 (after backfill + UI on rpc_*): uncomment and sync migration
-- DROP TABLE IF EXISTS public.pay_allocations CASCADE;
-- DROP TABLE IF EXISTS public.pay_instruments CASCADE;
-- DROP TABLE IF EXISTS public.money_purposes CASCADE;
-- DROP TABLE IF EXISTS public.cashbook_entries CASCADE;
-- DROP TABLE IF EXISTS public.invoice_write_offs CASCADE;
-- DROP TABLE IF EXISTS public.sales_invoice_counters CASCADE;

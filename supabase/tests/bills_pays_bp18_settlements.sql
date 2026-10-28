-- Tier 1: bill_settlements mirrors pay_allocations (08 audit §1b)
BEGIN;

SELECT plan(5);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'pay_allocations'
      AND t.tgname = 'trg_pay_allocations_bill_settlements'
  ),
  'alloc→settlement trigger removed after BP18-c'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = '_kernel_record_pay_bill_settlement'
  ),
  '_kernel_record_pay_bill_settlement exists'
);

SELECT is(
  (
    SELECT count(*)::bigint
    FROM public.pay_allocations pa
    LEFT JOIN public.bill_settlements bs
      ON bs.pay_allocation_id = pa.id
      OR (
        bs.pay_allocation_id IS NULL
        AND bs.allocator_kind = 'pay'
        AND bs.allocator_id = pa.payment_id
        AND bs.bill_id = public._kernel_resolve_bill_id_from_alloc(pa.invoice_id, pa.global_invoice_id, pa.bill_id)
        AND bs.allocated_books_amount = pa.amount
      )
    WHERE pa.amount IS DISTINCT FROM bs.allocated_books_amount
       OR bs.id IS NULL
  ),
  0::bigint,
  'pay_allocations and bill_settlements are aligned'
);

SELECT is(
  (
    SELECT count(*)::bigint
    FROM (
      SELECT bs.pay_allocation_id
      FROM public.bill_settlements bs
      WHERE bs.pay_allocation_id IS NOT NULL
      GROUP BY bs.pay_allocation_id
      HAVING count(*) > 1
    ) dup
  ),
  0::bigint,
  'pay_allocation_id is unique on bill_settlements'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'list_invoice_payment_history'
      AND p.prosrc LIKE '%bill_settlements bs%'
      AND p.prosrc NOT LIKE '%FROM public.pay_allocations ip%'
  ),
  'list_invoice_payment_history reads settlements'
);

SELECT finish();
ROLLBACK;

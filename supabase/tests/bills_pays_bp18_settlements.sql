-- Tier 1: bill_settlements mirrors pay_allocations (08 audit §1b)
BEGIN;

SELECT plan(2);

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

SELECT finish();
ROLLBACK;

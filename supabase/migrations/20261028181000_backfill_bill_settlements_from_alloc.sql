-- Backfill bill_settlements for pay_allocations missed by trigger (pre-cutover rows)

INSERT INTO public.bill_settlements (
  parent_tenant_id,
  bill_id,
  allocator_kind,
  allocator_id,
  pay_allocation_id,
  allocated_txn_amount,
  allocated_books_amount,
  books_rate_at_alloc,
  fx_realized_books_delta
)
SELECT
  b.parent_tenant_id,
  b.id,
  'pay',
  pa.payment_id,
  pa.id,
  sa.allocated_txn_amount,
  sa.allocated_books_amount,
  sa.books_rate_at_alloc,
  sa.fx_realized_books_delta
FROM public.pay_allocations pa
JOIN public.bills b
  ON b.id = public._kernel_resolve_bill_id_from_alloc(pa.invoice_id, pa.global_invoice_id, pa.bill_id)
LEFT JOIN public.pays p ON p.id = pa.payment_id
CROSS JOIN LATERAL public._kernel_settlement_amounts_from_pay_alloc(b, p, pa.amount) sa
WHERE NOT EXISTS (
  SELECT 1 FROM public.bill_settlements bs WHERE bs.pay_allocation_id = pa.id
);

UPDATE public.bill_settlements bs
SET pay_allocation_id = pa.id
FROM public.pay_allocations pa
WHERE bs.pay_allocation_id IS NULL
  AND bs.allocator_kind = 'pay'
  AND bs.allocator_id = pa.payment_id
  AND bs.bill_id = public._kernel_resolve_bill_id_from_alloc(pa.invoice_id, pa.global_invoice_id, pa.bill_id)
  AND bs.allocated_books_amount = pa.amount
  AND NOT EXISTS (
    SELECT 1 FROM public.bill_settlements bs2 WHERE bs2.pay_allocation_id = pa.id
  );

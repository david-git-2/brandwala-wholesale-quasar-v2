-- AP-2611-0001: clear mistaken books leg (4695 GBP was stored as BDT total/due).
UPDATE public.bills
SET
  subtotal_amount = 0,
  total_amount = 0,
  due_amount = 0,
  books_exchange_rate = null,
  updated_at = now()
WHERE invoice_no = 'AP-2611-0001';

SELECT public._kernel_freeze_bill_txn_face(id)
FROM public.bills
WHERE invoice_no = 'AP-2611-0001';

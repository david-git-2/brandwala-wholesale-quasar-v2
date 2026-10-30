-- Local repair — WTS Shipment 24 (global_shipments.id 45)
BEGIN;

UPDATE public.bills
SET subtotal_amount = 2051.00, total_amount = 2051.00, due_amount = 0, currency_code = 'GBP'
WHERE id = 91;

UPDATE public.bills
SET subtotal_amount = 4695.00, total_amount = 4695.00, due_amount = 0, currency_code = 'GBP'
WHERE id = 90;

SELECT public.recompute_global_invoice_payment_status(90);
SELECT public.recompute_global_invoice_payment_status(91);

SELECT set_config('app.allow_costs_lock', '1', true);

UPDATE public.global_shipments
SET
  status = 'in_transit',
  costs_locked = true,
  costs_locked_at = coalesce(costs_locked_at, now()),
  updated_at = now()
WHERE id = 45;

COMMIT;

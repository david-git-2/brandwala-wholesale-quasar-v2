-- Add cargo_invoice_total to global_shipments.
-- cargo_rate = cargo_invoice_total / received_weight (calculated in app).
alter table public.global_shipments
  add column if not exists cargo_invoice_total numeric;

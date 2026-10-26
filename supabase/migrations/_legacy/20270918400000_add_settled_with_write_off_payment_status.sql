-- recompute_global_invoice_payment_status sets settled_with_write_off;
-- the original check constraint never included that value.

begin;

alter table public.sales_invoices drop constraint if exists global_invoices_payment_status_check;

alter table public.sales_invoices add constraint global_invoices_payment_status_check
  check (
    payment_status = any (
      array[
        'due'::text,
        'partially_paid'::text,
        'paid'::text,
        'settled_with_write_off'::text
      ]
    )
  );

commit;

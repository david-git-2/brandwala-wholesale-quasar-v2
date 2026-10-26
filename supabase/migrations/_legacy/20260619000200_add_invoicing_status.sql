-- Migration to add invoicing status to invoices table status check constraint

alter table public.invoices
  drop constraint if exists invoices_status_check;

alter table public.invoices
  add constraint invoices_status_check
  check (status in ('draft', 'invoicing', 'issued', 'partially_paid', 'paid', 'overdue', 'cancelled'));

-- Migration: Add status column to commerce_invoices table
begin;

alter table public.commerce_invoices
  add column if not exists status text not null default 'draft';

alter table public.commerce_invoices
  drop constraint if exists commerce_invoice_status_check;

alter table public.commerce_invoices
  add constraint commerce_invoice_status_check
  check (status in ('draft', 'ready', 'handed_to_customer'));

commit;

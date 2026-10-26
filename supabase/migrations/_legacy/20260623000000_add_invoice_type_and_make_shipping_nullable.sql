-- Migration: Add invoice_type to commerce_invoices and make recipient_phone and shipping_address nullable in commerce_orders
begin;

-- 1. Add invoice_type column to public.commerce_invoices if it does not exist
alter table public.commerce_invoices
  add column if not exists invoice_type text not null default 'retail' check (invoice_type in ('retail', 'wholesale'));

-- 2. Drop NOT NULL constraints on recipient_phone and shipping_address in public.commerce_orders
alter table public.commerce_orders
  alter column recipient_phone drop not null,
  alter column shipping_address drop not null;

commit;

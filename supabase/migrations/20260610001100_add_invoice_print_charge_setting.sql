-- Migration: Add default_invoice_print_charge to commerce_order_settings
begin;

alter table public.commerce_order_settings
add column if not exists default_invoice_print_charge numeric(12, 2) not null default 0.00;

commit;

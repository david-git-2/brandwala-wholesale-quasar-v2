-- Step 1: Database Schema Updates for Dropship Invoice B2B Refactor
begin;

-- 1. Drop unused dual-price & consignment collection columns from global_invoices
alter table public.global_invoices
  drop column if exists face_subtotal_amount,
  drop column if exists accounting_subtotal_amount,
  drop column if exists middle_man_payout_amount,
  drop column if exists middle_man_payout_status,
  drop column if exists cod_charge,
  drop column if exists courier_collected_amount,
  drop column if exists delivery_charge;

-- 2. Drop dual-price columns from global_invoice_items
alter table public.global_invoice_items
  drop column if exists recipient_price_amount,
  drop column if exists line_face_total_amount;

-- 3. Cleanup global_return_items columns
alter table public.global_return_items
  drop column if exists return_face_amount,
  drop column if exists return_accounting_amount;

commit;

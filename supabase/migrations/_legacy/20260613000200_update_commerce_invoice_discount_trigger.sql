-- Migration: Update Commerce Invoice Discount Spreader Trigger to execute on total_amount updates
begin;

drop trigger if exists trg_commerce_invoice_discount_spreader on public.commerce_invoices;

create trigger trg_commerce_invoice_discount_spreader
after update of discount_amount, total_amount on public.commerce_invoices
for each row
execute function public.trg_fn_spread_commerce_invoice_discount();

commit;

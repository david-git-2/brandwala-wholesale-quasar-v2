-- Drop report-only read RPCs. Keep get_shipment_pnl (investor profit) and payment write RPCs.

drop function if exists public.list_invoice_margin_report(bigint, integer, integer, date, date, text, text);
drop function if exists public.get_invoice_margin_detail(bigint);
drop function if exists public.get_parent_dashboard(bigint);
drop function if exists public.list_billing_balances(bigint, text);
drop function if exists public.list_invoice_outstanding(bigint, text);
drop function if exists public.get_shipment_item_invoices(bigint, bigint);

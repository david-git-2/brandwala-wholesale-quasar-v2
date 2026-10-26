-- Grant authenticated role access to global * tables (RLS policies already exist).
-- Without these grants PostgREST returns 42501 "permission denied for table ...".

begin;

-- B2: stock bridge
grant select, insert, update, delete on table public.global_stocks to authenticated;
grant select, insert, update, delete on table public.global_stock_quantities to authenticated;
grant select, insert, update, delete on table public.child_tenant_stock_allocations to authenticated;
grant select, insert, update, delete on table public.business_parties to authenticated;

grant usage, select on sequence public.global_stocks_id_seq to authenticated;
grant usage, select on sequence public.global_stock_quantities_id_seq to authenticated;
grant usage, select on sequence public.child_tenant_stock_allocations_id_seq to authenticated;
grant usage, select on sequence public.business_parties_id_seq to authenticated;

-- B4: invoices
grant select, insert, update, delete on table public.global_invoices to authenticated;
grant select, insert, update, delete on table public.global_invoice_items to authenticated;
grant select, insert, update, delete on table public.global_return_items to authenticated;
grant select, insert, update, delete on table public.invoice_charge_lines to authenticated;

grant usage, select on sequence public.global_invoices_id_seq to authenticated;
grant usage, select on sequence public.global_invoice_items_id_seq to authenticated;
grant usage, select on sequence public.global_return_items_id_seq to authenticated;
grant usage, select on sequence public.invoice_charge_lines_id_seq to authenticated;

-- B5: accounting
grant select, insert, update, delete on table public.global_accounting_ledger to authenticated;
grant select, insert, update, delete on table public.global_shipment_accounting to authenticated;
grant select, insert, update, delete on table public.global_invoice_accounting to authenticated;

grant usage, select on sequence public.global_accounting_ledger_id_seq to authenticated;
grant usage, select on sequence public.global_shipment_accounting_id_seq to authenticated;
grant usage, select on sequence public.global_invoice_accounting_id_seq to authenticated;

-- B6: investor portal accounts
grant select, insert, update, delete on table public.investor_accounts to authenticated;
grant usage, select on sequence public.investor_accounts_id_seq to authenticated;

commit;

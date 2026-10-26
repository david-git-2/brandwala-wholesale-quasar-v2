grant select, insert, update, delete on table public.investors to authenticated;
grant select, insert, update, delete on table public.investor_transactions to authenticated;
grant select, insert, update, delete on table public.shipment_investments to authenticated;

grant usage, select on sequence public.investors_id_seq to authenticated;
grant usage, select on sequence public.investor_transactions_id_seq to authenticated;
grant usage, select on sequence public.shipment_investments_id_seq to authenticated;

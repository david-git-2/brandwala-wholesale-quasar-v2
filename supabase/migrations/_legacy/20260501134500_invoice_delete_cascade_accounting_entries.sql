alter table public.inventory_accounting_entries
  drop constraint if exists inventory_accounting_entries_invoice_id_fkey;

alter table public.inventory_accounting_entries
  add constraint inventory_accounting_entries_invoice_id_fkey
  foreign key (invoice_id)
  references public.invoices(id)
  on delete cascade;

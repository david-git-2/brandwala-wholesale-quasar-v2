alter table public.orders
  add column if not exists invoice_id bigint null default null;

alter table public.product_based_costing_files
  add column if not exists invoice_id bigint null default null;

alter table public.orders
  drop constraint if exists orders_invoice_id_fkey;
alter table public.orders
  add constraint orders_invoice_id_fkey
  foreign key (invoice_id)
  references public.invoices(id)
  on delete set null;

alter table public.product_based_costing_files
  drop constraint if exists product_based_costing_files_invoice_id_fkey;
alter table public.product_based_costing_files
  add constraint product_based_costing_files_invoice_id_fkey
  foreign key (invoice_id)
  references public.invoices(id)
  on delete set null;

create index if not exists orders_invoice_id_idx
  on public.orders (invoice_id);

create index if not exists product_based_costing_files_invoice_id_idx
  on public.product_based_costing_files (invoice_id);

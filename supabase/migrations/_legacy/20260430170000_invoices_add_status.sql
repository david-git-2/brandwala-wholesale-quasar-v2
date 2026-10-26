alter table public.invoices
  add column if not exists status text not null default 'draft'
  check (status in ('draft', 'issued', 'partially_paid', 'paid', 'overdue', 'cancelled'));

create index if not exists invoices_status_idx
  on public.invoices (tenant_id, status);

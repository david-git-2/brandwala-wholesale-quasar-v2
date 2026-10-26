alter table public.invoice_items
  add column if not exists return_normal_quantity numeric(12,3) not null default 0
    check (return_normal_quantity >= 0),
  add column if not exists return_open_box_quantity numeric(12,3) not null default 0
    check (return_open_box_quantity >= 0),
  add column if not exists return_amount numeric(12,2) not null default 0
    check (return_amount >= 0);

alter table public.inventory_accounting_entries
  add column if not exists return_quantity numeric(12,3) not null default 0
    check (return_quantity >= 0),
  add column if not exists return_amount numeric(12,2) not null default 0
    check (return_amount >= 0);

alter table public.inventory_accounting_entries
  drop constraint if exists inventory_accounting_entries_quantity_check;

alter table public.inventory_accounting_entries
  add constraint inventory_accounting_entries_quantity_check
  check (quantity >= 0);

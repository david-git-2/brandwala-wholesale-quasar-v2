alter table public.shipments
  add column if not exists inventory_added boolean not null default false;

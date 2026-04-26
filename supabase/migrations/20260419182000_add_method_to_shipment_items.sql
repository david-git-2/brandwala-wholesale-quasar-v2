alter table public.shipment_items
add column if not exists method text not null default 'manual';

alter table public.shipment_items
drop constraint if exists shipment_items_method_check;

alter table public.shipment_items
add constraint shipment_items_method_check
check (method in ('order', 'costing', 'manual'));

create index if not exists shipment_items_method_idx
  on public.shipment_items (method);

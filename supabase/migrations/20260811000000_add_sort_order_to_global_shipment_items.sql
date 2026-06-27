-- Add sort_order column to public.global_shipment_items
alter table public.global_shipment_items
  add column if not exists sort_order int not null default 0;

-- Add sort_order column to public.shipment_items
alter table public.shipment_items
  add column if not exists sort_order int not null default 0;

alter table public.shipment_items
add column if not exists order_id bigint references public.orders(id) on delete set null;

create index if not exists shipment_items_order_id_idx
  on public.shipment_items (order_id);

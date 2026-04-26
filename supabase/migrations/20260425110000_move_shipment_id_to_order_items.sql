begin;

alter table public.order_items
  add column if not exists shipment_id bigint null;

alter table public.order_items
  drop constraint if exists order_items_shipment_id_fkey;

alter table public.order_items
  add constraint order_items_shipment_id_fkey
  foreign key (shipment_id)
  references public.shipments(id)
  on delete set null;

create index if not exists order_items_shipment_id_idx
  on public.order_items using btree (shipment_id);

alter table public.orders
  drop constraint if exists orders_shipment_id_fkey;

drop index if exists public.orders_shipment_id_idx;

alter table public.orders
  drop column if exists shipment_id;

commit;

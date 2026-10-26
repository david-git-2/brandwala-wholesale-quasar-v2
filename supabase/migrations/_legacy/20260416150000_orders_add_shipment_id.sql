begin;

alter table public.orders
  add column if not exists shipment_id bigint null;

alter table public.orders
  drop constraint if exists orders_shipment_id_fkey;

alter table public.orders
  add constraint orders_shipment_id_fkey
  foreign key (shipment_id)
  references public.shipments(id)
  on delete set null;

create index if not exists orders_shipment_id_idx
  on public.orders using btree (shipment_id);

commit;

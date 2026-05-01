alter table public.inventory_accounting_entries
  add column if not exists shipment_id bigint null references public.shipments(id) on delete set null,
  add column if not exists shipment_item_id bigint null references public.shipment_items(id) on delete set null;

create index if not exists inventory_accounting_entries_shipment_id_idx
  on public.inventory_accounting_entries (shipment_id);

create index if not exists inventory_accounting_entries_shipment_item_id_idx
  on public.inventory_accounting_entries (shipment_item_id);

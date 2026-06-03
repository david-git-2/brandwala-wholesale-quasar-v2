begin;

alter table public.commerce_order_items
  add column if not exists inventory_item_id bigint null references public.inventory_items(id) on delete set null,
  add column if not exists shipment_item_id bigint null references public.shipment_items(id) on delete set null;

create index if not exists commerce_order_items_inventory_item_idx
  on public.commerce_order_items (inventory_item_id);

create index if not exists commerce_order_items_shipment_item_idx
  on public.commerce_order_items (shipment_item_id);

alter table public.commerce_accounting
  add column if not exists inventory_item_id bigint null references public.inventory_items(id) on delete set null;

create index if not exists commerce_accounting_inventory_item_idx
  on public.commerce_accounting (inventory_item_id);

do $$
begin
  perform pg_notify('pgrst', 'reload schema');
exception
  when others then
    null;
end;
$$;

commit;

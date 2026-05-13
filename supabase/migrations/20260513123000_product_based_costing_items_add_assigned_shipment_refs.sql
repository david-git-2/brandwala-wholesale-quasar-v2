alter table public.product_based_costing_items
  add column if not exists assigned_shipment_id bigint null,
  add column if not exists assigned_shipment_item_id bigint null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'product_based_costing_items_assigned_shipment_id_fkey'
  ) then
    alter table public.product_based_costing_items
      add constraint product_based_costing_items_assigned_shipment_id_fkey
      foreign key (assigned_shipment_id) references public.shipments(id)
      on delete set null;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'product_based_costing_items_assigned_shipment_item_id_fkey'
  ) then
    alter table public.product_based_costing_items
      add constraint product_based_costing_items_assigned_shipment_item_id_fkey
      foreign key (assigned_shipment_item_id) references public.shipment_items(id)
      on delete set null;
  end if;
end $$;

create index if not exists product_based_costing_items_assigned_shipment_id_idx
  on public.product_based_costing_items (assigned_shipment_id);

create index if not exists product_based_costing_items_assigned_shipment_item_id_idx
  on public.product_based_costing_items (assigned_shipment_item_id);

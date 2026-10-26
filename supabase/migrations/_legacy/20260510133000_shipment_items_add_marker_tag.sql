alter table public.shipment_items
  add column if not exists marker_tag text null;

alter table public.shipment_items
  drop constraint if exists shipment_items_marker_tag_check;

alter table public.shipment_items
  add constraint shipment_items_marker_tag_check
  check (marker_tag in ('price_reviewed', 'issue', 'done') or marker_tag is null);

create index if not exists shipment_items_marker_tag_idx
  on public.shipment_items (marker_tag);

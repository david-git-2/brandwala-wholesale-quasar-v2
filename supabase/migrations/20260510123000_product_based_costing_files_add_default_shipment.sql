alter table public.product_based_costing_files
  add column if not exists default_shipment_id bigint null references public.shipments(id) on delete set null;

create index if not exists product_based_costing_files_default_shipment_id_idx
  on public.product_based_costing_files (default_shipment_id);

drop index if exists public.product_based_costing_items_assigned_shipment_item_id_idx;

alter table public.product_based_costing_items
  drop constraint if exists product_based_costing_items_assigned_shipment_item_id_fkey;

alter table public.product_based_costing_items
  drop column if exists assigned_shipment_item_id;

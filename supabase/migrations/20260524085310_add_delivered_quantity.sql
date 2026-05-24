alter table public.product_based_costing_items
add column if not exists delivered_quantity numeric(12,3) null default 0.000;

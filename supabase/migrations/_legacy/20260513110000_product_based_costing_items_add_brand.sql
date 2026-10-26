alter table public.product_based_costing_items
  add column if not exists brand text null;

create index if not exists product_based_costing_items_brand_idx
  on public.product_based_costing_items (brand);

alter table public.product_based_costing_items
  add column if not exists vendor_code text null,
  add column if not exists market_code text null;

create index if not exists product_based_costing_items_vendor_code_idx
  on public.product_based_costing_items (vendor_code);

create index if not exists product_based_costing_items_market_code_idx
  on public.product_based_costing_items (market_code);

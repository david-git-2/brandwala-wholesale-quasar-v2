-- Add is_offer_price_manual column to product_based_costing_items table
alter table public.product_based_costing_items
  add column if not exists is_offer_price_manual boolean not null default false;

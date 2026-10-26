-- ====================================================================
-- Update check constraint on store_product_prices
-- Drop old minimum_sell_price_bdt <= price_bdt check
-- Add new minimum_sell_price_bdt >= price_bdt check
-- ====================================================================

-- Safe backfill: ensure no existing rows violate the new >= constraint
update public.store_product_prices
set minimum_sell_price_bdt = price_bdt
where minimum_sell_price_bdt < price_bdt;

alter table public.store_product_prices
  drop constraint if exists store_product_prices_min_lte_price_chk;

alter table public.store_product_prices
  add constraint store_product_prices_min_gte_price_chk check (minimum_sell_price_bdt >= price_bdt);

-- Listing insert 42P01: trg_sync_shop_listing_active_status still ran on
-- shop_product_listings and selected from dropped global_stock_allocations.
-- 00060 dropped that trigger name on the wrong table.
-- is_active is a staff catalog flag; ATP is computed at browse/checkout.

drop trigger if exists trg_sync_shop_listing_active_status on public.shop_product_listings;
drop function if exists public.sync_shop_listing_active_status_on_stock_change();
drop function if exists public.sync_shop_listings_on_allocation_qty_change();

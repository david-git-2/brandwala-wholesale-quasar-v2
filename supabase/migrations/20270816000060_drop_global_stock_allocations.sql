-- Phase 2 (W5 Step 2.5): Drop legacy table global_stock_allocations

begin;

-- Drop triggers on global_stock_allocations
drop trigger if exists trg_sync_shop_listing_active_status on public.global_stock_allocations;
drop function if exists public.sync_shop_listing_active_status_on_allocation_change();

-- Drop foreign key constraints referencing global_stock_allocations
alter table if exists public.shop_product_listings
  drop constraint if exists shop_product_listings_global_stock_allocation_id_fkey;

alter table if exists public.shop_cart_items
  drop constraint if exists shop_cart_items_global_stock_allocation_id_fkey;

alter table if exists public.shop_stock_reservations
  drop constraint if exists shop_stock_reservations_global_stock_allocation_id_fkey;

-- Drop legacy table
drop table if exists public.global_stock_allocations cascade;

commit;

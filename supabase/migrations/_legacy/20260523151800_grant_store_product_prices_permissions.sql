-- =========================================================
-- Grant authenticated access to store product prices tables and sequence
-- Needed for pricing CRUD operations
-- =========================================================

grant select, insert, update, delete
on table public.store_product_prices
to authenticated;

grant usage, select
on sequence public.store_product_prices_id_seq
to authenticated;

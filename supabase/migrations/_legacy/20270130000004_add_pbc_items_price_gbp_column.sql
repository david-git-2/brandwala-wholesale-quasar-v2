-- Fix Postgres 42703 error: add missing column price_gbp to product_based_costing_items table if not exists

ALTER TABLE public.product_based_costing_items
  ADD COLUMN IF NOT EXISTS price_gbp numeric(12,2) NULL;

NOTIFY pgrst, 'reload schema';


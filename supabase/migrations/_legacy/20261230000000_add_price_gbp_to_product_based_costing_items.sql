-- Ensure price_gbp column exists on product_based_costing_items table
ALTER TABLE public.product_based_costing_items
  ADD COLUMN IF NOT EXISTS price_gbp numeric(12,2) NULL;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';

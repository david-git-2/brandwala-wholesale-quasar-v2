ALTER TABLE public.koba_order_items
  DROP COLUMN IF EXISTS custom_price_gbp,
  ADD COLUMN IF NOT EXISTS confirmed_quantity INT DEFAULT NULL;

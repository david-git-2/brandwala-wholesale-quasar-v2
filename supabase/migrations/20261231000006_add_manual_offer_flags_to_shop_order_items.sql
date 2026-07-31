-- Migration: Add first offer rate, final offer rate, and manual offer flags to shop_orders & shop_order_items
ALTER TABLE public.shop_orders
  ADD COLUMN IF NOT EXISTS first_offer_rate NUMERIC NULL,
  ADD COLUMN IF NOT EXISTS final_offer_rate NUMERIC NULL;

ALTER TABLE public.shop_order_items
  ADD COLUMN IF NOT EXISTS is_first_offer_manual BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS is_final_offer_manual BOOLEAN NOT NULL DEFAULT FALSE;

-- Remove shop_order_items.delivered (no longer used).

ALTER TABLE public.shop_order_items
  DROP CONSTRAINT IF EXISTS shop_order_items_delivered_valid;

ALTER TABLE public.shop_order_items
  DROP COLUMN IF EXISTS delivered;

DROP FUNCTION IF EXISTS public.set_shop_order_item_delivered(bigint, bigint, jsonb);
DROP FUNCTION IF EXISTS public.validate_shop_order_item_delivered(jsonb);
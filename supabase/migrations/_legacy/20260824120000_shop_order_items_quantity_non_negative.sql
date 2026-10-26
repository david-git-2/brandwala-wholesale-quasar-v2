-- Allow quantity = 0 on shop_order_items (rejected / zero-qty lines at confirm).
-- Previously shop_order_items_qty_positive required quantity > 0.

ALTER TABLE public.shop_order_items
  DROP CONSTRAINT IF EXISTS shop_order_items_qty_positive;

ALTER TABLE public.shop_order_items
  ADD CONSTRAINT shop_order_items_qty_non_negative CHECK (quantity >= 0);

NOTIFY pgrst, 'reload schema';

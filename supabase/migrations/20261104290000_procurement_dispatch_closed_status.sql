-- Add shop_order_status values for catalog fulfillment (must commit before use).

ALTER TYPE public.shop_order_status ADD VALUE IF NOT EXISTS 'dispatch';
ALTER TYPE public.shop_order_status ADD VALUE IF NOT EXISTS 'closed';

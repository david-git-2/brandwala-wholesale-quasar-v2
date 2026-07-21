-- Migration: Custom Order Statuses for Dropship Shops
begin;

-- Add new values to shop_order_status enum if they do not exist
alter type public.shop_order_status add value if not exists 'processing';
alter type public.shop_order_status add value if not exists 'shipped';
alter type public.shop_order_status add value if not exists 'delivered';
alter type public.shop_order_status add value if not exists 'payment_received';

commit;

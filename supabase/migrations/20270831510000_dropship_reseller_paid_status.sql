-- Add shop_order_status.reseller_paid (step ③ complete — transferred to reseller).
-- Enum value must be committed before use in functions/backfill (separate migration).

alter type public.shop_order_status add value if not exists 'reseller_paid';

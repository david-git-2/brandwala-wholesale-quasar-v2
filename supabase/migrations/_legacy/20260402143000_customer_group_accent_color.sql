-- =========================================================
-- Customer group accent color
-- Adds accent_color for customer-group branding and UI context
-- =========================================================

alter table public.customer_groups
  add column if not exists accent_color text;

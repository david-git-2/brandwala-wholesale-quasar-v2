-- =========================================================
-- Billing profiles add color
-- Adds color column to public.billing_profiles
-- =========================================================

alter table public.billing_profiles
  add column if not exists color text null;

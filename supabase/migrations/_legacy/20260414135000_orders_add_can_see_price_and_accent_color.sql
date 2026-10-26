-- =========================================================
-- Orders: add can_see_price and accent_color
-- =========================================================

alter table public.orders
  add column if not exists can_see_price boolean not null default false,
  add column if not exists accent_color text null;

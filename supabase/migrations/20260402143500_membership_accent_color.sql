-- =========================================================
-- Membership accent color
-- Adds accent_color to align memberships with the master plan
-- =========================================================

alter table public.memberships
  add column if not exists accent_color text;

begin;

-- =========================================================
-- Drop legacy investor_accounts table (Phase 8)
-- =========================================================
drop table if exists public.investor_accounts cascade;

commit;

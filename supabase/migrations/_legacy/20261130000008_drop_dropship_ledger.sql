-- Migration: Drop legacy dropship ledger table and obsolete RPCs
-- Phase 5 of Unified Billing Profile Wallet Refactor

begin;

-- 1. Drop old table middle_man_payout_ledger if it exists
drop table if exists public.middle_man_payout_ledger cascade;

-- 2. Drop obsolete RPC create_middle_man_payout if it exists
drop function if exists public.create_middle_man_payout(bigint, bigint, bigint, numeric, text);

commit;

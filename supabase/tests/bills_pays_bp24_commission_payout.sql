-- BP24: commission payout via post_money_out
BEGIN;

SELECT plan(3);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = '_kernel_post_commission_payout'
  ),
  '_kernel_post_commission_payout exists'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'post_money_out'
      AND p.prosrc LIKE '%_kernel_post_commission_payout%'
      AND p.prosrc NOT LIKE '%dispense_middleman_payout_from_tenant(%'
  ),
  'post_money_out commission branch uses kernel writer'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = 'pays'
      AND c.conname = 'pays_source_check'
      AND pg_get_constraintdef(c.oid) LIKE '%commission%'
  ),
  'pays.source allows commission'
);

SELECT finish();
ROLLBACK;

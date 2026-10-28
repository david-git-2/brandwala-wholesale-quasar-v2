-- BP24: commission payout via post_money_out (no dispense shim)
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
  ),
  'post_money_out commission branch uses kernel writer'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'dispense_middleman_payout_from_tenant'
  ),
  'dispense_middleman_payout_from_tenant removed'
);

SELECT finish();
ROLLBACK;

-- BP15: collect requires cash point
BEGIN;

SELECT plan(2);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'post_money_in'
      AND p.prosrc LIKE '%p_cashbook_point_id%'
  ),
  'post_money_in forwards cashbook point args'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'post_customer_receipt_with_allocations'
      AND p.prosrc LIKE '%Choose a cash point for this receipt%'
      AND p.prosrc LIKE '%cashbook_point_id%'
  ),
  'post_customer_receipt requires point and sets pays.cashbook_point_id'
);

SELECT finish();
ROLLBACK;

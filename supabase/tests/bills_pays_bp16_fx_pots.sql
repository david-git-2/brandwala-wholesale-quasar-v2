-- BP16: FX pots + books exchange rates read
BEGIN;

SELECT plan(2);

SELECT has_function(
  'public',
  'list_books_exchange_rates',
  ARRAY['bigint', 'text', 'integer']
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'post_customer_receipt_with_allocations'
      AND p.prosrc LIKE '%v_ledger_currency%'
      AND p.prosrc LIKE '%cashbook_point_pot_id%'
  ),
  'collect receipt uses pot-aware ledger currency'
);

SELECT finish();
ROLLBACK;

-- BP5: wholesale return issues CN without shrinking parent total
BEGIN;

SELECT plan(3);

SELECT ok(
  (
    SELECT prosrc LIKE '%create_bill_adjustment%'
      AND prosrc NOT LIKE '%total_amount = v_new_total%'
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'process_wholesale_invoice_return'
  ),
  'process_wholesale_invoice_return uses create_bill_adjustment and does not set v_new_total on parent'
);

SELECT ok(
  (
    SELECT prosrc LIKE '%_kernel_dropship_return_credit_note%'
      AND prosrc NOT LIKE '%recompute_global_invoice_totals%'
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'finalize_dropship_return'
  ),
  'finalize_dropship_return uses CN helper instead of recompute_global_invoice_totals'
);

SELECT has_function(
  'public',
  '_kernel_dropship_return_credit_note',
  ARRAY['bigint', 'numeric', 'numeric', 'text', 'jsonb']
);

SELECT finish();
ROLLBACK;

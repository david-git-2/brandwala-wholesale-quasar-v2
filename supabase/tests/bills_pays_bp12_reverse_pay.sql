-- BP12: settlements-aware reverse_pay / _kernel_reverse_payment
BEGIN;

SELECT plan(4);

SELECT has_function(
  'public',
  '_kernel_reverse_payment',
  ARRAY['bigint', 'bigint', 'text']
);

SELECT has_function(
  'public',
  'reverse_pay',
  ARRAY['bigint', 'text']
);

SELECT ok(
  (
    SELECT prosrc LIKE '%delete from public.bill_settlements%'
      AND prosrc LIKE '%delete from public.pay_allocations%'
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = '_kernel_reverse_payment'
  ),
  '_kernel_reverse_payment deletes settlements before allocations'
);

SELECT ok(
  (
    SELECT prosrc LIKE '%_kernel_reverse_payment%'
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'void_customer_receipt'
  ),
  'void_customer_receipt delegates to kernel reverse'
);

SELECT finish();
ROLLBACK;

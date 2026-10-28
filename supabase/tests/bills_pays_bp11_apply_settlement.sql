-- BP11: apply_settlement_to_bill + pay leftover kernel (T4-2 contract)
BEGIN;

SELECT plan(3);

SELECT has_function(
  'public',
  'apply_settlement_to_bill',
  ARRAY['bigint', 'bigint', 'text', 'bigint', 'numeric']
);

SELECT has_function(
  'public',
  '_kernel_apply_pay_leftover_to_bill',
  ARRAY['bigint', 'bigint', 'bigint', 'numeric', 'boolean']
);

SELECT ok(
  (
    SELECT prosrc LIKE '%allocator_kind = ''credit_note''%'
      AND prosrc LIKE '%v_child_cross%'
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'recompute_global_invoice_payment_status'
  ),
  'recompute_global_invoice_payment_status subtracts cross-bill CN settlements'
);

SELECT finish();
ROLLBACK;

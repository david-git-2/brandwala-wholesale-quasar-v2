-- WA13: cheque bounce (whole pay v1 + partial split tender)
BEGIN;

SELECT plan(4);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'pay_instruments'
      AND column_name = 'bounced_at'
  ),
  'pay_instruments.bounced_at column exists'
);

SELECT has_function(
  'public',
  'bounce_cheque_instrument',
  ARRAY['bigint', 'bigint', 'text']
);

SELECT ok(
  (
    SELECT prosrc LIKE '%reverse_pay%'
      AND prosrc LIKE '%bounced_at%'
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'bounce_cheque_instrument'
  ),
  'bounce_cheque_instrument marks bounced and calls reverse_pay'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'bounce_cheque_instrument'
      AND p.prosrc LIKE '%_kernel_bounce_cheque_instrument_partial%'
  ),
  'bounce_cheque_instrument supports partial split-tender path'
);

SELECT finish();
ROLLBACK;

-- BP15-t: point transfer RPC smoke
BEGIN;

SELECT plan(3);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'transfer_cashbook_point'
  ),
  'transfer_cashbook_point exists'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'transfer_cashbook_point'
      AND p.prosrc LIKE '%point_transfer%'
  ),
  'transfer uses point_transfer source_type'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = '_kernel_lock_cashbook_points_for_transfer'
  ),
  'deterministic pot lock helper exists'
);

SELECT finish();
ROLLBACK;

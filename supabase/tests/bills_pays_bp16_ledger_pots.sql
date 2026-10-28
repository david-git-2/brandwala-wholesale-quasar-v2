-- BP16-r: void/refund ledger legs tag cashbook pots
BEGIN;

SELECT plan(4);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = '_kernel_reverse_payment'
      AND p.prosrc LIKE '%commission%'
      AND p.prosrc LIKE '%cashbook_point_pot_id%'
  ),
  '_kernel_reverse_payment commission void includes pot metadata'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = '_kernel_reverse_payment'
      AND p.prosrc LIKE '%ap_payout%'
      AND p.prosrc LIKE '%cashbook_point_pot_id%'
  ),
  '_kernel_reverse_payment ap_payout void includes pot metadata'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'create_bill_adjustment'
      AND p.prosrc LIKE '%credit_note_refund%'
      AND p.prosrc LIKE '%cashbook_point_pot_id%'
  ),
  'create_bill_adjustment cash refund tags pot on tenant debit'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'bill_lines'
      AND column_name = 'global_stock_id'
  ),
  'bill_lines.global_stock_id column dropped'
);

SELECT finish();
ROLLBACK;

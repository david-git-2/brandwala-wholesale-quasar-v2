-- BP21: cashbook_accounts.account_class
BEGIN;

SELECT plan(3);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public' AND t.typname = 'cashbook_account_class'
  ),
  'cashbook_account_class enum exists'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'cashbook_accounts'
      AND column_name = 'account_class'
  ),
  'cashbook_accounts.account_class column exists'
);

SELECT ok(
  (
    SELECT prosrc LIKE '%account_class%'
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_wallet_account_balances'
  ),
  'get_wallet_account_balances returns account_class'
);

SELECT finish();
ROLLBACK;

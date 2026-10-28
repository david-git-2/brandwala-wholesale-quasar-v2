-- BP17: stock commit before wholesale issue
BEGIN;

SELECT plan(5);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'commit_sales_bill_stock'
  ),
  'commit_sales_bill_stock exists'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'commit_wholesale_bill_stock'
  ),
  'commit_wholesale_bill_stock exists'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = '_kernel_issue_wholesale_stock'
      AND p.prosrc LIKE '%commit_wholesale_bill_stock first%'
      AND p.prosrc NOT LIKE '%update public.global_stocks%'
  ),
  'kernel wholesale issue no longer deducts stock inline'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'issue_wholesale_bill'
      AND p.prosrc LIKE '%commit_wholesale_bill_stock%'
  ),
  'issue_wholesale_bill commits stock before kernel issue'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'post_sales_invoice'
      AND p.prosrc LIKE '%commit_sales_bill_stock%'
  ),
  'post_sales_invoice delegates take-path stock to commit_sales_bill_stock'
);

SELECT finish();
ROLLBACK;

-- Stock spine WMS RPC smoke (existence + post_stock_movement supports issue_outbound).

BEGIN;

SELECT plan(8);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'dispatch_delivery_paper'
  ),
  'dispatch_delivery_paper exists'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'approve_stock_physical_count'
  ),
  'approve_stock_physical_count exists'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'record_delivery_paper_short_pick'
  ),
  'record_delivery_paper_short_pick exists'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'stock_movement_type' AND e.enumlabel = 'issue_outbound'
  ),
  'issue_outbound enum label exists'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'post_stock_movement'
      AND p.prosrc LIKE '%issue_outbound%'
  ),
  'post_stock_movement handles issue_outbound'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'post_stock_movement'
      AND p.prosrc LIKE '%vendor_return%'
  ),
  'post_stock_movement handles vendor_return'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'commit_sales_bill_stock'
      AND p.prosrc LIKE '%stock_dispatch_deduct_covers%'
  ),
  'commit_sales_bill_stock checks dispatch coverage'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'stock_physical_counts'
  ),
  'stock_physical_counts table exists'
);

SELECT finish();
ROLLBACK;

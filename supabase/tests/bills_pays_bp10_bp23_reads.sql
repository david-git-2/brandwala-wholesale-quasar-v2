-- BP10 + BP23 kernel reads smoke
BEGIN;

SELECT plan(7);

SELECT has_function(
  'public',
  'list_bills_for_source',
  ARRAY['bigint', 'text', 'text', 'text', 'boolean', 'boolean']
);
SELECT has_function('public', 'list_pays_for_source', ARRAY['bigint', 'text', 'text']);
SELECT has_function('public', 'list_open_on_profile', ARRAY['bigint', 'bigint']);
SELECT has_function('public', '_kernel_bill_open_components', ARRAY['bigint']);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'v_kernel_bill_summaries'
      AND c.relkind = 'v'
  ),
  'v_kernel_bill_summaries view exists'
);

SELECT ok(
  EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'list_bills_desk_page'
      AND (
        p.prosrc LIKE '%v_kernel_bill_summaries%'
        OR p.prosrc LIKE '%open_books%'
      )
  ),
  'desk list uses kernel bill summaries / open_books'
);

SELECT ok(
  (
    SELECT prosrc LIKE '%list_bills_for_source%'
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'get_shipment_settings_finance_bundle'
  ),
  'shipment finance bundle uses list_bills_for_source'
);

SELECT finish();
ROLLBACK;

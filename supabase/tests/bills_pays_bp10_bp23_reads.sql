-- BP10 + BP23 kernel reads smoke
BEGIN;

SELECT plan(8);

SELECT has_function(
  'public',
  'list_bills_for_source',
  ARRAY['bigint', 'text', 'text', 'text', 'boolean', 'boolean']
);
SELECT has_function('public', 'list_pays_for_source', ARRAY['bigint', 'text', 'text']);
SELECT has_function('public', 'list_open_on_profile', ARRAY['bigint', 'bigint']);
SELECT has_function('public', '_kernel_bill_open_components', ARRAY['bigint']);

SELECT has_view('public', 'v_kernel_bill_summaries');

SELECT ok(
  (
    SELECT count(*) > 0
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'v_kernel_bill_summaries'
      AND column_name = 'open_books'
  ),
  'v_kernel_bill_summaries exposes open_books'
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

SELECT ok(
  (
    SELECT prosrc LIKE '%v_kernel_bill_summaries%'
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'list_bills_desk_page'
  ),
  'desk list joins v_kernel_bill_summaries'
);

SELECT finish();
ROLLBACK;

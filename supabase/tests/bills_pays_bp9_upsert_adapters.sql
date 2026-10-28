-- BP9: kernel upsert adapters smoke
BEGIN;

SELECT plan(5);

SELECT has_function('public', '_kernel_upsert_compose_draft', ARRAY['jsonb']);
SELECT has_function('public', '_kernel_update_compose_draft', ARRAY['bigint', 'bigint', 'jsonb']);
SELECT has_function('public', '_kernel_upsert_dropship_courier_ap', ARRAY['bigint', 'boolean']);
SELECT has_function('public', '_kernel_issue_wholesale_stock', ARRAY['bigint', 'jsonb']);

SELECT ok(
  (
    SELECT prosrc NOT LIKE '%create_sales_invoice_from_payload%'
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'upsert_draft_bill'
  ),
  'upsert_draft_bill does not call create_sales_invoice_from_payload'
);

SELECT finish();
ROLLBACK;

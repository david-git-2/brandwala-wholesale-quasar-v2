-- Smoke: desk wrapper EXECUTE grants
BEGIN;
SELECT plan(4);

SELECT ok(
  pg_catalog.has_function_privilege('authenticated', 'public.update_draft_bill(bigint, bigint, jsonb)', 'EXECUTE'),
  'update_draft_bill executable'
);
SELECT ok(
  pg_catalog.has_function_privilege('authenticated', 'public.issue_wholesale_bill(bigint, jsonb)', 'EXECUTE'),
  'issue_wholesale_bill executable'
);
SELECT ok(
  pg_catalog.has_function_privilege('authenticated', 'public.issue_retail_bill(bigint)', 'EXECUTE'),
  'issue_retail_bill executable'
);
SELECT ok(
  pg_catalog.has_function_privilege(
    'authenticated',
    'public.list_bills_desk_page(bigint, bigint, text, text, text, text, text, integer, bigint)',
    'EXECUTE'
  ),
  'list_bills_desk_page executable'
);

SELECT finish();
ROLLBACK;

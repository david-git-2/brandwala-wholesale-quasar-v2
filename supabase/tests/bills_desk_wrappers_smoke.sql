-- Smoke: desk wrapper functions exist and delegate (no fixture bill required for compile)
BEGIN;
SELECT pg_catalog.has_function_privilege('authenticated', 'public.update_draft_bill(bigint, bigint, jsonb)', 'EXECUTE') AS can_update_draft;
SELECT pg_catalog.has_function_privilege('authenticated', 'public.issue_wholesale_bill(bigint, jsonb)', 'EXECUTE') AS can_issue_wholesale;
SELECT pg_catalog.has_function_privilege('authenticated', 'public.issue_retail_bill(bigint)', 'EXECUTE') AS can_issue_retail;
SELECT pg_catalog.has_function_privilege(
  'authenticated',
  'public.list_bills_desk_page(bigint, bigint, text, text, text, text, text, integer, bigint)',
  'EXECUTE'
) AS can_list_bills_desk;
ROLLBACK;

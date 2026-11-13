-- Desk kernel bridge (list + detail)
BEGIN;

SELECT plan(3);

SELECT has_function(
  'public',
  'get_bill_detail_bundle',
  ARRAY['bigint', 'bigint']
);

SELECT has_function(
  'public',
  'list_bills_desk_page',
  ARRAY['bigint', 'text', 'bigint', 'text', 'text', 'text', 'integer', 'bigint']
);

SELECT has_function(
  'public',
  '_get_bill_detail_bundle_from_kernel',
  ARRAY['bigint', 'bigint']
);

SELECT finish();
ROLLBACK;

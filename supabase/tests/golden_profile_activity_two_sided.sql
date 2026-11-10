-- BP26: profile activity read smoke (two-sided pays exist).
BEGIN;
SELECT plan(2);

SELECT has_function(
  'public',
  'list_profile_activity_for_staff',
  ARRAY['bigint', 'text', 'bigint', 'text', 'integer', 'text'],
  'list_profile_activity_for_staff exists'
);

SELECT has_function(
  'public',
  '_kernel_pay_direction_party',
  ARRAY['text', 'text'],
  'party pay direction helper exists'
);

SELECT finish();
ROLLBACK;

BEGIN;
SELECT plan(4);

SELECT is(
  (
    SELECT count(*)::int
    FROM information_schema.columns
    WHERE table_schema IN ('public', 'money_kernel')
      AND column_name = 'parent_tenant_id'
  ),
  0,
  'no parent_tenant_id columns in public or money_kernel'
);

SELECT is(
  (
    SELECT count(*)::int
    FROM pg_views v
    JOIN pg_namespace n ON n.nspname = v.schemaname
    WHERE n.nspname IN ('public', 'money_kernel')
      AND pg_get_viewdef((quote_ident(v.schemaname) || '.' || quote_ident(v.viewname))::regclass, true)
          ~ '\mparent_tenant_id\M'
  ),
  0,
  'no parent_tenant_id in view definitions'
);

SELECT is(
  (
    SELECT count(*)::int
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('public', 'money_kernel')
      AND p.prosrc ~ '\mparent_tenant_id\M'
      AND p.proname NOT LIKE '\_test%'
  ),
  0,
  'no parent_tenant_id in function bodies (except _test_*)'
);

SELECT is(
  (
    SELECT count(*)::int
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND 'p_parent_tenant_id' = ANY (p.proargnames)
  ),
  0,
  'no p_parent_tenant_id function arguments'
);

SELECT * FROM finish();
ROLLBACK;
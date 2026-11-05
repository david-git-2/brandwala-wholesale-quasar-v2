-- Read-only. Run on linked prod before Phase 0 copy (cutover 11a).
-- Does not write. Use decision row to choose RUN_COPY vs SKIP_COPY.
-- Dashboard: paste whole file (no psql \set lines).

SELECT 'linked_check_tenant_tree' AS step, id, name, parent_id, slug
FROM public.tenants
WHERE id IN (10, 11, 15) OR parent_id = 15
ORDER BY id;

SELECT 'dual_table_tenant_columns' AS step, c.table_name, c.column_name
FROM information_schema.columns c
WHERE c.table_schema = 'public'
  AND c.table_name IN (
    'shop_orders',
    'shops',
    'recipient_profiles',
    'product_brands',
    'product_categories',
    'preorder_demand',
    'customer_groups',
    'cashbook_accounts',
    'cashbook_entries',
    'global_invoice_items',
    'global_return_items',
    'invoice_write_offs'
  )
  AND c.column_name IN ('tenant_id', 'parent_tenant_id')
ORDER BY c.table_name, c.column_name;

SELECT 'decision' AS step,
  CASE
    WHEN EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'shops'
        AND column_name = 'parent_tenant_id'
    )
    THEN 'RUN_COPY — dual column still on prod; run tenant_id_copy_parent.sql → apply → verify (Prod SQL sequence steps 2–4)'
    ELSE 'SKIP_COPY — shops.parent_tenant_id is gone (phase 4+ already on prod); do not run apply; document skip and continue to 11b backend:prod'
  END AS guidance;

SELECT 'pending_cutover_migrations_on_repo' AS step,
  EXISTS (
    SELECT 1
    FROM supabase_migrations.schema_migrations sm
    WHERE sm.version = '20261106120000'
  ) AS phase10_applied_on_this_db,
  (
    SELECT max(sm.version)
    FROM supabase_migrations.schema_migrations sm
  ) AS latest_migration_version;

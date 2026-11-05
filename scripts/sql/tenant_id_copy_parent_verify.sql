-- Expect no leftover child/null tenant_id under parent 15, except skipped
-- recipient_profiles phone collisions.

SELECT 'dual_still_mismatch_parent_15' AS check_name, u.table_name, u.n
FROM (
  SELECT 'shop_orders'::text AS table_name, count(*)::bigint AS n
  FROM public.shop_orders
  WHERE parent_tenant_id = 15
    AND tenant_id IS DISTINCT FROM 15
    AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
  UNION ALL
  SELECT 'shops', count(*)
  FROM public.shops
  WHERE parent_tenant_id = 15
    AND tenant_id IS DISTINCT FROM 15
    AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
  UNION ALL
  SELECT 'product_brands', count(*)
  FROM public.product_brands
  WHERE parent_tenant_id = 15
    AND tenant_id IS DISTINCT FROM 15
    AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
  UNION ALL
  SELECT 'product_categories', count(*)
  FROM public.product_categories
  WHERE parent_tenant_id = 15
    AND tenant_id IS DISTINCT FROM 15
    AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
  UNION ALL
  SELECT 'preorder_demand', count(*)
  FROM public.preorder_demand
  WHERE parent_tenant_id = 15
    AND tenant_id IS DISTINCT FROM 15
    AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
  UNION ALL
  SELECT 'customer_groups', count(*)
  FROM public.customer_groups
  WHERE parent_tenant_id = 15
    AND tenant_id IS DISTINCT FROM 15
    AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
  UNION ALL
  SELECT 'cashbook_accounts', count(*)
  FROM public.cashbook_accounts
  WHERE parent_tenant_id = 15
    AND tenant_id IS DISTINCT FROM 15
    AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
  UNION ALL
  SELECT 'cashbook_entries', count(*)
  FROM public.cashbook_entries
  WHERE parent_tenant_id = 15
    AND tenant_id IS DISTINCT FROM 15
    AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
  UNION ALL
  SELECT 'global_invoice_items', count(*)
  FROM public.global_invoice_items
  WHERE parent_tenant_id = 15
    AND tenant_id IS DISTINCT FROM 15
    AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
  UNION ALL
  SELECT 'global_return_items', count(*)
  FROM public.global_return_items
  WHERE parent_tenant_id = 15
    AND tenant_id IS DISTINCT FROM 15
    AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
  UNION ALL
  SELECT 'invoice_write_offs', count(*)
  FROM public.invoice_write_offs
  WHERE parent_tenant_id = 15
    AND tenant_id IS DISTINCT FROM 15
    AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
  UNION ALL
  SELECT 'recipient_profiles', count(*)
  FROM public.recipient_profiles
  WHERE parent_tenant_id = 15
    AND tenant_id IS DISTINCT FROM 15
    AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
) u
WHERE u.n > 0
ORDER BY 2;

SELECT 'other_companies_untouched' AS check_name, parent_tenant_id, tenant_id, count(*) AS n
FROM public.customer_groups
WHERE parent_tenant_id IS DISTINCT FROM 15
GROUP BY 2, 3
ORDER BY 2, 3;

SELECT 'shop_orders_tenant_not_15_when_parent_15' AS check_name, tenant_id, count(*) AS n
FROM public.shop_orders
WHERE parent_tenant_id = 15 AND tenant_id IS DISTINCT FROM 15
GROUP BY tenant_id;

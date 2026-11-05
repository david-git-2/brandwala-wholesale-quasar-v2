-- Preview only. Apply: tenant_id_copy_parent_apply.sql
-- Scope: parent_tenant_id = 15 (BW). Child tenant_id in {10, 11} or null.
-- Does not touch other companies (local customer_groups 8 / 17 stay).

\set ON_ERROR_STOP on

SELECT 'scope_tenants' AS step, id, name, parent_id
FROM public.tenants
WHERE id IN (10, 11, 15) OR parent_id = 15
ORDER BY id;

SELECT 'preview_mismatches' AS step;

SELECT 'shop_orders' AS table_name, tenant_id, parent_tenant_id, count(*) AS n
FROM public.shop_orders
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
GROUP BY 1, 2, 3
UNION ALL
SELECT 'shops', tenant_id, parent_tenant_id, count(*)
FROM public.shops
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
GROUP BY 1, 2, 3
UNION ALL
SELECT 'recipient_profiles', tenant_id, parent_tenant_id, count(*)
FROM public.recipient_profiles
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
GROUP BY 1, 2, 3
UNION ALL
SELECT 'product_brands', tenant_id, parent_tenant_id, count(*)
FROM public.product_brands
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
GROUP BY 1, 2, 3
UNION ALL
SELECT 'product_categories', tenant_id, parent_tenant_id, count(*)
FROM public.product_categories
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
GROUP BY 1, 2, 3
UNION ALL
SELECT 'preorder_demand', tenant_id, parent_tenant_id, count(*)
FROM public.preorder_demand
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
GROUP BY 1, 2, 3
UNION ALL
SELECT 'customer_groups', tenant_id, parent_tenant_id, count(*)
FROM public.customer_groups
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
GROUP BY 1, 2, 3
UNION ALL
SELECT 'cashbook_accounts', tenant_id, parent_tenant_id, count(*)
FROM public.cashbook_accounts
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
GROUP BY 1, 2, 3
UNION ALL
SELECT 'cashbook_entries', tenant_id, parent_tenant_id, count(*)
FROM public.cashbook_entries
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
GROUP BY 1, 2, 3
UNION ALL
SELECT 'global_invoice_items', tenant_id, parent_tenant_id, count(*)
FROM public.global_invoice_items
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
GROUP BY 1, 2, 3
UNION ALL
SELECT 'global_return_items', tenant_id, parent_tenant_id, count(*)
FROM public.global_return_items
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
GROUP BY 1, 2, 3
UNION ALL
SELECT 'invoice_write_offs', tenant_id, parent_tenant_id, count(*)
FROM public.invoice_write_offs
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
GROUP BY 1, 2, 3
ORDER BY 1, 2;

SELECT 'recipient_phone_collisions_if_copied' AS step, phone, array_agg(id) AS ids, array_agg(tenant_id) AS tenants
FROM public.recipient_profiles
WHERE parent_tenant_id = 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL)
GROUP BY phone
HAVING count(DISTINCT tenant_id) > 1
ORDER BY phone;

SELECT 'untouched_other_companies' AS step, 'customer_groups' AS table_name, parent_tenant_id, tenant_id, count(*) AS n
FROM public.customer_groups
WHERE parent_tenant_id IS DISTINCT FROM 15
GROUP BY 2, 3, 4
ORDER BY 3, 4;

SELECT 'dry_run_only — apply with tenant_id_copy_parent_apply.sql' AS note;

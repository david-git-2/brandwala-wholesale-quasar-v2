-- Writes tenant_id = 15 where parent_tenant_id = 15 and tenant_id is a child of 15 (or null).
-- Preview first: tenant_id_copy_parent.sql
-- Replica role: shops/shop_orders triggers must not NULL parent_tenant_id.
-- Prod: abort unless 15 is root and 10 + 11 are its children.

\set ON_ERROR_STOP on

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.tenants WHERE id = 15 AND parent_id IS NULL
  ) THEN
    RAISE EXCEPTION 'tenant 15 is not a root parent';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.tenants WHERE id = 10 AND parent_id = 15
  ) THEN
    RAISE EXCEPTION 'tenant 10 is not a child of 15';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.tenants WHERE id = 11 AND parent_id = 15
  ) THEN
    RAISE EXCEPTION 'tenant 11 is not a child of 15';
  END IF;
END $$;

BEGIN;
SET LOCAL session_replication_role = replica;

UPDATE public.shop_orders
SET tenant_id = parent_tenant_id
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL);

UPDATE public.shops
SET tenant_id = parent_tenant_id
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL);

UPDATE public.product_brands
SET tenant_id = parent_tenant_id
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL);

UPDATE public.product_categories
SET tenant_id = parent_tenant_id
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL);

UPDATE public.preorder_demand
SET tenant_id = parent_tenant_id
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL);

UPDATE public.customer_groups
SET tenant_id = parent_tenant_id
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL);

UPDATE public.cashbook_accounts
SET tenant_id = parent_tenant_id
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL);

UPDATE public.cashbook_entries
SET tenant_id = parent_tenant_id
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL);

UPDATE public.global_invoice_items
SET tenant_id = parent_tenant_id
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL);

UPDATE public.global_return_items
SET tenant_id = parent_tenant_id
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL);

UPDATE public.invoice_write_offs
SET tenant_id = parent_tenant_id
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
  AND (tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR tenant_id IS NULL);

UPDATE public.recipient_profiles rp
SET tenant_id = rp.parent_tenant_id
WHERE rp.parent_tenant_id = 15
  AND rp.tenant_id IS DISTINCT FROM 15
  AND (rp.tenant_id IN (SELECT id FROM public.tenants WHERE parent_id = 15) OR rp.tenant_id IS NULL)
  AND NOT EXISTS (
    SELECT 1
    FROM public.recipient_profiles other
    WHERE other.id <> rp.id
      AND other.phone IS NOT DISTINCT FROM rp.phone
      AND other.parent_tenant_id = 15
      AND other.tenant_id = 15
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.recipient_profiles other
    WHERE other.id <> rp.id
      AND other.id < rp.id
      AND other.phone IS NOT DISTINCT FROM rp.phone
      AND other.parent_tenant_id = 15
      AND other.tenant_id IS DISTINCT FROM 15
  );

COMMIT;

SELECT 'recipient_profiles_still_mismatch' AS step, id, tenant_id, parent_tenant_id, phone, name
FROM public.recipient_profiles
WHERE parent_tenant_id = 15
  AND tenant_id IS DISTINCT FROM 15
ORDER BY phone, id;

-- Migration: 20261122000000_shop_categories_and_shop_attributes.sql
-- Description: Create tenant-scoped shop_categories table and add description + category_ids to shops table

BEGIN;

-- 1. Create shop_categories table
CREATE TABLE IF NOT EXISTS public.shop_categories (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL,
  description TEXT DEFAULT NULL,
  icon VARCHAR(100) DEFAULT 'category',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_shop_categories_tenant_slug UNIQUE (tenant_id, slug)
);

-- Index for tenant-scoped lookups
CREATE INDEX IF NOT EXISTS idx_shop_categories_tenant ON public.shop_categories(tenant_id, is_active);

-- 2. Enable Row Level Security
ALTER TABLE public.shop_categories ENABLE ROW LEVEL SECURITY;

-- Drop policies if exist to allow clean re-runs
DROP POLICY IF EXISTS shop_categories_select_policy ON public.shop_categories;
DROP POLICY IF EXISTS shop_categories_service_role_policy ON public.shop_categories;
DROP POLICY IF EXISTS shop_categories_staff_manage_policy ON public.shop_categories;

-- Select Policy: Authenticated users can view shop categories for their tenant
CREATE POLICY shop_categories_select_policy ON public.shop_categories
  FOR SELECT
  TO authenticated
  USING (
    tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::bigint
    OR public.is_superadmin()
    OR EXISTS (
      SELECT 1 FROM public.memberships m 
      WHERE m.tenant_id = public.shop_categories.tenant_id
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
    )
    OR EXISTS (
      SELECT 1 FROM public.customer_group_members cgm
      JOIN public.customer_groups cg ON cgm.customer_group_id = cg.id
      WHERE cg.tenant_id = public.shop_categories.tenant_id
        AND lower(trim(cgm.email)) = public.current_user_email()
        AND cgm.is_active = true
        AND cg.is_active = true
    )
  );

-- All operations for Service Role
CREATE POLICY shop_categories_service_role_policy ON public.shop_categories
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Insert/Update/Delete Policy: Staff / Admin Members can manage categories
CREATE POLICY shop_categories_staff_manage_policy ON public.shop_categories
  FOR ALL
  TO authenticated
  USING (
    public.is_superadmin()
    OR EXISTS (
      SELECT 1 FROM public.memberships m 
      WHERE m.tenant_id = public.shop_categories.tenant_id
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
        AND m.role IN ('admin', 'staff', 'superadmin')
    )
  )
  WITH CHECK (
    public.is_superadmin()
    OR EXISTS (
      SELECT 1 FROM public.memberships m 
      WHERE m.tenant_id = public.shop_categories.tenant_id
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
        AND m.role IN ('admin', 'staff', 'superadmin')
    )
  );

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON public.shop_categories TO authenticated;
GRANT ALL ON public.shop_categories TO service_role;

-- 3. Add description and category_ids attributes to shops table
ALTER TABLE public.shops 
  ADD COLUMN IF NOT EXISTS description TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS category_ids BIGINT[] DEFAULT '{}';

-- Index for searching shops by category ID array
CREATE INDEX IF NOT EXISTS idx_shops_category_ids ON public.shops USING GIN (category_ids);

COMMIT;

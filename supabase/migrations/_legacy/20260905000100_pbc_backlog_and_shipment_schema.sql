-- Phase 1 Schema Migration for Product Based Costing Backlog and Shipment
-- 1. Alter product_based_costing_files: add billing_profile_id and retarget default_shipment_id FK to global_shipments

ALTER TABLE public.product_based_costing_files
  ADD COLUMN IF NOT EXISTS billing_profile_id bigint NULL REFERENCES public.billing_profiles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS product_based_costing_files_billing_profile_id_idx
  ON public.product_based_costing_files (billing_profile_id);

-- Cleanup invalid FK values on product_based_costing_files.default_shipment_id before FK retargeting
UPDATE public.product_based_costing_files
SET default_shipment_id = NULL
WHERE default_shipment_id IS NOT NULL
  AND default_shipment_id NOT IN (SELECT id FROM public.global_shipments);

-- Retarget FK constraint on product_based_costing_files.default_shipment_id to global_shipments(id)
ALTER TABLE public.product_based_costing_files
  DROP CONSTRAINT IF EXISTS product_based_costing_files_default_shipment_id_fkey;

ALTER TABLE public.product_based_costing_files
  ADD CONSTRAINT product_based_costing_files_default_shipment_id_fkey
  FOREIGN KEY (default_shipment_id)
  REFERENCES public.global_shipments(id)
  ON DELETE SET NULL;


-- 2. Alter product_based_costing_items: cleanup and retarget assigned_shipment_id FK to global_shipments

UPDATE public.product_based_costing_items
SET assigned_shipment_id = NULL
WHERE assigned_shipment_id IS NOT NULL
  AND assigned_shipment_id NOT IN (SELECT id FROM public.global_shipments);

ALTER TABLE public.product_based_costing_items
  DROP CONSTRAINT IF EXISTS product_based_costing_items_assigned_shipment_id_fkey;

ALTER TABLE public.product_based_costing_items
  ADD CONSTRAINT product_based_costing_items_assigned_shipment_id_fkey
  FOREIGN KEY (assigned_shipment_id)
  REFERENCES public.global_shipments(id)
  ON DELETE SET NULL;


-- 3. Create table product_based_costing_backlog_items
CREATE TABLE IF NOT EXISTS public.product_based_costing_backlog_items (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id bigint NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  billing_profile_id bigint NOT NULL REFERENCES public.billing_profiles(id) ON DELETE CASCADE,
  product_id bigint NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  open_quantity int NOT NULL CHECK (open_quantity > 0),
  name text NOT NULL,
  image_url text NULL,
  barcode text NULL,
  product_code text NULL,
  price_gbp numeric NULL,
  product_weight numeric NULL,
  package_weight numeric NULL,
  note text NULL,
  last_costing_file_id bigint NULL REFERENCES public.product_based_costing_files(id) ON DELETE SET NULL,
  last_costing_item_id bigint NULL REFERENCES public.product_based_costing_items(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_pbc_backlog_tenant_profile_product UNIQUE (tenant_id, billing_profile_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_pbc_backlog_tenant_profile
  ON public.product_based_costing_backlog_items (tenant_id, billing_profile_id);

-- RLS setup for product_based_costing_backlog_items
ALTER TABLE public.product_based_costing_backlog_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Tenant members can select product_based_costing_backlog_items" ON public.product_based_costing_backlog_items;
CREATE POLICY "Tenant members can select product_based_costing_backlog_items"
  ON public.product_based_costing_backlog_items
  FOR SELECT
  TO authenticated
  USING (
    public.can_admin_manage_costing_file(tenant_id)
    OR public.can_staff_access_costing_file(tenant_id)
  );

DROP POLICY IF EXISTS "Tenant members can insert product_based_costing_backlog_items" ON public.product_based_costing_backlog_items;
CREATE POLICY "Tenant members can insert product_based_costing_backlog_items"
  ON public.product_based_costing_backlog_items
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.can_admin_manage_costing_file(tenant_id)
    OR public.can_staff_access_costing_file(tenant_id)
  );

DROP POLICY IF EXISTS "Tenant members can update product_based_costing_backlog_items" ON public.product_based_costing_backlog_items;
CREATE POLICY "Tenant members can update product_based_costing_backlog_items"
  ON public.product_based_costing_backlog_items
  FOR UPDATE
  TO authenticated
  USING (
    public.can_admin_manage_costing_file(tenant_id)
    OR public.can_staff_access_costing_file(tenant_id)
  );

DROP POLICY IF EXISTS "Tenant members can delete product_based_costing_backlog_items" ON public.product_based_costing_backlog_items;
CREATE POLICY "Tenant members can delete product_based_costing_backlog_items"
  ON public.product_based_costing_backlog_items
  FOR DELETE
  TO authenticated
  USING (
    public.can_admin_manage_costing_file(tenant_id)
    OR public.can_staff_access_costing_file(tenant_id)
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.product_based_costing_backlog_items TO authenticated;

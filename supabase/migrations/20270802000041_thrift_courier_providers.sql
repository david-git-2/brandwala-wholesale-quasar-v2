-- Migration: thrift_courier_providers (system BD seed + tenant customs)
-- + invoice courier_provider_id / meta
-- Docs: doc/v2/thrift/sales/schema.md §2b

BEGIN;

-- =========================================================
-- 1. Catalog table
-- =========================================================
CREATE TABLE IF NOT EXISTS public.thrift_courier_providers (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  country_code TEXT NOT NULL DEFAULT 'BD',
  is_system BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 100,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT thrift_courier_providers_code_nonempty CHECK (length(trim(code)) > 0),
  CONSTRAINT thrift_courier_providers_name_nonempty CHECK (length(trim(name)) > 0),
  CONSTRAINT thrift_courier_providers_system_tenant_check CHECK (
    (is_system = TRUE AND tenant_id IS NULL)
    OR (is_system = FALSE AND tenant_id IS NOT NULL)
  )
);

COMMENT ON COLUMN public.thrift_courier_providers.meta IS
  'JSONB extension bag for future extras (notes, website, support_phone, tracking_url_template). Not fee math.';

CREATE UNIQUE INDEX IF NOT EXISTS thrift_courier_providers_system_code_uidx
  ON public.thrift_courier_providers (code)
  WHERE tenant_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS thrift_courier_providers_tenant_code_uidx
  ON public.thrift_courier_providers (tenant_id, code)
  WHERE tenant_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_thrift_courier_providers_picker
  ON public.thrift_courier_providers (is_active, sort_order, name);

COMMENT ON TABLE public.thrift_courier_providers IS
  'System (tenant_id null, is_system) BD catalog + tenant custom couriers for Online sales.';

DROP TRIGGER IF EXISTS trg_thrift_courier_providers_set_updated_at ON public.thrift_courier_providers;
CREATE TRIGGER trg_thrift_courier_providers_set_updated_at
BEFORE UPDATE ON public.thrift_courier_providers
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- Block tenant mutation of system rows (RLS also blocks is_system inserts)
CREATE OR REPLACE FUNCTION public.thrift_courier_providers_guard_system()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.is_system THEN
      RAISE EXCEPTION 'System courier providers cannot be deleted';
    END IF;
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.is_system THEN
      RAISE EXCEPTION 'System courier providers cannot be updated';
    END IF;
    IF NEW.is_system IS DISTINCT FROM FALSE OR NEW.tenant_id IS NULL THEN
      RAISE EXCEPTION 'Tenant courier providers must keep is_system=false and a tenant_id';
    END IF;
    IF NEW.tenant_id IS DISTINCT FROM OLD.tenant_id THEN
      RAISE EXCEPTION 'Cannot move courier provider across tenants';
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_thrift_courier_providers_guard_system ON public.thrift_courier_providers;
CREATE TRIGGER trg_thrift_courier_providers_guard_system
BEFORE UPDATE OR DELETE ON public.thrift_courier_providers
FOR EACH ROW
EXECUTE FUNCTION public.thrift_courier_providers_guard_system();

-- =========================================================
-- 2. BD system seed
-- =========================================================
INSERT INTO public.thrift_courier_providers (
  tenant_id, code, name, country_code, is_system, is_active, sort_order
) VALUES
  (NULL, 'pathao', 'Pathao', 'BD', TRUE, TRUE, 10),
  (NULL, 'steadfast', 'Steadfast', 'BD', TRUE, TRUE, 20),
  (NULL, 'redx', 'RedX', 'BD', TRUE, TRUE, 30),
  (NULL, 'paperfly', 'Paperfly', 'BD', TRUE, TRUE, 40),
  (NULL, 'ecourier', 'eCourier', 'BD', TRUE, TRUE, 50),
  (NULL, 'deliveryman', 'Deliveryman', 'BD', TRUE, TRUE, 60),
  (NULL, 'sundarban', 'Sundarban Courier', 'BD', TRUE, TRUE, 70),
  (NULL, 'sa_paribahan', 'SA Paribahan', 'BD', TRUE, TRUE, 80),
  (NULL, 'karatoa', 'Karatoa Courier', 'BD', TRUE, TRUE, 90),
  (NULL, 'janani', 'Janani Courier', 'BD', TRUE, TRUE, 100),
  (NULL, 'fastbee', 'FastBee', 'BD', TRUE, TRUE, 110)
ON CONFLICT (code) WHERE (tenant_id IS NULL) DO UPDATE SET
  name = EXCLUDED.name,
  sort_order = EXCLUDED.sort_order,
  is_active = TRUE,
  updated_at = NOW();

-- =========================================================
-- 3. Invoice columns
-- =========================================================
ALTER TABLE public.thrift_sales_invoices
  ADD COLUMN IF NOT EXISTS courier_provider_id BIGINT
    REFERENCES public.thrift_courier_providers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS meta JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_thrift_sales_invoices_courier_provider
  ON public.thrift_sales_invoices (courier_provider_id)
  WHERE courier_provider_id IS NOT NULL;

COMMENT ON COLUMN public.thrift_sales_invoices.courier_provider_id IS
  'Optional FK to thrift_courier_providers; name also snapshotted in courier_provider.';
COMMENT ON COLUMN public.thrift_sales_invoices.meta IS
  'Optional Online extras (tracking_id, tracking_url). Not fee amounts.';

-- =========================================================
-- 4. RLS
-- =========================================================
ALTER TABLE public.thrift_courier_providers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS thrift_courier_providers_select ON public.thrift_courier_providers;
CREATE POLICY thrift_courier_providers_select
  ON public.thrift_courier_providers
  FOR SELECT
  TO authenticated
  USING (
    (
      tenant_id IS NULL
      AND is_system = TRUE
      AND EXISTS (
        SELECT 1
        FROM public.memberships m
        WHERE lower(trim(m.email)) = public.current_user_email()
          AND m.is_active = TRUE
      )
    )
    OR (
      tenant_id IS NOT NULL
      AND (
        public.membership_has_module_action(tenant_id, 'thrift_sales', 'view')
        OR public.membership_has_module_action(tenant_id, 'thrift_settings', 'view')
      )
    )
  );

DROP POLICY IF EXISTS thrift_courier_providers_insert ON public.thrift_courier_providers;
CREATE POLICY thrift_courier_providers_insert
  ON public.thrift_courier_providers
  FOR INSERT
  TO authenticated
  WITH CHECK (
    is_system = FALSE
    AND tenant_id IS NOT NULL
    AND (
      public.membership_has_module_action(tenant_id, 'thrift_sales', 'create')
      OR public.membership_has_module_action(tenant_id, 'thrift_sales', 'edit')
      OR public.membership_has_module_action(tenant_id, 'thrift_settings', 'edit')
    )
  );

DROP POLICY IF EXISTS thrift_courier_providers_update ON public.thrift_courier_providers;
CREATE POLICY thrift_courier_providers_update
  ON public.thrift_courier_providers
  FOR UPDATE
  TO authenticated
  USING (
    is_system = FALSE
    AND tenant_id IS NOT NULL
    AND (
      public.membership_has_module_action(tenant_id, 'thrift_sales', 'create')
      OR public.membership_has_module_action(tenant_id, 'thrift_sales', 'edit')
      OR public.membership_has_module_action(tenant_id, 'thrift_settings', 'edit')
    )
  )
  WITH CHECK (
    is_system = FALSE
    AND tenant_id IS NOT NULL
    AND (
      public.membership_has_module_action(tenant_id, 'thrift_sales', 'create')
      OR public.membership_has_module_action(tenant_id, 'thrift_sales', 'edit')
      OR public.membership_has_module_action(tenant_id, 'thrift_settings', 'edit')
    )
  );

DROP POLICY IF EXISTS thrift_courier_providers_delete ON public.thrift_courier_providers;
CREATE POLICY thrift_courier_providers_delete
  ON public.thrift_courier_providers
  FOR DELETE
  TO authenticated
  USING (
    is_system = FALSE
    AND tenant_id IS NOT NULL
    AND (
      public.membership_has_module_action(tenant_id, 'thrift_sales', 'edit')
      OR public.membership_has_module_action(tenant_id, 'thrift_sales', 'delete')
      OR public.membership_has_module_action(tenant_id, 'thrift_settings', 'edit')
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.thrift_courier_providers TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.thrift_courier_providers_id_seq TO authenticated;
GRANT ALL ON public.thrift_courier_providers TO service_role;

COMMIT;

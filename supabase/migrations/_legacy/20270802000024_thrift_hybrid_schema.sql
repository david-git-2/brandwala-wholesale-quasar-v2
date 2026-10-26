-- Phase 4: Hybrid desk schema + customer backfill
-- - normalize_thrift_phone (digits-only)
-- - thrift_customers + unique (tenant_id, phone_normalized) + RLS
-- - thrift_sales_invoices: customer_id, sale_channel (default IN_STORE), customer_address
-- - thrift_settings: return_window_days (default 30)
-- - Backfill customers from invoice phones and link invoices
-- No RPC body changes.

BEGIN;

-- =========================================================
-- 1. Phone normalizer (digits-only; empty → '')
-- =========================================================
CREATE OR REPLACE FUNCTION public.normalize_thrift_phone(p_phone text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
$$;

COMMENT ON FUNCTION public.normalize_thrift_phone(text) IS
  'Digits-only thrift customer phone key; empty/null input → empty string.';

REVOKE ALL ON FUNCTION public.normalize_thrift_phone(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.normalize_thrift_phone(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.normalize_thrift_phone(text) TO service_role;

-- =========================================================
-- 2. thrift_customers
-- =========================================================
CREATE TABLE IF NOT EXISTS public.thrift_customers (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  phone_normalized TEXT NOT NULL,
  address TEXT NULL,
  notes TEXT NULL,
  inserted_by TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT thrift_customers_tenant_phone_normalized_key
    UNIQUE (tenant_id, phone_normalized),
  CONSTRAINT thrift_customers_phone_normalized_match_check
    CHECK (
      phone_normalized <> ''
      AND phone_normalized = public.normalize_thrift_phone(phone)
    )
);

CREATE INDEX IF NOT EXISTS idx_thrift_customers_tenant_updated
  ON public.thrift_customers (tenant_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_thrift_customers_tenant_name
  ON public.thrift_customers (tenant_id, name);

DROP TRIGGER IF EXISTS trg_thrift_customers_updated_at ON public.thrift_customers;
CREATE TRIGGER trg_thrift_customers_updated_at
  BEFORE UPDATE ON public.thrift_customers
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.thrift_customers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS select_thrift_customers ON public.thrift_customers;
CREATE POLICY select_thrift_customers
  ON public.thrift_customers
  FOR SELECT
  TO authenticated
  USING (public.membership_has_module_action(tenant_id, 'thrift_sales', 'view'));

DROP POLICY IF EXISTS write_thrift_customers ON public.thrift_customers;
CREATE POLICY write_thrift_customers
  ON public.thrift_customers
  FOR ALL
  TO authenticated
  USING (public.membership_has_module_action(tenant_id, 'thrift_sales', 'edit'))
  WITH CHECK (public.membership_has_module_action(tenant_id, 'thrift_sales', 'edit'));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.thrift_customers TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.thrift_customers_id_seq TO authenticated;

-- =========================================================
-- 3. thrift_sales_invoices hybrid columns
-- =========================================================
ALTER TABLE public.thrift_sales_invoices
  ADD COLUMN IF NOT EXISTS sale_channel TEXT NOT NULL DEFAULT 'IN_STORE',
  ADD COLUMN IF NOT EXISTS customer_id BIGINT NULL,
  ADD COLUMN IF NOT EXISTS customer_address TEXT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'thrift_sales_invoices_sale_channel_check'
      AND conrelid = 'public.thrift_sales_invoices'::regclass
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_sale_channel_check
      CHECK (sale_channel IN ('IN_STORE', 'ONLINE'));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'thrift_sales_invoices_customer_id_fkey'
      AND conrelid = 'public.thrift_sales_invoices'::regclass
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_customer_id_fkey
      FOREIGN KEY (customer_id)
      REFERENCES public.thrift_customers(id)
      ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_thrift_sales_invoices_tenant_customer
  ON public.thrift_sales_invoices (tenant_id, customer_id)
  WHERE customer_id IS NOT NULL;

COMMENT ON COLUMN public.thrift_sales_invoices.sale_channel IS
  'Hybrid desk channel: IN_STORE | ONLINE';
COMMENT ON COLUMN public.thrift_sales_invoices.customer_id IS
  'Linked thrift_customers row when phone was present at sale';
COMMENT ON COLUMN public.thrift_sales_invoices.customer_address IS
  'Sale-day address snapshot';

-- =========================================================
-- 4. thrift_settings.return_window_days
-- =========================================================
ALTER TABLE public.thrift_settings
  ADD COLUMN IF NOT EXISTS return_window_days INTEGER NOT NULL DEFAULT 30;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'thrift_settings_return_window_days_check'
      AND conrelid = 'public.thrift_settings'::regclass
  ) THEN
    ALTER TABLE public.thrift_settings
      ADD CONSTRAINT thrift_settings_return_window_days_check
      CHECK (return_window_days >= 0);
  END IF;
END $$;

COMMENT ON COLUMN public.thrift_settings.return_window_days IS
  'Customer RETURN eligibility window (days) from invoice date; 0 = no customer returns';

-- =========================================================
-- 5. Backfill customers from invoice phones + link
-- =========================================================
INSERT INTO public.thrift_customers (
  tenant_id,
  name,
  phone,
  phone_normalized,
  inserted_by,
  created_at,
  updated_at
)
SELECT DISTINCT ON (inv.tenant_id, public.normalize_thrift_phone(inv.customer_phone))
  inv.tenant_id,
  COALESCE(NULLIF(trim(inv.customer_name), ''), 'Customer'),
  inv.customer_phone,
  public.normalize_thrift_phone(inv.customer_phone),
  COALESCE(NULLIF(trim(inv.created_by), ''), 'backfill'),
  NOW(),
  NOW()
FROM public.thrift_sales_invoices inv
WHERE NULLIF(public.normalize_thrift_phone(inv.customer_phone), '') IS NOT NULL
ORDER BY
  inv.tenant_id,
  public.normalize_thrift_phone(inv.customer_phone),
  inv.date DESC NULLS LAST,
  inv.id DESC
ON CONFLICT (tenant_id, phone_normalized) DO NOTHING;

UPDATE public.thrift_sales_invoices inv
SET customer_id = c.id
FROM public.thrift_customers c
WHERE inv.customer_id IS NULL
  AND c.tenant_id = inv.tenant_id
  AND NULLIF(public.normalize_thrift_phone(inv.customer_phone), '') IS NOT NULL
  AND c.phone_normalized = public.normalize_thrift_phone(inv.customer_phone);

COMMIT;

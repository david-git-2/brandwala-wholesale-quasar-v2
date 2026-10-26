-- Migration: Thrift sales economics — invoice close fields + PnL lines + post-pay returns
-- Docs: doc/v2/thrift/sales/schema.md · task.md phase 1
-- Does NOT alter thrift_shipments / thrift_stocks / costing RPCs.
-- RPCs that write PnL/returns are follow-up migrations.

BEGIN;

-- =========================================================
-- 1. thrift_sales_invoices — fee/close columns
-- =========================================================
ALTER TABLE public.thrift_sales_invoices
  ADD COLUMN IF NOT EXISTS courier_provider TEXT,
  ADD COLUMN IF NOT EXISTS cod_fee_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS cod_fee_paid_by TEXT,
  ADD COLUMN IF NOT EXISTS packing_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS packing_paid_by TEXT,
  ADD COLUMN IF NOT EXISTS return_courier_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS close_reason TEXT,
  ADD COLUMN IF NOT EXISTS economics_closed_at TIMESTAMPTZ;

DO $$
BEGIN
  -- Status: allow PARTIALLY_RETURNED (keep STAFF_MISTAKE for legacy rows)
  IF EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'thrift_sales_invoices_status_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      DROP CONSTRAINT thrift_sales_invoices_status_check;
  END IF;

  ALTER TABLE public.thrift_sales_invoices
    ADD CONSTRAINT thrift_sales_invoices_status_check
    CHECK (status IN ('ACTIVE', 'PARTIALLY_RETURNED', 'RETURNED', 'STAFF_MISTAKE'));

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'thrift_sales_invoices_cod_fee_amount_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_cod_fee_amount_check
      CHECK (cod_fee_amount >= 0);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'thrift_sales_invoices_packing_amount_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_packing_amount_check
      CHECK (packing_amount >= 0);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'thrift_sales_invoices_return_courier_amount_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_return_courier_amount_check
      CHECK (return_courier_amount >= 0);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'thrift_sales_invoices_cod_fee_paid_by_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_cod_fee_paid_by_check
      CHECK (
        cod_fee_paid_by IS NULL
        OR cod_fee_paid_by IN ('CUSTOMER', 'SHOP')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'thrift_sales_invoices_packing_paid_by_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_packing_paid_by_check
      CHECK (
        packing_paid_by IS NULL
        OR packing_paid_by IN ('CUSTOMER', 'SHOP')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'thrift_sales_invoices_cod_fee_payer_consistency_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_cod_fee_payer_consistency_check
      CHECK (
        (cod_fee_amount > 0 AND cod_fee_paid_by IS NOT NULL)
        OR (cod_fee_amount = 0 AND cod_fee_paid_by IS NULL)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'thrift_sales_invoices_packing_payer_consistency_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_packing_payer_consistency_check
      CHECK (
        (packing_amount > 0 AND packing_paid_by IS NOT NULL)
        OR (packing_amount = 0 AND packing_paid_by IS NULL)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'thrift_sales_invoices_close_reason_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_close_reason_check
      CHECK (
        close_reason IS NULL
        OR close_reason IN ('RTO', 'CUSTOMER_RETURN')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'thrift_sales_invoices_payment_status_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_payment_status_check
      CHECK (
        payment_status IN (
          'PAID',
          'COD_PENDING',
          'PARTIALLY_REFUNDED',
          'REFUNDED',
          'WRITTEN_OFF',
          'UNPAID'
        )
      );
  END IF;
END $$;

COMMENT ON COLUMN public.thrift_sales_invoices.courier_provider IS
  'Online optional courier company name; Offline null.';
COMMENT ON COLUMN public.thrift_sales_invoices.cod_fee_amount IS
  'Courier COD service fee (staff-entered ৳), not a stored %.';
COMMENT ON COLUMN public.thrift_sales_invoices.packing_amount IS
  'Packing / print charge.';
COMMENT ON COLUMN public.thrift_sales_invoices.return_courier_amount IS
  'RTO / no-pickup return courier billed to shop (post-pay returns use thrift_sales_returns).';
COMMENT ON COLUMN public.thrift_sales_invoices.close_reason IS
  'RTO | CUSTOMER_RETURN when fully closed; null while open or partially returned.';
COMMENT ON COLUMN public.thrift_sales_invoices.economics_closed_at IS
  'Last time thrift_sales_pnl_lines were written/updated for this invoice.';

CREATE INDEX IF NOT EXISTS idx_thrift_sales_invoices_tenant_close_reason
  ON public.thrift_sales_invoices (tenant_id, close_reason)
  WHERE close_reason IS NOT NULL;

-- =========================================================
-- 2. thrift_sales_pnl_lines
-- =========================================================
CREATE TABLE IF NOT EXISTS public.thrift_sales_pnl_lines (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  invoice_id BIGINT NOT NULL REFERENCES public.thrift_sales_invoices(id) ON DELETE CASCADE,
  invoice_item_id BIGINT NOT NULL REFERENCES public.thrift_sales_invoice_items(id) ON DELETE CASCADE,
  stock_id BIGINT NOT NULL REFERENCES public.thrift_stocks(id) ON DELETE RESTRICT,
  inbound_shipment_id BIGINT NOT NULL REFERENCES public.thrift_shipments(id) ON DELETE RESTRICT,
  outcome TEXT NOT NULL,
  return_id BIGINT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  sell_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  allocated_shop_delivery NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  allocated_shop_cod_fee NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  allocated_shop_packing NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  allocated_return_courier NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  allocated_fees_total NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  cogs_is_loss BOOLEAN NOT NULL DEFAULT FALSE,
  event_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  event_date DATE NOT NULL DEFAULT ((NOW() AT TIME ZONE 'UTC')::DATE),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT thrift_sales_pnl_lines_invoice_item_key UNIQUE (invoice_item_id),
  CONSTRAINT thrift_sales_pnl_lines_outcome_check
    CHECK (outcome IN ('DELIVERED', 'RTO', 'CUSTOMER_RETURN')),
  CONSTRAINT thrift_sales_pnl_lines_quantity_check CHECK (quantity > 0),
  CONSTRAINT thrift_sales_pnl_lines_sell_amount_check CHECK (sell_amount >= 0),
  CONSTRAINT thrift_sales_pnl_lines_alloc_delivery_check CHECK (allocated_shop_delivery >= 0),
  CONSTRAINT thrift_sales_pnl_lines_alloc_cod_check CHECK (allocated_shop_cod_fee >= 0),
  CONSTRAINT thrift_sales_pnl_lines_alloc_packing_check CHECK (allocated_shop_packing >= 0),
  CONSTRAINT thrift_sales_pnl_lines_alloc_return_check CHECK (allocated_return_courier >= 0),
  CONSTRAINT thrift_sales_pnl_lines_fees_total_check
    CHECK (
      allocated_fees_total
        = allocated_shop_delivery
        + allocated_shop_cod_fee
        + allocated_shop_packing
        + allocated_return_courier
    )
);

COMMENT ON TABLE public.thrift_sales_pnl_lines IS
  'Per invoice-line economics fact for reports. COGS stays live via stock→inbound shipment.';

CREATE INDEX IF NOT EXISTS idx_thrift_sales_pnl_lines_tenant_event_date
  ON public.thrift_sales_pnl_lines (tenant_id, event_date DESC);

CREATE INDEX IF NOT EXISTS idx_thrift_sales_pnl_lines_shipment
  ON public.thrift_sales_pnl_lines (tenant_id, inbound_shipment_id, event_date DESC);

CREATE INDEX IF NOT EXISTS idx_thrift_sales_pnl_lines_invoice
  ON public.thrift_sales_pnl_lines (invoice_id);

CREATE INDEX IF NOT EXISTS idx_thrift_sales_pnl_lines_outcome
  ON public.thrift_sales_pnl_lines (tenant_id, outcome);

DROP TRIGGER IF EXISTS trg_thrift_sales_pnl_lines_set_updated_at ON public.thrift_sales_pnl_lines;
CREATE TRIGGER trg_thrift_sales_pnl_lines_set_updated_at
BEFORE UPDATE ON public.thrift_sales_pnl_lines
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- =========================================================
-- 3. thrift_sales_returns + items
-- =========================================================
CREATE TABLE IF NOT EXISTS public.thrift_sales_returns (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  invoice_id BIGINT NOT NULL REFERENCES public.thrift_sales_invoices(id) ON DELETE CASCADE,
  return_number TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'COMPLETED',
  refund_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  return_courier_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  notes TEXT,
  created_by TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT thrift_sales_returns_tenant_number_key UNIQUE (tenant_id, return_number),
  CONSTRAINT thrift_sales_returns_status_check CHECK (status IN ('COMPLETED')),
  CONSTRAINT thrift_sales_returns_refund_amount_check CHECK (refund_amount >= 0),
  CONSTRAINT thrift_sales_returns_courier_amount_check CHECK (return_courier_amount >= 0)
);

COMMENT ON TABLE public.thrift_sales_returns IS
  'Post-pay / post-delivery returns (partial or full). Not used for RTO no-pickup.';

CREATE TABLE IF NOT EXISTS public.thrift_sales_return_items (
  id BIGSERIAL PRIMARY KEY,
  return_id BIGINT NOT NULL REFERENCES public.thrift_sales_returns(id) ON DELETE CASCADE,
  tenant_id BIGINT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  invoice_item_id BIGINT NOT NULL REFERENCES public.thrift_sales_invoice_items(id) ON DELETE RESTRICT,
  stock_id BIGINT NOT NULL REFERENCES public.thrift_stocks(id) ON DELETE RESTRICT,
  quantity INTEGER NOT NULL DEFAULT 1,
  condition TEXT NOT NULL,
  refund_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT thrift_sales_return_items_invoice_item_key UNIQUE (invoice_item_id),
  CONSTRAINT thrift_sales_return_items_quantity_check CHECK (quantity > 0),
  CONSTRAINT thrift_sales_return_items_condition_check
    CHECK (condition IN ('SELLABLE', 'DAMAGED')),
  CONSTRAINT thrift_sales_return_items_refund_amount_check CHECK (refund_amount >= 0)
);

-- Deferred FK: pnl.return_id → returns (returns created first in app flow)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'thrift_sales_pnl_lines_return_id_fkey'
  ) THEN
    ALTER TABLE public.thrift_sales_pnl_lines
      ADD CONSTRAINT thrift_sales_pnl_lines_return_id_fkey
      FOREIGN KEY (return_id)
      REFERENCES public.thrift_sales_returns(id)
      ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_thrift_sales_returns_tenant_created
  ON public.thrift_sales_returns (tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_thrift_sales_returns_invoice
  ON public.thrift_sales_returns (invoice_id);

CREATE INDEX IF NOT EXISTS idx_thrift_sales_return_items_return
  ON public.thrift_sales_return_items (return_id);

CREATE INDEX IF NOT EXISTS idx_thrift_sales_return_items_stock
  ON public.thrift_sales_return_items (stock_id);

DROP TRIGGER IF EXISTS trg_thrift_sales_returns_set_updated_at ON public.thrift_sales_returns;
CREATE TRIGGER trg_thrift_sales_returns_set_updated_at
BEFORE UPDATE ON public.thrift_sales_returns
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- =========================================================
-- 4. Return number counters (RET-YYYY-MM-#####)
-- =========================================================
CREATE TABLE IF NOT EXISTS public.thrift_return_counters (
  tenant_id BIGINT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  year_month TEXT NOT NULL,
  last_value BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT thrift_return_counters_pkey PRIMARY KEY (tenant_id, year_month),
  CONSTRAINT thrift_return_counters_year_month_check CHECK (year_month ~ '^\d{4}-\d{2}$'),
  CONSTRAINT thrift_return_counters_last_value_check CHECK (last_value >= 0)
);

DROP TRIGGER IF EXISTS trg_thrift_return_counters_set_updated_at ON public.thrift_return_counters;
CREATE TRIGGER trg_thrift_return_counters_set_updated_at
BEFORE UPDATE ON public.thrift_return_counters
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.thrift_return_counters ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.thrift_return_counters FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.thrift_return_counters TO service_role;

-- =========================================================
-- 5. RLS + grants
-- =========================================================
ALTER TABLE public.thrift_sales_pnl_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.thrift_sales_returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.thrift_sales_return_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS thrift_sales_pnl_lines_select ON public.thrift_sales_pnl_lines;
CREATE POLICY thrift_sales_pnl_lines_select
  ON public.thrift_sales_pnl_lines
  FOR SELECT
  TO authenticated
  USING (
    public.membership_has_module_action(tenant_id, 'thrift_sales', 'view')
    OR public.membership_has_module_action(tenant_id, 'thrift_reports', 'view')
  );

DROP POLICY IF EXISTS thrift_sales_pnl_lines_insert ON public.thrift_sales_pnl_lines;
CREATE POLICY thrift_sales_pnl_lines_insert
  ON public.thrift_sales_pnl_lines
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.membership_has_module_action(tenant_id, 'thrift_sales', 'create')
    OR public.membership_has_module_action(tenant_id, 'thrift_sales', 'return')
    OR public.membership_has_module_action(tenant_id, 'thrift_sales', 'edit')
  );

DROP POLICY IF EXISTS thrift_sales_pnl_lines_update ON public.thrift_sales_pnl_lines;
CREATE POLICY thrift_sales_pnl_lines_update
  ON public.thrift_sales_pnl_lines
  FOR UPDATE
  TO authenticated
  USING (
    public.membership_has_module_action(tenant_id, 'thrift_sales', 'return')
    OR public.membership_has_module_action(tenant_id, 'thrift_sales', 'edit')
    OR public.membership_has_module_action(tenant_id, 'thrift_sales', 'create')
  )
  WITH CHECK (
    public.membership_has_module_action(tenant_id, 'thrift_sales', 'return')
    OR public.membership_has_module_action(tenant_id, 'thrift_sales', 'edit')
    OR public.membership_has_module_action(tenant_id, 'thrift_sales', 'create')
  );

DROP POLICY IF EXISTS thrift_sales_pnl_lines_delete ON public.thrift_sales_pnl_lines;
CREATE POLICY thrift_sales_pnl_lines_delete
  ON public.thrift_sales_pnl_lines
  FOR DELETE
  TO authenticated
  USING (
    public.membership_has_module_action(tenant_id, 'thrift_sales', 'staff_mistake')
  );

DROP POLICY IF EXISTS thrift_sales_returns_select ON public.thrift_sales_returns;
CREATE POLICY thrift_sales_returns_select
  ON public.thrift_sales_returns
  FOR SELECT
  TO authenticated
  USING (
    public.membership_has_module_action(tenant_id, 'thrift_sales', 'view')
    OR public.membership_has_module_action(tenant_id, 'thrift_reports', 'view')
  );

DROP POLICY IF EXISTS thrift_sales_returns_insert ON public.thrift_sales_returns;
CREATE POLICY thrift_sales_returns_insert
  ON public.thrift_sales_returns
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.membership_has_module_action(tenant_id, 'thrift_sales', 'return')
    OR public.membership_has_module_action(tenant_id, 'thrift_sales', 'force_return')
  );

DROP POLICY IF EXISTS thrift_sales_returns_update ON public.thrift_sales_returns;
CREATE POLICY thrift_sales_returns_update
  ON public.thrift_sales_returns
  FOR UPDATE
  TO authenticated
  USING (
    public.membership_has_module_action(tenant_id, 'thrift_sales', 'return')
    OR public.membership_has_module_action(tenant_id, 'thrift_sales', 'force_return')
  )
  WITH CHECK (
    public.membership_has_module_action(tenant_id, 'thrift_sales', 'return')
    OR public.membership_has_module_action(tenant_id, 'thrift_sales', 'force_return')
  );

DROP POLICY IF EXISTS thrift_sales_return_items_select ON public.thrift_sales_return_items;
CREATE POLICY thrift_sales_return_items_select
  ON public.thrift_sales_return_items
  FOR SELECT
  TO authenticated
  USING (
    public.membership_has_module_action(tenant_id, 'thrift_sales', 'view')
    OR public.membership_has_module_action(tenant_id, 'thrift_reports', 'view')
  );

DROP POLICY IF EXISTS thrift_sales_return_items_insert ON public.thrift_sales_return_items;
CREATE POLICY thrift_sales_return_items_insert
  ON public.thrift_sales_return_items
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.membership_has_module_action(tenant_id, 'thrift_sales', 'return')
    OR public.membership_has_module_action(tenant_id, 'thrift_sales', 'force_return')
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.thrift_sales_pnl_lines TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.thrift_sales_returns TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.thrift_sales_return_items TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.thrift_sales_pnl_lines_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.thrift_sales_returns_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.thrift_sales_return_items_id_seq TO authenticated;

GRANT ALL ON public.thrift_sales_pnl_lines TO service_role;
GRANT ALL ON public.thrift_sales_returns TO service_role;
GRANT ALL ON public.thrift_sales_return_items TO service_role;

COMMIT;

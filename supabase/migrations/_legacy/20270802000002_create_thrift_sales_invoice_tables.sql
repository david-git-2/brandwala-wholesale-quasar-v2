-- ==========================================
-- Migration: Create Thrift Sales Invoice Tables
-- Timestamp: 20270802000002
-- Description: Create thrift_sales_invoices and thrift_sales_invoice_items tables with RLS and Indexes
-- ==========================================

-- 1. Create thrift_sales_invoices header table
CREATE TABLE IF NOT EXISTS public.thrift_sales_invoices (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  invoice_number TEXT NOT NULL,
  date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  payment_method TEXT NOT NULL DEFAULT 'CASH',
  payment_status TEXT NOT NULL DEFAULT 'PAID',
  total_invoice_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  created_by TEXT NOT NULL DEFAULT '',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT thrift_sales_invoices_tenant_num_key UNIQUE (tenant_id, invoice_number)
);

-- 2. Create thrift_sales_invoice_items line table
CREATE TABLE IF NOT EXISTS public.thrift_sales_invoice_items (
  id BIGSERIAL PRIMARY KEY,
  invoice_id BIGINT NOT NULL REFERENCES public.thrift_sales_invoices(id) ON DELETE CASCADE,
  tenant_id BIGINT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  stock_id BIGINT NOT NULL REFERENCES public.thrift_stocks(id) ON DELETE RESTRICT,
  sell_price NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  final_price NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  quantity INTEGER NOT NULL DEFAULT 1,
  landed_unit_cost_at_sale NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  net_profit NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Indexes for high performance lookup
CREATE INDEX IF NOT EXISTS idx_thrift_sales_invoices_tenant_date ON public.thrift_sales_invoices (tenant_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_thrift_sales_invoice_items_invoice ON public.thrift_sales_invoice_items (invoice_id);
CREATE INDEX IF NOT EXISTS idx_thrift_sales_invoice_items_stock ON public.thrift_sales_invoice_items (stock_id);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.thrift_sales_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.thrift_sales_invoice_items ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies for thrift_sales_invoices
CREATE POLICY "Members can view thrift sales invoices for their tenant"
  ON public.thrift_sales_invoices
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.memberships m
      WHERE m.tenant_id = thrift_sales_invoices.tenant_id
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
    )
  );

CREATE POLICY "Staff and Admins can insert thrift sales invoices"
  ON public.thrift_sales_invoices
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.memberships m
      WHERE m.tenant_id = thrift_sales_invoices.tenant_id
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
        AND m.role IN ('superadmin', 'admin', 'manager', 'staff', 'cashier')
    )
  );

CREATE POLICY "Staff and Admins can update thrift sales invoices"
  ON public.thrift_sales_invoices
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.memberships m
      WHERE m.tenant_id = thrift_sales_invoices.tenant_id
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
        AND m.role IN ('superadmin', 'admin', 'manager', 'staff', 'cashier')
    )
  );

-- 6. RLS Policies for thrift_sales_invoice_items
CREATE POLICY "Members can view thrift sales invoice items"
  ON public.thrift_sales_invoice_items
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.memberships m
      WHERE m.tenant_id = thrift_sales_invoice_items.tenant_id
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
    )
  );

CREATE POLICY "Staff and Admins can insert thrift sales invoice items"
  ON public.thrift_sales_invoice_items
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.memberships m
      WHERE m.tenant_id = thrift_sales_invoice_items.tenant_id
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
        AND m.role IN ('superadmin', 'admin', 'manager', 'staff', 'cashier')
    )
  );

-- 7. Grant Permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.thrift_sales_invoices TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.thrift_sales_invoice_items TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.thrift_sales_invoices_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.thrift_sales_invoice_items_id_seq TO authenticated;

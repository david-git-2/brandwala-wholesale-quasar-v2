-- Migration: Per-tenant monthly thrift invoice numbers
-- Format: INV-YYYY-MM-##### (counter resets each calendar month)

-- ==========================================
-- 1. Monthly counters (server-only)
-- ==========================================
CREATE TABLE IF NOT EXISTS public.thrift_invoice_counters (
  tenant_id BIGINT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  year_month TEXT NOT NULL,
  last_value BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT thrift_invoice_counters_pkey PRIMARY KEY (tenant_id, year_month),
  CONSTRAINT thrift_invoice_counters_year_month_check CHECK (year_month ~ '^\d{4}-\d{2}$'),
  CONSTRAINT thrift_invoice_counters_last_value_check CHECK (last_value >= 0)
);

DROP TRIGGER IF EXISTS trg_thrift_invoice_counters_set_updated_at ON public.thrift_invoice_counters;
CREATE TRIGGER trg_thrift_invoice_counters_set_updated_at
BEFORE UPDATE ON public.thrift_invoice_counters
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.thrift_invoice_counters ENABLE ROW LEVEL SECURITY;

-- No client policies: only SECURITY DEFINER RPCs touch this table.
REVOKE ALL ON public.thrift_invoice_counters FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.thrift_invoice_counters TO service_role;

-- Seed from existing invoices that already match the new format
INSERT INTO public.thrift_invoice_counters (tenant_id, year_month, last_value)
SELECT
  inv.tenant_id,
  substring(inv.invoice_number FROM '^INV-(\d{4}-\d{2})-\d+$'),
  MAX((substring(inv.invoice_number FROM '^INV-\d{4}-\d{2}-(\d+)$'))::BIGINT)
FROM public.thrift_sales_invoices inv
WHERE inv.invoice_number ~ '^INV-\d{4}-\d{2}-\d+$'
GROUP BY inv.tenant_id, substring(inv.invoice_number FROM '^INV-(\d{4}-\d{2})-\d+$')
ON CONFLICT (tenant_id, year_month) DO UPDATE
SET last_value = GREATEST(
  public.thrift_invoice_counters.last_value,
  EXCLUDED.last_value
);

-- ==========================================
-- 2. Generator
-- ==========================================
CREATE OR REPLACE FUNCTION public.generate_thrift_invoice_number(
  p_tenant_id BIGINT,
  p_date TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_year_month TEXT;
  v_next BIGINT;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  v_year_month := to_char(COALESCE(p_date, NOW()), 'YYYY-MM');

  INSERT INTO public.thrift_invoice_counters (tenant_id, year_month, last_value)
  VALUES (p_tenant_id, v_year_month, 1)
  ON CONFLICT (tenant_id, year_month)
  DO UPDATE
    SET last_value = public.thrift_invoice_counters.last_value + 1
  RETURNING last_value INTO v_next;

  RETURN 'INV-' || v_year_month || '-' || lpad(v_next::TEXT, 5, '0');
END;
$$;

REVOKE ALL ON FUNCTION public.generate_thrift_invoice_number(BIGINT, TIMESTAMPTZ) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.generate_thrift_invoice_number(BIGINT, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_thrift_invoice_number(BIGINT, TIMESTAMPTZ) TO service_role;

-- ==========================================
-- 3. create_thrift_sales_invoice — auto number
-- ==========================================
CREATE OR REPLACE FUNCTION public.create_thrift_sales_invoice(
  p_tenant_id BIGINT,
  p_invoice_number TEXT DEFAULT NULL,
  p_customer_name TEXT DEFAULT NULL,
  p_customer_phone TEXT DEFAULT NULL,
  p_date TIMESTAMPTZ DEFAULT NOW(),
  p_payment_method TEXT DEFAULT 'CASH',
  p_payment_status TEXT DEFAULT 'PAID',
  p_notes TEXT DEFAULT NULL,
  p_created_by TEXT DEFAULT 'cashier',
  p_total_invoice_amount NUMERIC(12,2) DEFAULT 0.00,
  p_items JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice_id BIGINT;
  v_invoice_number TEXT;
  v_item JSONB;
  v_stock_id BIGINT;
  v_sell_price NUMERIC(12,2);
  v_discount_amount NUMERIC(12,2);
  v_final_price NUMERIC(12,2);
  v_landed_unit_cost NUMERIC(12,2);
  v_quantity INT;
  v_net_profit NUMERIC(12,2);
  v_updated INT;
BEGIN
  -- Always allocate server-side (ignore client-supplied number)
  v_invoice_number := public.generate_thrift_invoice_number(p_tenant_id, COALESCE(p_date, NOW()));

  INSERT INTO public.thrift_sales_invoices (
    tenant_id,
    invoice_number,
    customer_name,
    customer_phone,
    date,
    payment_method,
    payment_status,
    notes,
    created_by,
    total_invoice_amount,
    status
  ) VALUES (
    p_tenant_id,
    v_invoice_number,
    p_customer_name,
    p_customer_phone,
    p_date,
    p_payment_method,
    p_payment_status,
    p_notes,
    p_created_by,
    p_total_invoice_amount,
    'ACTIVE'
  )
  RETURNING id INTO v_invoice_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_stock_id := (v_item->>'stock_id')::BIGINT;
    v_sell_price := COALESCE((v_item->>'sell_price')::NUMERIC(12,2), 0.00);
    v_discount_amount := COALESCE((v_item->>'discount_amount')::NUMERIC(12,2), 0.00);
    v_final_price := COALESCE((v_item->>'final_price')::NUMERIC(12,2), v_sell_price - v_discount_amount);
    v_landed_unit_cost := COALESCE((v_item->>'landed_unit_cost')::NUMERIC(12,2), 0.00);
    v_quantity := COALESCE((v_item->>'quantity')::INT, 1);
    v_net_profit := COALESCE((v_item->>'net_profit')::NUMERIC(12,2), (v_final_price - v_landed_unit_cost) * v_quantity);

    INSERT INTO public.thrift_sales_invoice_items (
      tenant_id,
      invoice_id,
      stock_id,
      sell_price,
      discount_amount,
      final_price,
      landed_unit_cost_at_sale,
      quantity,
      net_profit
    ) VALUES (
      p_tenant_id,
      v_invoice_id,
      v_stock_id,
      v_sell_price,
      v_discount_amount,
      v_final_price,
      v_landed_unit_cost,
      v_quantity,
      v_net_profit
    );

    UPDATE public.thrift_stocks
    SET
      quantity = GREATEST(0, quantity - v_quantity),
      status = 'SOLD'::public.thrift_stock_status,
      updated_at = NOW()
    WHERE id = v_stock_id
      AND tenant_id = p_tenant_id;

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    IF v_updated = 0 THEN
      RAISE EXCEPTION 'Stock item % not found for tenant %', v_stock_id, p_tenant_id;
    END IF;
  END LOOP;

  INSERT INTO public.thrift_accounting_ledger (
    tenant_id,
    type,
    source,
    reference_id,
    amount,
    note,
    inserted_by,
    date
  ) VALUES (
    p_tenant_id,
    'REVENUE'::public.thrift_ledger_type,
    'INVOICE'::public.thrift_ledger_source,
    v_invoice_id,
    p_total_invoice_amount,
    'Sales Invoice #' || v_invoice_number,
    p_created_by,
    p_date
  );

  RETURN jsonb_build_object(
    'id', v_invoice_id,
    'invoice_number', v_invoice_number,
    'status', 'success'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_thrift_sales_invoice TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_thrift_sales_invoice TO service_role;

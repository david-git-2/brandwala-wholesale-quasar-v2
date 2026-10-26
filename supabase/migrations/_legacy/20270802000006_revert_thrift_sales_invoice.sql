-- Migration: Harden create_thrift_sales_invoice + thrift sales invoice revert (return / staff mistake)
-- Prerequisite: 20270802000005_add_thrift_stock_status_sold.sql (SOLD enum value)
-- 1. Invoice status + revert metadata
-- 2. Harden create_thrift_sales_invoice stock update
-- 3. Backfill stocks already on invoices
-- 4. revert_thrift_sales_invoice RPC

-- ==========================================
-- 1. Invoice status columns
-- ==========================================
ALTER TABLE public.thrift_sales_invoices
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'ACTIVE',
  ADD COLUMN IF NOT EXISTS reverted_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS reverted_by TEXT NULL,
  ADD COLUMN IF NOT EXISTS revert_reason TEXT NULL,
  ADD COLUMN IF NOT EXISTS revert_notes TEXT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'thrift_sales_invoices_status_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_status_check
      CHECK (status IN ('ACTIVE', 'RETURNED', 'STAFF_MISTAKE'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_thrift_sales_invoices_tenant_status
  ON public.thrift_sales_invoices (tenant_id, status);

-- ==========================================
-- 2. Harden create_thrift_sales_invoice
-- ==========================================
CREATE OR REPLACE FUNCTION public.create_thrift_sales_invoice(
  p_tenant_id BIGINT,
  p_invoice_number TEXT,
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
AS $$
DECLARE
  v_invoice_id BIGINT;
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
    p_invoice_number,
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
    'Sales Invoice #' || p_invoice_number,
    p_created_by,
    p_date
  );

  RETURN jsonb_build_object(
    'id', v_invoice_id,
    'invoice_number', p_invoice_number,
    'status', 'success'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_thrift_sales_invoice TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_thrift_sales_invoice TO service_role;

-- ==========================================
-- 3. Backfill stocks already on active invoices
-- ==========================================
UPDATE public.thrift_stocks s
SET
  status = 'SOLD'::public.thrift_stock_status,
  quantity = 0,
  updated_at = NOW()
FROM public.thrift_sales_invoice_items si
JOIN public.thrift_sales_invoices inv ON inv.id = si.invoice_id
WHERE s.id = si.stock_id
  AND s.tenant_id = si.tenant_id
  AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE'
  AND s.status = 'AVAILABLE'::public.thrift_stock_status;

-- ==========================================
-- 4. Revert RPC (RETURN | STAFF_MISTAKE)
-- ==========================================
CREATE OR REPLACE FUNCTION public.revert_thrift_sales_invoice(
  p_tenant_id BIGINT,
  p_invoice_id BIGINT,
  p_reason TEXT,
  p_reverted_by TEXT DEFAULT 'cashier',
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_invoice public.thrift_sales_invoices%ROWTYPE;
  v_item RECORD;
  v_new_status TEXT;
  v_reason TEXT;
BEGIN
  v_reason := upper(trim(COALESCE(p_reason, '')));
  IF v_reason NOT IN ('RETURN', 'STAFF_MISTAKE') THEN
    RAISE EXCEPTION 'Invalid revert reason %. Expected RETURN or STAFF_MISTAKE', p_reason;
  END IF;

  v_new_status := CASE
    WHEN v_reason = 'RETURN' THEN 'RETURNED'
    ELSE 'STAFF_MISTAKE'
  END;

  SELECT * INTO v_invoice
  FROM public.thrift_sales_invoices
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice % not found for tenant %', p_invoice_id, p_tenant_id;
  END IF;

  IF v_invoice.status IS DISTINCT FROM 'ACTIVE' THEN
    RAISE EXCEPTION 'Invoice % is already % and cannot be reverted', p_invoice_id, v_invoice.status;
  END IF;

  FOR v_item IN
    SELECT stock_id, quantity
    FROM public.thrift_sales_invoice_items
    WHERE invoice_id = p_invoice_id
      AND tenant_id = p_tenant_id
  LOOP
    UPDATE public.thrift_stocks
    SET
      quantity = quantity + GREATEST(v_item.quantity, 1),
      status = 'AVAILABLE'::public.thrift_stock_status,
      updated_at = NOW()
    WHERE id = v_item.stock_id
      AND tenant_id = p_tenant_id;
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
    'REFUND'::public.thrift_ledger_type,
    'INVOICE'::public.thrift_ledger_source,
    p_invoice_id,
    v_invoice.total_invoice_amount,
    CASE
      WHEN v_reason = 'RETURN' THEN
        'Return refund for Sales Invoice #' || v_invoice.invoice_number
      ELSE
        'Staff mistake reverse for Sales Invoice #' || v_invoice.invoice_number
    END
      || COALESCE(' — ' || NULLIF(trim(p_notes), ''), ''),
    p_reverted_by,
    NOW()
  );

  UPDATE public.thrift_sales_invoices
  SET
    status = v_new_status,
    payment_status = 'REFUNDED',
    reverted_at = NOW(),
    reverted_by = p_reverted_by,
    revert_reason = v_reason,
    revert_notes = NULLIF(trim(p_notes), ''),
    updated_at = NOW()
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id;

  RETURN jsonb_build_object(
    'id', p_invoice_id,
    'invoice_number', v_invoice.invoice_number,
    'status', v_new_status,
    'reason', v_reason
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.revert_thrift_sales_invoice TO authenticated;
GRANT EXECUTE ON FUNCTION public.revert_thrift_sales_invoice TO service_role;

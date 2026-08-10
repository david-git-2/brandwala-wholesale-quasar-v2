-- Phase 30: Courier fee payer + COD remittance fields
-- - Schema: courier_amount / courier_paid_by / cod_*
-- - create: channel defaults + shop-courier EXPENSE only
-- - revert: clear COD expectation on soft return
-- - record_thrift_cod_remittance: mark remitted → PAID

BEGIN;

-- =========================================================
-- 1. Schema
-- =========================================================
ALTER TABLE public.thrift_sales_invoices
  ADD COLUMN IF NOT EXISTS courier_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS courier_paid_by TEXT NULL,
  ADD COLUMN IF NOT EXISTS cod_expected NUMERIC(12,2) NULL,
  ADD COLUMN IF NOT EXISTS cod_remitted_amount NUMERIC(12,2) NULL,
  ADD COLUMN IF NOT EXISTS cod_remitted_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS cod_remittance_ref TEXT NULL;

-- Backfill from legacy fee column (historical rows).
-- Old create always posted courier as EXPENSE → treat as SHOP-paid.
UPDATE public.thrift_sales_invoices
SET
  courier_amount = COALESCE(courier_cod_amount, 0.00),
  courier_paid_by = CASE
    WHEN COALESCE(courier_cod_amount, 0.00) > 0 THEN COALESCE(courier_paid_by, 'SHOP')
    ELSE NULL
  END
WHERE courier_amount IS DISTINCT FROM COALESCE(courier_cod_amount, 0.00)
   OR (
     COALESCE(courier_cod_amount, 0.00) > 0
     AND courier_paid_by IS NULL
   );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'thrift_sales_invoices_courier_amount_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_courier_amount_check
      CHECK (courier_amount >= 0);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'thrift_sales_invoices_courier_paid_by_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_courier_paid_by_check
      CHECK (
        courier_paid_by IS NULL
        OR courier_paid_by IN ('CUSTOMER', 'SHOP')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'thrift_sales_invoices_courier_payer_amount_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_courier_payer_amount_check
      CHECK (
        (courier_amount > 0 AND courier_paid_by IS NOT NULL)
        OR (courier_amount = 0 AND courier_paid_by IS NULL)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'thrift_sales_invoices_cod_expected_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_cod_expected_check
      CHECK (cod_expected IS NULL OR cod_expected >= 0);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'thrift_sales_invoices_cod_remitted_amount_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_cod_remitted_amount_check
      CHECK (cod_remitted_amount IS NULL OR cod_remitted_amount >= 0);
  END IF;
END $$;

COMMENT ON COLUMN public.thrift_sales_invoices.courier_amount IS
  'Courier fee amount (>= 0). Offline always 0.';
COMMENT ON COLUMN public.thrift_sales_invoices.courier_paid_by IS
  'CUSTOMER | SHOP when courier_amount > 0; null when amount is 0.';
COMMENT ON COLUMN public.thrift_sales_invoices.cod_expected IS
  'COD cash expected from courier (Online COD_PENDING). Null offline / paid-at-create.';
COMMENT ON COLUMN public.thrift_sales_invoices.courier_cod_amount IS
  'DEPRECATED — use courier_amount. Retained for historical rows / reports.';
COMMENT ON COLUMN public.thrift_sales_invoices.other_expense_amount IS
  'DEPRECATED — no longer written by create_thrift_sales_invoice.';

-- =========================================================
-- 2. create_thrift_sales_invoice
-- =========================================================
DROP FUNCTION IF EXISTS public.create_thrift_sales_invoice(
  BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB, TEXT, TEXT, TEXT, NUMERIC, NUMERIC
);

CREATE OR REPLACE FUNCTION public.create_thrift_sales_invoice(
  p_tenant_id BIGINT,
  p_invoice_number TEXT DEFAULT NULL,
  p_customer_name TEXT DEFAULT NULL,
  p_customer_phone TEXT DEFAULT NULL,
  p_date TIMESTAMPTZ DEFAULT NOW(),
  p_payment_method TEXT DEFAULT NULL,
  p_payment_status TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_created_by TEXT DEFAULT 'cashier',
  p_total_invoice_amount NUMERIC(12,2) DEFAULT 0.00,
  p_items JSONB DEFAULT '[]'::jsonb,
  p_sale_channel TEXT DEFAULT 'IN_STORE',
  p_customer_address TEXT DEFAULT NULL,
  p_customer_notes TEXT DEFAULT NULL,
  p_courier_amount NUMERIC(12,2) DEFAULT 0.00,
  p_courier_paid_by TEXT DEFAULT NULL
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
  v_line JSONB;
  v_prepared_items JSONB := '[]'::jsonb;
  v_stock_id BIGINT;
  v_sell_price NUMERIC(12,2);
  v_discount_amount NUMERIC(12,2);
  v_final_price NUMERIC(12,2);
  v_landed_unit_cost NUMERIC(12,2);
  v_quantity INT;
  v_net_profit NUMERIC(12,2);
  v_total_invoice_amount NUMERIC(12,2) := 0.00;
  v_stock public.thrift_stocks%ROWTYPE;
  v_updated INT;
  v_sale_channel TEXT;
  v_phone_normalized TEXT;
  v_customer_id BIGINT := NULL;
  v_customer_display_name TEXT;
  v_courier_amount NUMERIC(12,2);
  v_courier_paid_by TEXT;
  v_payment_method TEXT;
  v_payment_status TEXT;
  v_cod_expected NUMERIC(12,2) := NULL;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create') THEN
    RAISE EXCEPTION 'Creating a thrift sales invoice requires thrift_sales create permission';
  END IF;

  v_invoice_number := public.generate_thrift_invoice_number(p_tenant_id, COALESCE(p_date, NOW()));

  v_sale_channel := COALESCE(NULLIF(trim(p_sale_channel), ''), 'IN_STORE');
  IF v_sale_channel NOT IN ('IN_STORE', 'ONLINE') THEN
    RAISE EXCEPTION 'Invalid sale_channel: % (expected IN_STORE or ONLINE)', v_sale_channel;
  END IF;

  v_courier_amount := ROUND(COALESCE(p_courier_amount, 0.00), 2);
  v_courier_paid_by := NULLIF(upper(trim(COALESCE(p_courier_paid_by, ''))), '');

  IF v_sale_channel = 'IN_STORE' THEN
    -- Offline: no courier / COD; force PAID.
    v_courier_amount := 0.00;
    v_courier_paid_by := NULL;
    v_payment_method := COALESCE(NULLIF(trim(p_payment_method), ''), 'CASH');
    v_payment_status := 'PAID';
    v_cod_expected := NULL;
  ELSE
    IF v_courier_amount < 0 THEN
      RAISE EXCEPTION 'Courier amount cannot be negative';
    END IF;

    IF v_courier_amount > 0 THEN
      IF v_courier_paid_by IS NULL OR v_courier_paid_by NOT IN ('CUSTOMER', 'SHOP') THEN
        RAISE EXCEPTION 'courier_paid_by is required when courier_amount > 0 (CUSTOMER or SHOP)';
      END IF;
    ELSE
      v_courier_paid_by := NULL;
    END IF;

    v_payment_method := COALESCE(NULLIF(trim(p_payment_method), ''), 'COD');
    v_payment_status := COALESCE(NULLIF(upper(trim(p_payment_status)), ''), 'COD_PENDING');
    IF v_payment_status NOT IN ('PAID', 'COD_PENDING', 'UNPAID', 'WRITTEN_OFF', 'REFUNDED') THEN
      RAISE EXCEPTION 'Invalid payment_status: %', v_payment_status;
    END IF;
  END IF;

  v_phone_normalized := public.normalize_thrift_phone(p_customer_phone);
  IF v_phone_normalized <> '' THEN
    v_customer_display_name := COALESCE(NULLIF(trim(p_customer_name), ''), 'Customer');

    INSERT INTO public.thrift_customers (
      tenant_id,
      name,
      phone,
      phone_normalized,
      address,
      notes,
      inserted_by
    ) VALUES (
      p_tenant_id,
      v_customer_display_name,
      COALESCE(NULLIF(trim(p_customer_phone), ''), v_phone_normalized),
      v_phone_normalized,
      p_customer_address,
      p_customer_notes,
      COALESCE(NULLIF(trim(p_created_by), ''), 'cashier')
    )
    ON CONFLICT (tenant_id, phone_normalized) DO UPDATE SET
      phone = EXCLUDED.phone,
      name = CASE
        WHEN NULLIF(trim(p_customer_name), '') IS NOT NULL THEN trim(p_customer_name)
        ELSE public.thrift_customers.name
      END,
      address = CASE
        WHEN p_customer_address IS NOT NULL THEN p_customer_address
        ELSE public.thrift_customers.address
      END,
      notes = CASE
        WHEN p_customer_notes IS NOT NULL THEN p_customer_notes
        ELSE public.thrift_customers.notes
      END,
      updated_at = NOW()
    RETURNING id INTO v_customer_id;
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb))
  LOOP
    v_stock_id := (v_item->>'stock_id')::BIGINT;
    v_sell_price := COALESCE((v_item->>'sell_price')::NUMERIC(12,2), 0.00);
    v_quantity := COALESCE((v_item->>'quantity')::INT, 1);

    IF v_stock_id IS NULL THEN
      RAISE EXCEPTION 'Each line item requires stock_id';
    END IF;

    IF EXISTS (
      SELECT 1
      FROM jsonb_array_elements(v_prepared_items) AS x(line)
      WHERE (x.line->>'stock_id')::BIGINT = v_stock_id
    ) THEN
      RAISE EXCEPTION 'Duplicate stock item % in invoice', v_stock_id;
    END IF;

    IF v_quantity IS NULL OR v_quantity <= 0 THEN
      RAISE EXCEPTION 'Quantity must be positive for stock item %', v_stock_id;
    END IF;

    IF v_sell_price < 0 THEN
      RAISE EXCEPTION 'Sell price cannot be negative for stock item %', v_stock_id;
    END IF;

    v_discount_amount := COALESCE((v_item->>'discount_amount')::NUMERIC(12,2), 0.00);
    v_discount_amount := GREATEST(0.00, LEAST(v_discount_amount, v_sell_price));
    v_final_price := v_sell_price - v_discount_amount;

    SELECT *
    INTO v_stock
    FROM public.thrift_stocks
    WHERE id = v_stock_id
      AND tenant_id = p_tenant_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Stock item % not found for tenant %', v_stock_id, p_tenant_id;
    END IF;

    IF v_stock.status = 'AVAILABLE'::public.thrift_stock_status THEN
      NULL;
    ELSIF v_stock.status = 'RESERVED'::public.thrift_stock_status THEN
      IF v_phone_normalized = ''
         OR COALESCE(v_stock.held_for_phone_normalized, '') = ''
         OR v_stock.held_for_phone_normalized IS DISTINCT FROM v_phone_normalized
      THEN
        RAISE EXCEPTION
          'Stock item % is on hold; sell requires matching customer phone (same hold) or release first',
          v_stock_id;
      END IF;
    ELSE
      RAISE EXCEPTION
        'Stock item % is not AVAILABLE (status=%)',
        v_stock_id,
        v_stock.status;
    END IF;

    IF COALESCE(v_stock.quantity, 0) < v_quantity THEN
      RAISE EXCEPTION
        'Insufficient quantity for stock item % (have %, need %)',
        v_stock_id,
        COALESCE(v_stock.quantity, 0),
        v_quantity;
    END IF;

    v_landed_unit_cost := ROUND(
      COALESCE(public.compute_thrift_landed_unit_cost(v_stock_id), 0.00),
      2
    )::NUMERIC(12,2);
    v_net_profit := (v_final_price - v_landed_unit_cost) * v_quantity;

    v_prepared_items := v_prepared_items || jsonb_build_array(
      jsonb_build_object(
        'stock_id', v_stock_id,
        'sell_price', v_sell_price,
        'discount_amount', v_discount_amount,
        'final_price', v_final_price,
        'landed_unit_cost', v_landed_unit_cost,
        'quantity', v_quantity,
        'net_profit', v_net_profit
      )
    );

    v_total_invoice_amount := v_total_invoice_amount + (v_final_price * v_quantity);
  END LOOP;

  IF jsonb_array_length(v_prepared_items) = 0 THEN
    RAISE EXCEPTION 'Invoice requires at least one line item';
  END IF;

  -- COD expected = customer charge (item + courier when customer pays courier).
  IF v_sale_channel = 'ONLINE' AND v_payment_status = 'COD_PENDING' THEN
    IF v_courier_paid_by = 'CUSTOMER' THEN
      v_cod_expected := ROUND(v_total_invoice_amount + v_courier_amount, 2);
    ELSE
      v_cod_expected := ROUND(v_total_invoice_amount, 2);
    END IF;
  END IF;

  INSERT INTO public.thrift_sales_invoices (
    tenant_id,
    invoice_number,
    customer_name,
    customer_phone,
    customer_address,
    customer_id,
    sale_channel,
    date,
    payment_method,
    payment_status,
    notes,
    created_by,
    total_invoice_amount,
    courier_amount,
    courier_paid_by,
    courier_cod_amount,
    other_expense_amount,
    cod_expected,
    status
  ) VALUES (
    p_tenant_id,
    v_invoice_number,
    p_customer_name,
    p_customer_phone,
    p_customer_address,
    v_customer_id,
    v_sale_channel,
    p_date,
    v_payment_method,
    v_payment_status,
    p_notes,
    p_created_by,
    v_total_invoice_amount,
    v_courier_amount,
    v_courier_paid_by,
    v_courier_amount, -- keep legacy column in sync for report RPC
    0.00,
    v_cod_expected,
    'ACTIVE'
  )
  RETURNING id INTO v_invoice_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(v_prepared_items)
  LOOP
    v_stock_id := (v_line->>'stock_id')::BIGINT;
    v_sell_price := (v_line->>'sell_price')::NUMERIC(12,2);
    v_discount_amount := (v_line->>'discount_amount')::NUMERIC(12,2);
    v_final_price := (v_line->>'final_price')::NUMERIC(12,2);
    v_landed_unit_cost := (v_line->>'landed_unit_cost')::NUMERIC(12,2);
    v_quantity := (v_line->>'quantity')::INT;
    v_net_profit := (v_line->>'net_profit')::NUMERIC(12,2);

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
      quantity = quantity - v_quantity,
      status = 'SOLD'::public.thrift_stock_status,
      updated_at = NOW()
    WHERE id = v_stock_id
      AND tenant_id = p_tenant_id
      AND quantity >= v_quantity
      AND (
        status = 'AVAILABLE'::public.thrift_stock_status
        OR (
          status = 'RESERVED'::public.thrift_stock_status
          AND held_for_phone_normalized IS NOT DISTINCT FROM v_phone_normalized
          AND COALESCE(v_phone_normalized, '') <> ''
        )
      );

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    IF v_updated = 0 THEN
      RAISE EXCEPTION
        'Stock item % became unavailable during sale (tenant %)',
        v_stock_id,
        p_tenant_id;
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
    v_total_invoice_amount,
    'Sales Invoice #' || v_invoice_number,
    p_created_by,
    p_date
  );

  -- Shop-paid courier only (customer-paid is collected via COD, not shop expense).
  IF v_courier_amount > 0 AND v_courier_paid_by = 'SHOP' THEN
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
      'EXPENSE'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      v_invoice_id,
      v_courier_amount,
      'Shop courier for Sales Invoice #' || v_invoice_number,
      p_created_by,
      p_date
    );
  END IF;

  RETURN jsonb_build_object(
    'id', v_invoice_id,
    'invoice_number', v_invoice_number,
    'payment_status', v_payment_status,
    'cod_expected', v_cod_expected,
    'status', 'success'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_thrift_sales_invoice(
  BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB, TEXT, TEXT, TEXT, NUMERIC, TEXT
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_thrift_sales_invoice(
  BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB, TEXT, TEXT, TEXT, NUMERIC, TEXT
) TO service_role;

-- =========================================================
-- 3. revert — clear COD expectation on soft return
-- =========================================================
CREATE OR REPLACE FUNCTION public.revert_thrift_sales_invoice(
  p_tenant_id BIGINT,
  p_invoice_id BIGINT,
  p_reason TEXT,
  p_reverted_by TEXT DEFAULT 'cashier',
  p_notes TEXT DEFAULT NULL,
  p_force BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice public.thrift_sales_invoices%ROWTYPE;
  v_item RECORD;
  v_reason TEXT;
  v_invoice_number TEXT;
  v_return_window_days INTEGER;
  v_force BOOLEAN := COALESCE(p_force, false);
  v_deadline TIMESTAMPTZ;
BEGIN
  v_reason := upper(trim(COALESCE(p_reason, '')));
  IF v_reason NOT IN ('RETURN', 'STAFF_MISTAKE') THEN
    RAISE EXCEPTION 'Invalid revert reason %. Expected RETURN or STAFF_MISTAKE', p_reason;
  END IF;

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

  IF v_reason = 'STAFF_MISTAKE' THEN
    IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'staff_mistake') THEN
      RAISE EXCEPTION 'Staff mistake revert requires thrift_sales staff_mistake permission';
    END IF;
  ELSIF v_reason = 'RETURN' THEN
    IF v_force THEN
      IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'force_return') THEN
        RAISE EXCEPTION
          'Force revert requires thrift_sales force_return permission for tenant %',
          p_tenant_id;
      END IF;
    ELSE
      IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'return') THEN
        RAISE EXCEPTION 'Customer return requires thrift_sales return permission';
      END IF;

      SELECT return_window_days INTO v_return_window_days
      FROM public.thrift_settings
      WHERE tenant_id = p_tenant_id;

      IF NOT FOUND THEN
        v_return_window_days := 30;
      END IF;

      IF v_return_window_days = 0 THEN
        RAISE EXCEPTION
          'Customer returns are disabled (return_window_days=0). Use p_force with thrift_sales force_return, or STAFF_MISTAKE.';
      END IF;

      v_deadline := v_invoice.date + make_interval(days => v_return_window_days);
      IF NOW() > v_deadline THEN
        RAISE EXCEPTION
          'Return window expired: invoice date % + % day(s) ended at %. Use p_force with thrift_sales force_return to override.',
          v_invoice.date,
          v_return_window_days,
          v_deadline;
      END IF;
    END IF;
  END IF;

  v_invoice_number := v_invoice.invoice_number;

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

  IF v_reason = 'STAFF_MISTAKE' THEN
    DELETE FROM public.thrift_accounting_ledger
    WHERE tenant_id = p_tenant_id
      AND source = 'INVOICE'::public.thrift_ledger_source
      AND reference_id = p_invoice_id;

    DELETE FROM public.thrift_sales_invoices
    WHERE id = p_invoice_id
      AND tenant_id = p_tenant_id;

    RETURN jsonb_build_object(
      'id', p_invoice_id,
      'invoice_number', v_invoice_number,
      'status', 'DELETED',
      'reason', v_reason,
      'deleted', true
    );
  END IF;

  -- Soft return: refund item total only (not shop courier — that EXPENSE is deleted).
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
    'Return refund for Sales Invoice #' || v_invoice_number
      || COALESCE(' — ' || NULLIF(trim(p_notes), ''), ''),
    p_reverted_by,
    NOW()
  );

  -- Deletes shop-courier EXPENSE (and any legacy fee expenses).
  DELETE FROM public.thrift_accounting_ledger
  WHERE tenant_id = p_tenant_id
    AND source = 'INVOICE'::public.thrift_ledger_source
    AND reference_id = p_invoice_id
    AND type = 'EXPENSE'::public.thrift_ledger_type;

  UPDATE public.thrift_sales_invoices
  SET
    status = 'RETURNED',
    payment_status = 'REFUNDED',
    cod_expected = NULL,
    cod_remitted_amount = NULL,
    cod_remitted_at = NULL,
    cod_remittance_ref = NULL,
    reverted_at = NOW(),
    reverted_by = p_reverted_by,
    revert_reason = v_reason,
    revert_notes = NULLIF(trim(p_notes), ''),
    updated_at = NOW()
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id;

  RETURN jsonb_build_object(
    'id', p_invoice_id,
    'invoice_number', v_invoice_number,
    'status', 'RETURNED',
    'reason', v_reason,
    'deleted', false
  );
END;
$$;

-- =========================================================
-- 4. record_thrift_cod_remittance
-- =========================================================
CREATE OR REPLACE FUNCTION public.record_thrift_cod_remittance(
  p_tenant_id BIGINT,
  p_invoice_id BIGINT,
  p_remitted_amount NUMERIC(12,2),
  p_actor TEXT,
  p_remitted_at TIMESTAMPTZ DEFAULT NOW(),
  p_remittance_ref TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_outcome TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice public.thrift_sales_invoices%ROWTYPE;
  v_remitted NUMERIC(12,2);
  v_outcome TEXT;
  v_payment_status TEXT;
  v_notes TEXT;
BEGIN
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'edit')
    OR public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create')
  ) THEN
    RAISE EXCEPTION 'Recording COD remittance requires thrift_sales edit or create permission';
  END IF;

  v_remitted := ROUND(COALESCE(p_remitted_amount, 0.00), 2);
  IF v_remitted < 0 THEN
    RAISE EXCEPTION 'Remitted amount cannot be negative';
  END IF;

  SELECT * INTO v_invoice
  FROM public.thrift_sales_invoices
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice % not found for tenant %', p_invoice_id, p_tenant_id;
  END IF;

  IF v_invoice.status IS DISTINCT FROM 'ACTIVE' THEN
    RAISE EXCEPTION 'Invoice % is % — remittance only allowed on ACTIVE invoices', p_invoice_id, v_invoice.status;
  END IF;

  IF v_invoice.payment_status = 'REFUNDED' THEN
    RAISE EXCEPTION 'Invoice % is REFUNDED — no remittance expected', p_invoice_id;
  END IF;

  v_outcome := upper(trim(COALESCE(p_outcome, '')));
  IF v_outcome = '' THEN
    IF v_invoice.cod_expected IS NULL OR v_remitted >= v_invoice.cod_expected THEN
      v_outcome := 'PAID';
    ELSE
      v_outcome := 'KEEP_PENDING';
    END IF;
  END IF;

  IF v_outcome NOT IN ('PAID', 'KEEP_PENDING', 'WRITTEN_OFF') THEN
    RAISE EXCEPTION 'Invalid outcome % (expected PAID, KEEP_PENDING, or WRITTEN_OFF)', p_outcome;
  END IF;

  IF v_outcome = 'PAID' THEN
    v_payment_status := 'PAID';
  ELSIF v_outcome = 'WRITTEN_OFF' THEN
    v_payment_status := 'WRITTEN_OFF';
  ELSE
    v_payment_status := 'COD_PENDING';
  END IF;

  v_notes := v_invoice.notes;
  IF NULLIF(trim(p_notes), '') IS NOT NULL THEN
    v_notes := CASE
      WHEN NULLIF(trim(v_notes), '') IS NULL THEN trim(p_notes)
      ELSE trim(v_notes) || E'\n' || trim(p_notes)
    END;
  END IF;

  UPDATE public.thrift_sales_invoices
  SET
    cod_remitted_amount = v_remitted,
    cod_remitted_at = COALESCE(p_remitted_at, NOW()),
    cod_remittance_ref = COALESCE(NULLIF(trim(p_remittance_ref), ''), cod_remittance_ref),
    payment_status = v_payment_status,
    notes = v_notes,
    updated_at = NOW()
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id;

  RETURN jsonb_build_object(
    'invoice_id', p_invoice_id,
    'payment_status', v_payment_status,
    'cod_expected', v_invoice.cod_expected,
    'cod_remitted_amount', v_remitted,
    'outcome', v_outcome
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_thrift_cod_remittance(
  BIGINT, BIGINT, NUMERIC, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_thrift_cod_remittance(
  BIGINT, BIGINT, NUMERIC, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT
) TO service_role;

COMMIT;

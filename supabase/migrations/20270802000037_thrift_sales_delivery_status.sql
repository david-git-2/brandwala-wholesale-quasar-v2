-- Migration: thrift_sales_invoices.delivery_status + advance RPC
-- Parcel track (Online only): PENDING → READY → IN_TRANSIT → DELIVERED | RETURNED
-- Offline: null. Independent of payment_status.

ALTER TABLE public.thrift_sales_invoices
  ADD COLUMN IF NOT EXISTS delivery_status TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'thrift_sales_invoices_delivery_status_check'
  ) THEN
    ALTER TABLE public.thrift_sales_invoices
      ADD CONSTRAINT thrift_sales_invoices_delivery_status_check
      CHECK (
        delivery_status IS NULL
        OR delivery_status IN (
          'PENDING',
          'READY',
          'IN_TRANSIT',
          'DELIVERED',
          'RETURNED'
        )
      );
  END IF;
END $$;

COMMENT ON COLUMN public.thrift_sales_invoices.delivery_status IS
  'Parcel track for Online invoices. Null for Offline. Independent of payment_status.';

UPDATE public.thrift_sales_invoices
SET delivery_status = 'PENDING',
    updated_at = NOW()
WHERE COALESCE(sale_channel, 'IN_STORE') = 'ONLINE'
  AND delivery_status IS NULL
  AND COALESCE(status, 'ACTIVE') = 'ACTIVE';

UPDATE public.thrift_sales_invoices
SET delivery_status = 'RETURNED',
    updated_at = NOW()
WHERE COALESCE(sale_channel, 'IN_STORE') = 'ONLINE'
  AND delivery_status IS NULL
  AND status = 'RETURNED';

CREATE INDEX IF NOT EXISTS idx_thrift_sales_invoices_tenant_delivery_status
  ON public.thrift_sales_invoices (tenant_id, delivery_status)
  WHERE delivery_status IS NOT NULL;


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
  v_quantity INT;
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
  v_delivery_status TEXT := NULL;
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
    v_courier_amount := 0.00;
    v_courier_paid_by := NULL;
    v_payment_method := COALESCE(NULLIF(trim(p_payment_method), ''), 'CASH');
    v_payment_status := 'PAID';
    v_cod_expected := NULL;
    v_delivery_status := NULL;
  ELSE
    IF NULLIF(trim(p_customer_name), '') IS NULL THEN
      RAISE EXCEPTION 'Online sale requires customer name';
    END IF;
    IF NULLIF(trim(p_customer_phone), '') IS NULL THEN
      RAISE EXCEPTION 'Online sale requires customer phone';
    END IF;
    IF NULLIF(trim(p_customer_address), '') IS NULL THEN
      RAISE EXCEPTION 'Online sale requires delivery address';
    END IF;

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

    v_delivery_status := 'PENDING';
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
      AND deleted_at IS NULL
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

    v_prepared_items := v_prepared_items || jsonb_build_array(
      jsonb_build_object(
        'stock_id', v_stock_id,
        'sell_price', v_sell_price,
        'discount_amount', v_discount_amount,
        'final_price', v_final_price,
        'quantity', v_quantity
      )
    );

    v_total_invoice_amount := v_total_invoice_amount + (v_final_price * v_quantity);
  END LOOP;

  IF jsonb_array_length(v_prepared_items) = 0 THEN
    RAISE EXCEPTION 'Invoice requires at least one line item';
  END IF;

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
    delivery_status,
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
    v_courier_amount,
    0.00,
    v_cod_expected,
    v_delivery_status,
    'ACTIVE'
  )
  RETURNING id INTO v_invoice_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(v_prepared_items)
  LOOP
    v_stock_id := (v_line->>'stock_id')::BIGINT;
    v_sell_price := (v_line->>'sell_price')::NUMERIC(12,2);
    v_discount_amount := (v_line->>'discount_amount')::NUMERIC(12,2);
    v_final_price := (v_line->>'final_price')::NUMERIC(12,2);
    v_quantity := (v_line->>'quantity')::INT;

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
      0.00,
      v_quantity,
      0.00
    );

    UPDATE public.thrift_stocks
    SET
      quantity = quantity - v_quantity,
      status = 'SOLD'::public.thrift_stock_status,
      updated_at = NOW()
    WHERE id = v_stock_id
      AND tenant_id = p_tenant_id
      AND deleted_at IS NULL
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
    'delivery_status', v_delivery_status,
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

DROP FUNCTION IF EXISTS public.list_thrift_sales_invoices_paginated(BIGINT, INTEGER, INTEGER, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.list_thrift_sales_invoices_paginated(
  p_tenant_id BIGINT,
  p_page INTEGER DEFAULT 1,
  p_page_size INTEGER DEFAULT 20,
  p_search TEXT DEFAULT NULL,
  p_payment_status TEXT DEFAULT NULL,
  p_status TEXT DEFAULT NULL,
  p_delivery_status TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_page INTEGER := greatest(coalesce(p_page, 1), 1);
  v_page_size INTEGER := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_search TEXT := nullif(trim(coalesce(p_search, '')), '');
  v_payment_status TEXT := nullif(upper(trim(coalesce(p_payment_status, ''))), '');
  v_status TEXT := nullif(upper(trim(coalesce(p_status, ''))), '');
  v_delivery_status TEXT := nullif(upper(trim(coalesce(p_delivery_status, ''))), '');
  v_total_count BIGINT;
  v_total_pages INTEGER;
  v_data JSONB;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.tenant_id = p_tenant_id
      AND lower(trim(m.email)) = public.current_user_email()
      AND m.is_active = true
  ) THEN
    RAISE EXCEPTION 'Not authorized for this tenant';
  END IF;

  SELECT count(*)
  INTO v_total_count
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND (
      v_search IS NULL
      OR coalesce(inv.invoice_number, '') ILIKE '%' || v_search || '%'
      OR coalesce(inv.customer_name, '') ILIKE '%' || v_search || '%'
      OR coalesce(inv.customer_phone, '') ILIKE '%' || v_search || '%'
    )
    AND (v_payment_status IS NULL OR inv.payment_status = v_payment_status)
    AND (v_status IS NULL OR coalesce(inv.status, 'ACTIVE') = v_status)
    AND (
      v_delivery_status IS NULL
      OR inv.delivery_status = v_delivery_status
    );

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_created_at DESC, sort_id DESC), '[]'::jsonb)
  INTO v_data
  FROM (
    SELECT
      jsonb_build_object(
        'id', inv.id,
        'invoice_number', inv.invoice_number,
        'sale_channel', inv.sale_channel,
        'customer_id', inv.customer_id,
        'customer_name', inv.customer_name,
        'customer_phone', inv.customer_phone,
        'customer_address', inv.customer_address,
        'date', inv.date,
        'payment_method', inv.payment_method,
        'payment_status', inv.payment_status,
        'delivery_status', inv.delivery_status,
        'total_invoice_amount', inv.total_invoice_amount,
        'courier_amount', inv.courier_amount,
        'courier_paid_by', inv.courier_paid_by,
        'cod_expected', inv.cod_expected,
        'cod_remitted_amount', inv.cod_remitted_amount,
        'cod_remitted_at', inv.cod_remitted_at,
        'created_by', inv.created_by,
        'notes', inv.notes,
        'created_at', inv.created_at,
        'status', inv.status,
        'reverted_at', inv.reverted_at,
        'reverted_by', inv.reverted_by,
        'revert_reason', inv.revert_reason,
        'revert_notes', inv.revert_notes,
        'item_count', (
          SELECT count(*)::INT
          FROM public.thrift_sales_invoice_items si
          WHERE si.invoice_id = inv.id
            AND si.tenant_id = inv.tenant_id
        )
      ) AS row_data,
      inv.created_at AS sort_created_at,
      inv.id AS sort_id
    FROM public.thrift_sales_invoices inv
    WHERE inv.tenant_id = p_tenant_id
      AND (
        v_search IS NULL
        OR coalesce(inv.invoice_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_name, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_phone, '') ILIKE '%' || v_search || '%'
      )
      AND (v_payment_status IS NULL OR inv.payment_status = v_payment_status)
      AND (v_status IS NULL OR coalesce(inv.status, 'ACTIVE') = v_status)
      AND (
        v_delivery_status IS NULL
        OR inv.delivery_status = v_delivery_status
      )
    ORDER BY inv.created_at DESC, inv.id DESC
    OFFSET (v_page - 1) * v_page_size
    LIMIT v_page_size
  ) paged;

  IF v_total_count = 0 THEN
    v_total_pages := 0;
  ELSE
    v_total_pages := ceil(v_total_count::NUMERIC / v_page_size)::INTEGER;
  END IF;

  RETURN jsonb_build_object(
    'data', coalesce(v_data, '[]'::jsonb),
    'meta', jsonb_build_object(
      'page', v_page,
      'total', v_total_count,
      'page_size', v_page_size,
      'total_pages', v_total_pages
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.list_thrift_sales_invoices_paginated(
  BIGINT, INTEGER, INTEGER, TEXT, TEXT, TEXT, TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_thrift_sales_invoices_paginated(
  BIGINT, INTEGER, INTEGER, TEXT, TEXT, TEXT, TEXT
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_thrift_sales_invoices_paginated(
  BIGINT, INTEGER, INTEGER, TEXT, TEXT, TEXT, TEXT
) TO service_role;


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
    delivery_status = CASE
      WHEN COALESCE(sale_channel, 'IN_STORE') = 'ONLINE' THEN 'RETURNED'
      ELSE delivery_status
    END,
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



-- Advance / set delivery status (parcel only — never flips payment_status)
CREATE OR REPLACE FUNCTION public.update_thrift_sales_delivery_status(
  p_tenant_id BIGINT,
  p_invoice_id BIGINT,
  p_delivery_status TEXT,
  p_actor TEXT DEFAULT 'cashier'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice public.thrift_sales_invoices%ROWTYPE;
  v_target TEXT;
  v_current TEXT;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create')
     AND NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'return')
  THEN
    RAISE EXCEPTION 'Updating delivery status requires thrift_sales create or return permission';
  END IF;

  v_target := upper(trim(COALESCE(p_delivery_status, '')));
  IF v_target NOT IN ('PENDING', 'READY', 'IN_TRANSIT', 'DELIVERED', 'RETURNED') THEN
    RAISE EXCEPTION 'Invalid delivery_status: %', p_delivery_status;
  END IF;

  SELECT * INTO v_invoice
  FROM public.thrift_sales_invoices
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice % not found for tenant %', p_invoice_id, p_tenant_id;
  END IF;

  IF COALESCE(v_invoice.sale_channel, 'IN_STORE') <> 'ONLINE' THEN
    RAISE EXCEPTION 'delivery_status applies to Online invoices only';
  END IF;

  IF v_invoice.status IS DISTINCT FROM 'ACTIVE' THEN
    RAISE EXCEPTION 'Cannot update delivery on invoice status %', v_invoice.status;
  END IF;

  IF v_target = 'RETURNED' THEN
    RAISE EXCEPTION
      'Set delivery RETURNED via revert_thrift_sales_invoice (RETURN), not delivery advance';
  END IF;

  v_current := COALESCE(v_invoice.delivery_status, 'PENDING');

  IF v_current = v_target THEN
    RETURN jsonb_build_object(
      'id', v_invoice.id,
      'delivery_status', v_current,
      'unchanged', true
    );
  END IF;

  -- Allow forward steps and limited corrections (not past DELIVERED → earlier except READY/IN_TRANSIT corrections from DELIVERED? Keep simple: any non-RETURNED target among set while ACTIVE)
  IF v_current = 'DELIVERED' AND v_target <> 'DELIVERED' THEN
    RAISE EXCEPTION 'Cannot move delivery from DELIVERED to %', v_target;
  END IF;

  UPDATE public.thrift_sales_invoices
  SET
    delivery_status = v_target,
    updated_at = NOW()
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id;

  RETURN jsonb_build_object(
    'id', p_invoice_id,
    'delivery_status', v_target,
    'previous_delivery_status', v_current,
    'actor', COALESCE(NULLIF(trim(p_actor), ''), 'cashier'),
    'unchanged', false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.update_thrift_sales_delivery_status(BIGINT, BIGINT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_thrift_sales_delivery_status(BIGINT, BIGINT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_thrift_sales_delivery_status(BIGINT, BIGINT, TEXT, TEXT) TO service_role;

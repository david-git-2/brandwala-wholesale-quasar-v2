-- Thrift gaps Phase 1 (backend):
-- 1a. create_thrift_sales_invoice — sell-only lines (cost/profit = 0)
-- 1b. list_thrift_sales_invoices_paginated — p_payment_status / p_status filters
-- 1c. get_thrift_sales_report — live COGS, shop courier fees, COD outstanding
-- 1d. get_thrift_shipment_sales_report — live unit cost
-- 1e. get_thrift_dashboard_metrics — expanded metrics + thrift_reports/view

BEGIN;

-- =========================================================
-- 1a. create_thrift_sales_invoice (sell-only COGS stubs)
-- =========================================================
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

    -- Sell-only: freeze cost/profit as 0; reports compute live COGS via stock_id.
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
    v_courier_amount, -- keep legacy column in sync for older readers
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
-- 1b. list_thrift_sales_invoices_paginated (+ payment/status filters)
-- =========================================================
DROP FUNCTION IF EXISTS public.list_thrift_sales_invoices_paginated(BIGINT, INTEGER, INTEGER, TEXT);

CREATE OR REPLACE FUNCTION public.list_thrift_sales_invoices_paginated(
  p_tenant_id BIGINT,
  p_page INTEGER DEFAULT 1,
  p_page_size INTEGER DEFAULT 20,
  p_search TEXT DEFAULT NULL,
  p_payment_status TEXT DEFAULT NULL,
  p_status TEXT DEFAULT NULL
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
    AND (v_status IS NULL OR coalesce(inv.status, 'ACTIVE') = v_status);

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
  BIGINT, INTEGER, INTEGER, TEXT, TEXT, TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_thrift_sales_invoices_paginated(
  BIGINT, INTEGER, INTEGER, TEXT, TEXT, TEXT
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_thrift_sales_invoices_paginated(
  BIGINT, INTEGER, INTEGER, TEXT, TEXT, TEXT
) TO service_role;

-- =========================================================
-- 1c. get_thrift_sales_report (live COGS + shop fees + COD outstanding)
-- =========================================================
CREATE OR REPLACE FUNCTION public.get_thrift_sales_report(
  p_tenant_id BIGINT,
  p_date_from TIMESTAMPTZ,
  p_date_to TIMESTAMPTZ,
  p_sale_channel TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_channel TEXT;
  v_summary JSONB;
  v_by_channel JSONB;
  v_cod_outstanding JSONB;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_reports', 'view') THEN
    RAISE EXCEPTION 'Thrift sales report requires thrift_reports view permission';
  END IF;

  IF p_date_from IS NULL OR p_date_to IS NULL THEN
    RAISE EXCEPTION 'p_date_from and p_date_to are required';
  END IF;

  IF p_date_from > p_date_to THEN
    RAISE EXCEPTION 'p_date_from must be <= p_date_to';
  END IF;

  v_channel := NULLIF(trim(COALESCE(p_sale_channel, '')), '');
  IF v_channel IS NOT NULL AND v_channel NOT IN ('IN_STORE', 'ONLINE') THEN
    RAISE EXCEPTION 'Invalid sale_channel: % (expected IN_STORE, ONLINE, or null)', v_channel;
  END IF;

  WITH active_inv AS (
    SELECT
      inv.id,
      COALESCE(inv.sale_channel, 'IN_STORE') AS sale_channel,
      inv.total_invoice_amount,
      CASE
        WHEN inv.courier_paid_by = 'SHOP' THEN COALESCE(inv.courier_amount, 0)
        ELSE 0
      END AS shop_courier_fee
    FROM public.thrift_sales_invoices inv
    WHERE inv.tenant_id = p_tenant_id
      AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE'
      AND inv.date >= p_date_from
      AND inv.date <= p_date_to
      AND (v_channel IS NULL OR COALESCE(inv.sale_channel, 'IN_STORE') = v_channel)
  ),
  active_lines AS (
    SELECT
      a.sale_channel,
      a.id AS invoice_id,
      a.total_invoice_amount,
      a.shop_courier_fee,
      COALESCE(SUM(i.quantity), 0) AS units,
      COALESCE(
        SUM(
          ROUND(COALESCE(public.compute_thrift_landed_unit_cost(i.stock_id), 0.00), 2)
          * i.quantity
        ),
        0
      ) AS cogs,
      COALESCE(
        SUM(
          (
            i.final_price
            - ROUND(COALESCE(public.compute_thrift_landed_unit_cost(i.stock_id), 0.00), 2)
          ) * i.quantity
        ),
        0
      ) AS line_profit
    FROM active_inv a
    LEFT JOIN public.thrift_sales_invoice_items i
      ON i.invoice_id = a.id
     AND i.tenant_id = p_tenant_id
    GROUP BY a.id, a.sale_channel, a.total_invoice_amount, a.shop_courier_fee
  ),
  active_agg AS (
    SELECT
      COUNT(*)::BIGINT AS invoice_count,
      COALESCE(SUM(units), 0)::BIGINT AS units_sold,
      COALESCE(SUM(total_invoice_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(line_profit), 0)::NUMERIC(14,2) AS line_profit,
      COALESCE(SUM(shop_courier_fee), 0)::NUMERIC(14,2) AS total_fees,
      COALESCE(SUM(line_profit - shop_courier_fee), 0)::NUMERIC(14,2) AS net_after_fees
    FROM active_lines
  ),
  returned_agg AS (
    SELECT
      COUNT(*)::BIGINT AS refund_count,
      COALESCE(SUM(inv.total_invoice_amount), 0)::NUMERIC(14,2) AS refund_amount
    FROM public.thrift_sales_invoices inv
    WHERE inv.tenant_id = p_tenant_id
      AND inv.status = 'RETURNED'
      AND inv.reverted_at IS NOT NULL
      AND inv.reverted_at >= p_date_from
      AND inv.reverted_at <= p_date_to
      AND (v_channel IS NULL OR COALESCE(inv.sale_channel, 'IN_STORE') = v_channel)
  ),
  channel_rows AS (
    SELECT
      al.sale_channel,
      COUNT(*)::BIGINT AS invoice_count,
      COALESCE(SUM(al.units), 0)::BIGINT AS units_sold,
      COALESCE(SUM(al.total_invoice_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(al.cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(al.line_profit), 0)::NUMERIC(14,2) AS line_profit,
      COALESCE(SUM(al.shop_courier_fee), 0)::NUMERIC(14,2) AS total_fees,
      COALESCE(SUM(al.line_profit - al.shop_courier_fee), 0)::NUMERIC(14,2) AS net_after_fees
    FROM active_lines al
    GROUP BY al.sale_channel
  )
  SELECT
    jsonb_build_object(
      'invoice_count', a.invoice_count,
      'units_sold', a.units_sold,
      'net_revenue', a.net_revenue,
      'cogs', a.cogs,
      'line_profit', a.line_profit,
      -- BC keys: courier_cod_amount = shop courier fee; other_expense always 0
      'courier_cod_amount', a.total_fees,
      'other_expense_amount', 0::NUMERIC(14,2),
      'total_fees', a.total_fees,
      'net_after_fees', a.net_after_fees,
      'refund_count', r.refund_count,
      'refund_amount', r.refund_amount
    ),
    COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'sale_channel', c.sale_channel,
            'invoice_count', c.invoice_count,
            'units_sold', c.units_sold,
            'net_revenue', c.net_revenue,
            'cogs', c.cogs,
            'line_profit', c.line_profit,
            'courier_cod_amount', c.total_fees,
            'other_expense_amount', 0::NUMERIC(14,2),
            'total_fees', c.total_fees,
            'net_after_fees', c.net_after_fees
          )
          ORDER BY c.sale_channel
        )
        FROM channel_rows c
      ),
      '[]'::jsonb
    )
  INTO v_summary, v_by_channel
  FROM active_agg a
  CROSS JOIN returned_agg r;

  -- COD outstanding: snapshot of ALL open COD (not date-filtered).
  SELECT jsonb_build_object(
    'invoice_count', COUNT(*)::BIGINT,
    'cod_expected_total', COALESCE(SUM(COALESCE(inv.cod_expected, 0)), 0)::NUMERIC(14,2),
    'cod_remitted_total', COALESCE(SUM(COALESCE(inv.cod_remitted_amount, 0)), 0)::NUMERIC(14,2)
  )
  INTO v_cod_outstanding
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE'
    AND inv.payment_status = 'COD_PENDING';

  RETURN jsonb_build_object(
    'date_from', p_date_from,
    'date_to', p_date_to,
    'sale_channel', v_channel,
    'summary', COALESCE(v_summary, '{}'::jsonb),
    'by_channel', COALESCE(v_by_channel, '[]'::jsonb),
    'cod_outstanding', COALESCE(v_cod_outstanding, jsonb_build_object(
      'invoice_count', 0,
      'cod_expected_total', 0,
      'cod_remitted_total', 0
    ))
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_thrift_sales_report(BIGINT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_thrift_sales_report(BIGINT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
  TO service_role;

-- =========================================================
-- 1d. get_thrift_shipment_sales_report (live unit cost)
-- =========================================================
CREATE OR REPLACE FUNCTION public.get_thrift_shipment_sales_report(
  p_tenant_id BIGINT,
  p_shipment_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_shipment JSONB;
  v_summary JSONB;
  v_lines JSONB;
  v_units_sold BIGINT := 0;
  v_gross_sales NUMERIC(14, 2) := 0;
  v_discounts NUMERIC(14, 2) := 0;
  v_net_revenue NUMERIC(14, 2) := 0;
  v_cogs NUMERIC(14, 2) := 0;
  v_net_profit NUMERIC(14, 2) := 0;
  v_margin_pct NUMERIC(8, 2) := 0;
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

  SELECT jsonb_build_object(
    'id', s.id,
    'name', s.name,
    'created_at', s.created_at,
    'updated_at', s.updated_at
  )
  INTO v_shipment
  FROM public.thrift_shipments s
  WHERE s.id = p_shipment_id
    AND s.tenant_id = p_tenant_id;

  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment % not found for tenant %', p_shipment_id, p_tenant_id;
  END IF;

  SELECT
    COALESCE(SUM(i.quantity), 0),
    COALESCE(SUM(i.sell_price * i.quantity), 0),
    COALESCE(SUM(i.discount_amount * i.quantity), 0),
    COALESCE(SUM(i.final_price * i.quantity), 0),
    COALESCE(
      SUM(
        ROUND(COALESCE(public.compute_thrift_landed_unit_cost(i.stock_id), 0.00), 2)
        * i.quantity
      ),
      0
    ),
    COALESCE(
      SUM(
        (
          i.final_price
          - ROUND(COALESCE(public.compute_thrift_landed_unit_cost(i.stock_id), 0.00), 2)
        ) * i.quantity
      ),
      0
    )
  INTO
    v_units_sold,
    v_gross_sales,
    v_discounts,
    v_net_revenue,
    v_cogs,
    v_net_profit
  FROM public.thrift_sales_invoice_items i
  INNER JOIN public.thrift_stocks st
    ON st.id = i.stock_id
   AND st.tenant_id = i.tenant_id
  INNER JOIN public.thrift_sales_invoices inv
    ON inv.id = i.invoice_id
   AND inv.tenant_id = i.tenant_id
  WHERE i.tenant_id = p_tenant_id
    AND st.shipment_id = p_shipment_id
    AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE';

  IF v_net_revenue > 0 THEN
    v_margin_pct := ROUND((v_net_profit / v_net_revenue) * 100, 2);
  ELSE
    v_margin_pct := 0;
  END IF;

  v_summary := jsonb_build_object(
    'units_sold', v_units_sold,
    'gross_sales', v_gross_sales,
    'discounts', v_discounts,
    'net_revenue', v_net_revenue,
    'cogs', v_cogs,
    'net_profit', v_net_profit,
    'margin_pct', v_margin_pct
  );

  SELECT COALESCE(jsonb_agg(row_to_json(r)::jsonb ORDER BY r.invoice_date DESC, r.id), '[]'::jsonb)
  INTO v_lines
  FROM (
    SELECT
      i.id,
      i.invoice_id,
      inv.invoice_number,
      inv.date AS invoice_date,
      i.stock_id,
      st.name AS stock_name,
      st.barcode,
      i.quantity,
      i.sell_price,
      i.discount_amount,
      i.final_price,
      -- Keep key name; value is live unit cost at report time.
      ROUND(COALESCE(public.compute_thrift_landed_unit_cost(i.stock_id), 0.00), 2)
        AS landed_unit_cost_at_sale,
      (
        (
          i.final_price
          - ROUND(COALESCE(public.compute_thrift_landed_unit_cost(i.stock_id), 0.00), 2)
        ) * i.quantity
      ) AS net_profit
    FROM public.thrift_sales_invoice_items i
    INNER JOIN public.thrift_stocks st
      ON st.id = i.stock_id
     AND st.tenant_id = i.tenant_id
    INNER JOIN public.thrift_sales_invoices inv
      ON inv.id = i.invoice_id
     AND inv.tenant_id = i.tenant_id
    WHERE i.tenant_id = p_tenant_id
      AND st.shipment_id = p_shipment_id
      AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE'
  ) r;

  RETURN jsonb_build_object(
    'shipment', v_shipment,
    'summary', v_summary,
    'lines', v_lines
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_thrift_shipment_sales_report(BIGINT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_thrift_shipment_sales_report(BIGINT, BIGINT) TO service_role;

-- =========================================================
-- 1e. get_thrift_dashboard_metrics (expanded + thrift_reports/view)
-- =========================================================
CREATE OR REPLACE FUNCTION public.get_thrift_dashboard_metrics(p_tenant_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_items_added_today BIGINT;
  v_total_items BIGINT;
  v_available_items BIGINT;
  v_sold_items BIGINT;
  v_cod_pending_count BIGINT;
  v_cod_expected_total NUMERIC(14,2);
  v_active_invoices_today BIGINT;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_reports', 'view') THEN
    RAISE EXCEPTION 'Thrift dashboard metrics require thrift_reports view permission';
  END IF;

  SELECT COUNT(*)
  INTO v_items_added_today
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND created_at >= date_trunc('day', NOW());

  SELECT COUNT(*)
  INTO v_total_items
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id;

  SELECT COUNT(*)
  INTO v_available_items
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND status = 'AVAILABLE'::public.thrift_stock_status;

  SELECT COUNT(*)
  INTO v_sold_items
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND status = 'SOLD'::public.thrift_stock_status;

  SELECT
    COUNT(*)::BIGINT,
    COALESCE(SUM(COALESCE(inv.cod_expected, 0)), 0)::NUMERIC(14,2)
  INTO v_cod_pending_count, v_cod_expected_total
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE'
    AND inv.payment_status = 'COD_PENDING';

  SELECT COUNT(*)
  INTO v_active_invoices_today
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE'
    AND inv.date >= date_trunc('day', NOW());

  RETURN jsonb_build_object(
    'items_added_today', v_items_added_today,
    'total_items', v_total_items,
    'available_items', v_available_items,
    'sold_items', v_sold_items,
    'cod_pending_count', v_cod_pending_count,
    'cod_expected_total', v_cod_expected_total,
    'active_invoices_today', v_active_invoices_today
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_thrift_dashboard_metrics(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_thrift_dashboard_metrics(BIGINT) TO service_role;

COMMIT;

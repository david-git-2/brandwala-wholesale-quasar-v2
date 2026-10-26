-- Phase 5: Hybrid create + list RPC
-- - create_thrift_sales_invoice: optional channel/address/customer_notes; upsert customer by phone
-- - Preserve Phase 2 safety (FOR UPDATE, AVAILABLE, qty, server COGS/totals)
-- - list_thrift_sales_invoices_paginated: include sale_channel, customer_id, customer_address

BEGIN;

-- =========================================================
-- 1. create_thrift_sales_invoice (hybrid + P2 safety)
-- =========================================================
DROP FUNCTION IF EXISTS public.create_thrift_sales_invoice(
  BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB
);

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
  p_items JSONB DEFAULT '[]'::jsonb,
  p_sale_channel TEXT DEFAULT 'IN_STORE',
  p_customer_address TEXT DEFAULT NULL,
  p_customer_notes TEXT DEFAULT NULL
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
BEGIN
  -- Always allocate server-side (ignore client-supplied number)
  v_invoice_number := public.generate_thrift_invoice_number(p_tenant_id, COALESCE(p_date, NOW()));

  v_sale_channel := COALESCE(NULLIF(trim(p_sale_channel), ''), 'IN_STORE');
  IF v_sale_channel NOT IN ('IN_STORE', 'ONLINE') THEN
    RAISE EXCEPTION 'Invalid sale_channel: % (expected IN_STORE or ONLINE)', v_sale_channel;
  END IF;

  -- Optional customer upsert by normalized phone
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

  -- Lock + validate all stocks; compute server line math before any stock mutation
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

    -- Clamp discount to [0, sell_price]
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

    IF v_stock.status IS DISTINCT FROM 'AVAILABLE'::public.thrift_stock_status THEN
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

    -- Authoritative COGS (ignore client landed_unit_cost / final_price / net_profit)
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

  -- Ignore client p_total_invoice_amount
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
    p_payment_method,
    p_payment_status,
    p_notes,
    p_created_by,
    v_total_invoice_amount,
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
      AND status = 'AVAILABLE'::public.thrift_stock_status
      AND quantity >= v_quantity;

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

  RETURN jsonb_build_object(
    'id', v_invoice_id,
    'invoice_number', v_invoice_number,
    'status', 'success'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_thrift_sales_invoice(
  BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB, TEXT, TEXT, TEXT
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.create_thrift_sales_invoice(
  BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB, TEXT, TEXT, TEXT
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.create_thrift_sales_invoice(
  BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB, TEXT, TEXT, TEXT
) TO service_role;

-- =========================================================
-- 2. list_thrift_sales_invoices_paginated (+ hybrid fields)
-- =========================================================
CREATE OR REPLACE FUNCTION public.list_thrift_sales_invoices_paginated(
  p_tenant_id BIGINT,
  p_page INTEGER DEFAULT 1,
  p_page_size INTEGER DEFAULT 20,
  p_search TEXT DEFAULT NULL
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
        'total_invoice_amount', inv.total_invoice_amount,
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

REVOKE ALL ON FUNCTION public.list_thrift_sales_invoices_paginated(BIGINT, INTEGER, INTEGER, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_thrift_sales_invoices_paginated(BIGINT, INTEGER, INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_thrift_sales_invoices_paginated(BIGINT, INTEGER, INTEGER, TEXT) TO service_role;

COMMIT;

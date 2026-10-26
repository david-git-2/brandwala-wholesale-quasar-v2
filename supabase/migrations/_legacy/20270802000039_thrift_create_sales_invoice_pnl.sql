-- Migration: create_thrift_sales_invoice — Offline PnL + Online fee/money rules
-- Docs: doc/v2/thrift/sales/workflow.md §1 · rpc/create_thrift_sales_invoice.md
-- Depends on: 20270802000038 (pnl_lines + invoice fee/close columns)

BEGIN;

DROP FUNCTION IF EXISTS public.create_thrift_sales_invoice(
  BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB, TEXT, TEXT, TEXT, NUMERIC, TEXT
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
  p_courier_paid_by TEXT DEFAULT NULL,
  p_packing_amount NUMERIC(12,2) DEFAULT 0.00,
  p_packing_paid_by TEXT DEFAULT NULL,
  p_cod_fee_amount NUMERIC(12,2) DEFAULT 0.00,
  p_cod_fee_paid_by TEXT DEFAULT NULL,
  p_courier_provider TEXT DEFAULT NULL
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
  v_packing_amount NUMERIC(12,2);
  v_packing_paid_by TEXT;
  v_cod_fee_amount NUMERIC(12,2);
  v_cod_fee_paid_by TEXT;
  v_courier_provider TEXT;
  v_payment_method TEXT;
  v_payment_status TEXT;
  v_cod_expected NUMERIC(12,2) := NULL;
  v_delivery_status TEXT := NULL;
  v_economics_closed_at TIMESTAMPTZ := NULL;
  v_event_at TIMESTAMPTZ;
  v_invoice_item_id BIGINT;
  v_inbound_shipment_id BIGINT;
  v_sell_amount NUMERIC(12,2);
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create') THEN
    RAISE EXCEPTION 'Creating a thrift sales invoice requires thrift_sales create permission';
  END IF;

  v_event_at := COALESCE(p_date, NOW());
  v_invoice_number := public.generate_thrift_invoice_number(p_tenant_id, v_event_at);

  v_sale_channel := COALESCE(NULLIF(trim(p_sale_channel), ''), 'IN_STORE');
  IF v_sale_channel NOT IN ('IN_STORE', 'ONLINE') THEN
    RAISE EXCEPTION 'Invalid sale_channel: % (expected IN_STORE or ONLINE)', v_sale_channel;
  END IF;

  v_courier_amount := ROUND(COALESCE(p_courier_amount, 0.00), 2);
  v_courier_paid_by := NULLIF(upper(trim(COALESCE(p_courier_paid_by, ''))), '');
  v_packing_amount := ROUND(COALESCE(p_packing_amount, 0.00), 2);
  v_packing_paid_by := NULLIF(upper(trim(COALESCE(p_packing_paid_by, ''))), '');
  v_cod_fee_amount := ROUND(COALESCE(p_cod_fee_amount, 0.00), 2);
  v_cod_fee_paid_by := NULLIF(upper(trim(COALESCE(p_cod_fee_paid_by, ''))), '');
  v_courier_provider := NULLIF(trim(COALESCE(p_courier_provider, '')), '');

  IF NULLIF(trim(p_customer_name), '') IS NULL THEN
    RAISE EXCEPTION 'Customer name is required';
  END IF;
  IF NULLIF(trim(p_customer_phone), '') IS NULL THEN
    RAISE EXCEPTION 'Customer phone is required';
  END IF;

  IF v_sale_channel = 'IN_STORE' THEN
    -- Offline: force zero fees / null payers / null delivery; close economics immediately.
    v_courier_amount := 0.00;
    v_courier_paid_by := NULL;
    v_packing_amount := 0.00;
    v_packing_paid_by := NULL;
    v_cod_fee_amount := 0.00;
    v_cod_fee_paid_by := NULL;
    v_courier_provider := NULL;
    v_payment_method := 'CASH';
    v_payment_status := 'PAID';
    v_cod_expected := NULL;
    v_delivery_status := NULL;
    v_economics_closed_at := v_event_at;
  ELSE
    IF NULLIF(trim(p_customer_address), '') IS NULL THEN
      RAISE EXCEPTION 'Online sale requires delivery address';
    END IF;

    IF v_courier_amount < 0 OR v_packing_amount < 0 OR v_cod_fee_amount < 0 THEN
      RAISE EXCEPTION 'Fee amounts cannot be negative';
    END IF;

    IF v_courier_amount > 0 THEN
      IF v_courier_paid_by IS NULL OR v_courier_paid_by NOT IN ('CUSTOMER', 'SHOP') THEN
        RAISE EXCEPTION 'courier_paid_by is required when courier_amount > 0 (CUSTOMER or SHOP)';
      END IF;
    ELSE
      v_courier_paid_by := NULL;
    END IF;

    IF v_packing_amount > 0 THEN
      IF v_packing_paid_by IS NULL OR v_packing_paid_by NOT IN ('CUSTOMER', 'SHOP') THEN
        RAISE EXCEPTION 'packing_paid_by is required when packing_amount > 0 (CUSTOMER or SHOP)';
      END IF;
    ELSE
      v_packing_paid_by := NULL;
    END IF;

    IF v_cod_fee_amount > 0 THEN
      IF v_cod_fee_paid_by IS NULL OR v_cod_fee_paid_by NOT IN ('CUSTOMER', 'SHOP') THEN
        RAISE EXCEPTION 'cod_fee_paid_by is required when cod_fee_amount > 0 (CUSTOMER or SHOP)';
      END IF;
    ELSE
      v_cod_fee_paid_by := NULL;
    END IF;

    v_payment_method := 'COD';
    v_payment_status := 'COD_PENDING';
    v_delivery_status := 'PENDING';
    v_economics_closed_at := NULL;
  END IF;

  v_phone_normalized := public.normalize_thrift_phone(p_customer_phone);
  IF v_phone_normalized = '' THEN
    RAISE EXCEPTION 'Customer phone is required';
  END IF;

  v_customer_display_name := trim(p_customer_name);

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
    name = EXCLUDED.name,
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

    IF v_stock.shipment_id IS NULL THEN
      RAISE EXCEPTION 'Stock item % has no inbound shipment; cannot create sales PnL later', v_stock_id;
    END IF;

    IF v_stock.status = 'AVAILABLE'::public.thrift_stock_status THEN
      NULL;
    ELSIF v_stock.status = 'RESERVED'::public.thrift_stock_status THEN
      IF COALESCE(v_stock.held_for_phone_normalized, '') = ''
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
        'quantity', v_quantity,
        'inbound_shipment_id', v_stock.shipment_id
      )
    );

    v_total_invoice_amount := v_total_invoice_amount + (v_final_price * v_quantity);
  END LOOP;

  IF jsonb_array_length(v_prepared_items) = 0 THEN
    RAISE EXCEPTION 'Invoice requires at least one line item';
  END IF;

  IF v_sale_channel = 'ONLINE' THEN
    v_cod_expected := ROUND(
      v_total_invoice_amount
      + CASE WHEN v_courier_paid_by = 'CUSTOMER' THEN v_courier_amount ELSE 0.00 END
      + CASE WHEN v_cod_fee_paid_by = 'CUSTOMER' THEN v_cod_fee_amount ELSE 0.00 END
      + CASE WHEN v_packing_paid_by = 'CUSTOMER' THEN v_packing_amount ELSE 0.00 END,
      2
    );
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
    courier_provider,
    packing_amount,
    packing_paid_by,
    cod_fee_amount,
    cod_fee_paid_by,
    return_courier_amount,
    other_expense_amount,
    cod_expected,
    delivery_status,
    economics_closed_at,
    status
  ) VALUES (
    p_tenant_id,
    v_invoice_number,
    p_customer_name,
    p_customer_phone,
    p_customer_address,
    v_customer_id,
    v_sale_channel,
    v_event_at,
    v_payment_method,
    v_payment_status,
    p_notes,
    p_created_by,
    v_total_invoice_amount,
    v_courier_amount,
    v_courier_paid_by,
    v_courier_amount,
    v_courier_provider,
    v_packing_amount,
    v_packing_paid_by,
    v_cod_fee_amount,
    v_cod_fee_paid_by,
    0.00,
    0.00,
    v_cod_expected,
    v_delivery_status,
    v_economics_closed_at,
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
    v_inbound_shipment_id := (v_line->>'inbound_shipment_id')::BIGINT;
    v_sell_amount := ROUND(v_final_price * v_quantity, 2);

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
    )
    RETURNING id INTO v_invoice_item_id;

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

    -- Offline only: immediate PnL DELIVERED (fee allocations all zero).
    IF v_sale_channel = 'IN_STORE' THEN
      INSERT INTO public.thrift_sales_pnl_lines (
        tenant_id,
        invoice_id,
        invoice_item_id,
        stock_id,
        inbound_shipment_id,
        outcome,
        return_id,
        quantity,
        sell_amount,
        allocated_shop_delivery,
        allocated_shop_cod_fee,
        allocated_shop_packing,
        allocated_return_courier,
        allocated_fees_total,
        cogs_is_loss,
        event_at,
        event_date
      ) VALUES (
        p_tenant_id,
        v_invoice_id,
        v_invoice_item_id,
        v_stock_id,
        v_inbound_shipment_id,
        'DELIVERED',
        NULL,
        v_quantity,
        v_sell_amount,
        0.00,
        0.00,
        0.00,
        0.00,
        0.00,
        FALSE,
        v_event_at,
        (v_event_at AT TIME ZONE 'UTC')::DATE
      );
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
    'item_revenue',
    p_created_by,
    v_event_at
  );

  IF v_sale_channel = 'ONLINE' AND v_courier_amount > 0 AND v_courier_paid_by = 'SHOP' THEN
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
      'shop_delivery',
      p_created_by,
      v_event_at
    );
  END IF;

  IF v_sale_channel = 'ONLINE' AND v_packing_amount > 0 AND v_packing_paid_by = 'SHOP' THEN
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
      v_packing_amount,
      'shop_packing',
      p_created_by,
      v_event_at
    );
  END IF;

  -- COD fee: invoice field + cod_expected only — no create-time ledger row.

  RETURN jsonb_build_object(
    'id', v_invoice_id,
    'invoice_number', v_invoice_number,
    'payment_status', v_payment_status,
    'sale_channel', v_sale_channel,
    'cod_expected', v_cod_expected,
    'delivery_status', v_delivery_status,
    'economics_closed_at', v_economics_closed_at,
    'status', 'success'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_thrift_sales_invoice(
  BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB, TEXT, TEXT, TEXT, NUMERIC, TEXT, NUMERIC, TEXT, NUMERIC, TEXT, TEXT
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.create_thrift_sales_invoice(
  BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB, TEXT, TEXT, TEXT, NUMERIC, TEXT, NUMERIC, TEXT, NUMERIC, TEXT, TEXT
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.create_thrift_sales_invoice(
  BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB, TEXT, TEXT, TEXT, NUMERIC, TEXT, NUMERIC, TEXT, NUMERIC, TEXT, TEXT
) TO service_role;

COMMENT ON FUNCTION public.create_thrift_sales_invoice(
  BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB, TEXT, TEXT, TEXT, NUMERIC, TEXT, NUMERIC, TEXT, NUMERIC, TEXT, TEXT
) IS
  'Create thrift sales invoice. Offline: PAID + PnL DELIVERED. Online: COD_PENDING/PENDING, fee EXPENSEs, no PnL yet.';

COMMIT;

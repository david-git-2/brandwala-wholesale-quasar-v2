-- Phase 28: Sales permission matrix
-- Actions: return, force_return, staff_mistake
-- RPC gates on create + revert

BEGIN;

-- =========================================================
-- 1. Catalog + role templates
-- =========================================================
INSERT INTO public.module_actions (module_key, action, scope, tenant_configurable, is_active)
VALUES
  ('thrift_sales', 'return', 'app', true, true),
  ('thrift_sales', 'force_return', 'app', true, true),
  ('thrift_sales', 'staff_mistake', 'app', true, true)
ON CONFLICT (module_key, action, scope) DO UPDATE SET
  is_active = true,
  tenant_configurable = true;

INSERT INTO public.system_role_templates (scope, role_slug, module_key, action, allowed)
VALUES
  ('app', 'staff', 'thrift_sales', 'return', true),
  ('app', 'staff', 'thrift_sales', 'force_return', true),
  ('app', 'staff', 'thrift_sales', 'staff_mistake', true),
  ('app', 'manager', 'thrift_sales', 'return', true),
  ('app', 'manager', 'thrift_sales', 'force_return', true),
  ('app', 'manager', 'thrift_sales', 'staff_mistake', true),
  ('app', 'cashier', 'thrift_sales', 'return', false),
  ('app', 'cashier', 'thrift_sales', 'force_return', false),
  ('app', 'cashier', 'thrift_sales', 'staff_mistake', false)
ON CONFLICT (scope, role_slug, module_key, action) DO UPDATE SET
  allowed = EXCLUDED.allowed;

-- Backfill from legacy edit/delete grants on tenant roles
INSERT INTO public.tenant_role_grants (tenant_role_id, module_key, action, allowed)
SELECT trg.tenant_role_id, 'thrift_sales', 'return', true
FROM public.tenant_role_grants trg
WHERE trg.module_key = 'thrift_sales'
  AND trg.action = 'edit'
  AND trg.allowed = true
ON CONFLICT (tenant_role_id, module_key, action) DO UPDATE SET
  allowed = true,
  updated_at = NOW();

INSERT INTO public.tenant_role_grants (tenant_role_id, module_key, action, allowed)
SELECT trg.tenant_role_id, 'thrift_sales', 'staff_mistake', true
FROM public.tenant_role_grants trg
WHERE trg.module_key = 'thrift_sales'
  AND trg.action = 'delete'
  AND trg.allowed = true
ON CONFLICT (tenant_role_id, module_key, action) DO UPDATE SET
  allowed = true,
  updated_at = NOW();

-- Membership overrides: edit → return, delete → staff_mistake
INSERT INTO public.membership_grants (membership_id, module_key, action, effect)
SELECT mg.membership_id, 'thrift_sales', 'return', mg.effect
FROM public.membership_grants mg
WHERE mg.module_key = 'thrift_sales'
  AND mg.action = 'edit'
ON CONFLICT (membership_id, module_key, action) DO UPDATE SET
  effect = EXCLUDED.effect,
  updated_at = NOW();

INSERT INTO public.membership_grants (membership_id, module_key, action, effect)
SELECT mg.membership_id, 'thrift_sales', 'staff_mistake', mg.effect
FROM public.membership_grants mg
WHERE mg.module_key = 'thrift_sales'
  AND mg.action = 'delete'
ON CONFLICT (membership_id, module_key, action) DO UPDATE SET
  effect = EXCLUDED.effect,
  updated_at = NOW();

-- Additive template seed (force_return for manager/staff roles)
SELECT public.seed_tenant_roles_and_grants(id) FROM public.tenants;

-- =========================================================
-- 2. create — require thrift_sales create
-- =========================================================
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
  p_customer_notes TEXT DEFAULT NULL,
  p_courier_cod_amount NUMERIC(12,2) DEFAULT 0.00,
  p_other_expense_amount NUMERIC(12,2) DEFAULT 0.00
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
  v_courier_cod NUMERIC(12,2);
  v_other_expense NUMERIC(12,2);
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create') THEN
    RAISE EXCEPTION 'Creating a thrift sales invoice requires thrift_sales create permission';
  END IF;

  v_invoice_number := public.generate_thrift_invoice_number(p_tenant_id, COALESCE(p_date, NOW()));

  v_sale_channel := COALESCE(NULLIF(trim(p_sale_channel), ''), 'IN_STORE');
  IF v_sale_channel NOT IN ('IN_STORE', 'ONLINE') THEN
    RAISE EXCEPTION 'Invalid sale_channel: % (expected IN_STORE or ONLINE)', v_sale_channel;
  END IF;

  v_courier_cod := ROUND(COALESCE(p_courier_cod_amount, 0.00), 2);
  v_other_expense := ROUND(COALESCE(p_other_expense_amount, 0.00), 2);
  IF v_courier_cod < 0 OR v_other_expense < 0 THEN
    RAISE EXCEPTION 'Sale fee amounts cannot be negative';
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
    courier_cod_amount,
    other_expense_amount,
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
    v_courier_cod,
    v_other_expense,
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

  IF v_courier_cod > 0 THEN
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
      v_courier_cod,
      'Courier/COD for Sales Invoice #' || v_invoice_number,
      p_created_by,
      p_date
    );
  END IF;

  IF v_other_expense > 0 THEN
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
      v_other_expense,
      'Other expense for Sales Invoice #' || v_invoice_number,
      p_created_by,
      p_date
    );
  END IF;

  RETURN jsonb_build_object(
    'id', v_invoice_id,
    'invoice_number', v_invoice_number,
    'status', 'success'
  );
END;
$$;

-- =========================================================
-- 3. revert — return / force_return / staff_mistake
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

  DELETE FROM public.thrift_accounting_ledger
  WHERE tenant_id = p_tenant_id
    AND source = 'INVOICE'::public.thrift_ledger_source
    AND reference_id = p_invoice_id
    AND type = 'EXPENSE'::public.thrift_ledger_type;

  UPDATE public.thrift_sales_invoices
  SET
    status = 'RETURNED',
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
    'invoice_number', v_invoice_number,
    'status', 'RETURNED',
    'reason', v_reason,
    'deleted', false
  );
END;
$$;

COMMIT;

-- Phase 4: Advance is non-refundable on RTO + post-pay return (ledger REFUND clamp).
-- Return/RTO docs keep line sell amounts; cash/ledger REFUND excludes advance_amount.

BEGIN;

CREATE OR REPLACE FUNCTION public.create_thrift_sales_return(
  p_tenant_id BIGINT,
  p_invoice_id BIGINT,
  p_items JSONB,
  p_return_courier_amount NUMERIC(12,2) DEFAULT 0.00,
  p_notes TEXT DEFAULT NULL,
  p_created_by TEXT DEFAULT 'cashier'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice public.thrift_sales_invoices%ROWTYPE;
  v_return_courier NUMERIC(12,2);
  v_event_at TIMESTAMPTZ := NOW();
  v_is_online BOOLEAN;
  v_return_id BIGINT;
  v_return_number TEXT;
  v_refund_total NUMERIC(12,2) := 0.00;
  v_advance_amount NUMERIC(12,2) := 0.00;
  v_invoice_item_total NUMERIC(12,2) := 0.00;
  v_prior_line_refunds NUMERIC(12,2) := 0.00;
  v_advance_withheld NUMERIC(12,2) := 0.00;
  v_ledger_refund NUMERIC(12,2) := 0.00;
  v_item_count INT := 0;
  v_total_value NUMERIC(12,2) := 0.00;
  v_idx INT := 0;
  v_cum_return NUMERIC(12,2) := 0.00;
  v_alloc_return NUMERIC(12,2);
  v_share NUMERIC;
  v_line RECORD;
  v_remaining INT;
  v_new_status TEXT;
  v_new_payment TEXT;
  v_close_reason TEXT;
  v_actor TEXT := COALESCE(NULLIF(trim(p_created_by), ''), 'cashier');
BEGIN
  IF p_tenant_id IS NULL OR p_invoice_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id and invoice_id are required';
  END IF;

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'return')
    OR public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'force_return')
  ) THEN
    RAISE EXCEPTION 'Post-pay return requires thrift_sales return (or force_return) permission';
  END IF;

  v_return_courier := ROUND(COALESCE(p_return_courier_amount, 0.00), 2);
  IF v_return_courier < 0 THEN
    RAISE EXCEPTION 'return_courier_amount cannot be negative';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) < 1 THEN
    RAISE EXCEPTION 'p_items must be a non-empty JSON array';
  END IF;

  SELECT * INTO v_invoice
  FROM public.thrift_sales_invoices
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice % not found for tenant %', p_invoice_id, p_tenant_id;
  END IF;

  IF COALESCE(v_invoice.close_reason, '') = 'RTO' THEN
    RAISE EXCEPTION 'Invoice % is RTO-closed; cannot create post-pay return', p_invoice_id;
  END IF;

  IF v_invoice.status NOT IN ('ACTIVE', 'PARTIALLY_RETURNED') THEN
    RAISE EXCEPTION 'Invoice % status % cannot accept returns', p_invoice_id, v_invoice.status;
  END IF;

  v_is_online := COALESCE(v_invoice.sale_channel, 'IN_STORE') = 'ONLINE';

  IF v_is_online THEN
    IF COALESCE(v_invoice.delivery_status, '') IS DISTINCT FROM 'DELIVERED'
       AND v_invoice.status IS DISTINCT FROM 'PARTIALLY_RETURNED'
    THEN
      RAISE EXCEPTION
        'Online invoice % must be DELIVERED before Return items (use Mark RTO if refuse)',
        p_invoice_id;
    END IF;
  END IF;

  CREATE TEMP TABLE IF NOT EXISTS tmp_return_lines (
    invoice_item_id BIGINT PRIMARY KEY,
    stock_id BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    condition TEXT NOT NULL,
    refund_amount NUMERIC(12,2) NOT NULL,
    prior_delivery NUMERIC(12,2) NOT NULL DEFAULT 0,
    prior_cod_fee NUMERIC(12,2) NOT NULL DEFAULT 0,
    prior_packing NUMERIC(12,2) NOT NULL DEFAULT 0,
    prior_return_courier NUMERIC(12,2) NOT NULL DEFAULT 0
  ) ON COMMIT DROP;

  TRUNCATE tmp_return_lines;

  INSERT INTO tmp_return_lines (
    invoice_item_id,
    stock_id,
    quantity,
    condition,
    refund_amount,
    prior_delivery,
    prior_cod_fee,
    prior_packing,
    prior_return_courier
  )
  SELECT
    i.id,
    i.stock_id,
    GREATEST(req.qty, 1),
    req.condition,
    ROUND(i.final_price * GREATEST(req.qty, 1), 2),
    COALESCE(p.allocated_shop_delivery, 0),
    COALESCE(p.allocated_shop_cod_fee, 0),
    COALESCE(p.allocated_shop_packing, 0),
    COALESCE(p.allocated_return_courier, 0)
  FROM (
    SELECT DISTINCT ON (x.invoice_item_id)
      x.invoice_item_id,
      x.qty,
      x.condition
    FROM (
      SELECT
        (elem->>'invoice_item_id')::BIGINT AS invoice_item_id,
        GREATEST(COALESCE((elem->>'quantity')::INTEGER, 1), 1) AS qty,
        upper(trim(COALESCE(elem->>'condition', ''))) AS condition
      FROM jsonb_array_elements(p_items) AS elem
    ) x
    ORDER BY x.invoice_item_id
  ) req
  JOIN public.thrift_sales_invoice_items i
    ON i.id = req.invoice_item_id
   AND i.tenant_id = p_tenant_id
   AND i.invoice_id = p_invoice_id
  LEFT JOIN public.thrift_sales_pnl_lines p
    ON p.invoice_item_id = i.id
   AND p.tenant_id = p_tenant_id
  WHERE req.condition IN ('SELLABLE', 'DAMAGED')
    AND NOT EXISTS (
      SELECT 1
      FROM public.thrift_sales_return_items ri
      WHERE ri.invoice_item_id = i.id
    );

  GET DIAGNOSTICS v_item_count = ROW_COUNT;

  IF v_item_count = 0 THEN
    RAISE EXCEPTION 'No valid returnable lines in p_items (already returned, wrong invoice, or bad condition)';
  END IF;

  IF v_item_count <> jsonb_array_length(p_items) THEN
    RAISE EXCEPTION 'One or more return lines are invalid, already returned, or not on invoice %', p_invoice_id;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM tmp_return_lines t
    JOIN public.thrift_sales_invoice_items i
      ON i.id = t.invoice_item_id
    WHERE t.quantity > i.quantity
  ) THEN
    RAISE EXCEPTION 'Return quantity exceeds invoice line quantity';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM tmp_return_lines t
    LEFT JOIN public.thrift_sales_pnl_lines p
      ON p.invoice_item_id = t.invoice_item_id
     AND p.tenant_id = p_tenant_id
    WHERE p.id IS NULL
  ) THEN
    RAISE EXCEPTION
      'Invoice % has lines without PnL — deliver Online first (or recreate Offline sale)',
      p_invoice_id;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM tmp_return_lines t
    JOIN public.thrift_sales_pnl_lines p
      ON p.invoice_item_id = t.invoice_item_id
     AND p.tenant_id = p_tenant_id
    WHERE p.outcome IS DISTINCT FROM 'DELIVERED'
  ) THEN
    RAISE EXCEPTION 'Only DELIVERED PnL lines can be returned';
  END IF;

  SELECT COALESCE(SUM(refund_amount), 0)
  INTO v_refund_total
  FROM tmp_return_lines;

  v_total_value := v_refund_total;

  -- Advance is non-refundable: withhold proportional remaining advance from ledger REFUND.
  -- Return doc refund_amount stays line sell sum (PnL/stock). Cash/ledger refund excludes advance.
  v_advance_amount := ROUND(COALESCE(v_invoice.advance_amount, 0.00), 2);
  SELECT COALESCE(SUM(ROUND(i.final_price * i.quantity, 2)), 0)
  INTO v_invoice_item_total
  FROM public.thrift_sales_invoice_items i
  WHERE i.tenant_id = p_tenant_id
    AND i.invoice_id = p_invoice_id;
  SELECT COALESCE(SUM(ri.refund_amount), 0)
  INTO v_prior_line_refunds
  FROM public.thrift_sales_return_items ri
  JOIN public.thrift_sales_returns r
    ON r.id = ri.return_id
   AND r.tenant_id = ri.tenant_id
  WHERE r.tenant_id = p_tenant_id
    AND r.invoice_id = p_invoice_id;
  IF v_invoice_item_total > 0 AND v_advance_amount > 0 THEN
    v_advance_withheld := ROUND(
      v_advance_amount * (v_refund_total / v_invoice_item_total),
      2
    );
    -- Clamp so cumulative withheld cannot exceed advance
    IF v_advance_withheld > GREATEST(0.00, v_advance_amount - ROUND(
      v_advance_amount * (v_prior_line_refunds / v_invoice_item_total), 2
    )) THEN
      v_advance_withheld := GREATEST(
        0.00,
        ROUND(v_advance_amount - ROUND(v_advance_amount * (v_prior_line_refunds / v_invoice_item_total), 2), 2)
      );
    END IF;
  ELSE
    v_advance_withheld := 0.00;
  END IF;
  v_ledger_refund := GREATEST(0.00, ROUND(v_refund_total - v_advance_withheld, 2));
  v_return_number := public.generate_thrift_return_number(p_tenant_id, v_event_at);

  INSERT INTO public.thrift_sales_returns (
    tenant_id,
    invoice_id,
    return_number,
    status,
    refund_amount,
    return_courier_amount,
    notes,
    created_by
  ) VALUES (
    p_tenant_id,
    p_invoice_id,
    v_return_number,
    'COMPLETED',
    v_refund_total,
    v_return_courier,
    NULLIF(trim(p_notes), ''),
    v_actor
  )
  RETURNING id INTO v_return_id;

  INSERT INTO public.thrift_sales_return_items (
    return_id,
    tenant_id,
    invoice_item_id,
    stock_id,
    quantity,
    condition,
    refund_amount
  )
  SELECT
    v_return_id,
    p_tenant_id,
    invoice_item_id,
    stock_id,
    quantity,
    condition,
    refund_amount
  FROM tmp_return_lines;

  -- Restore stock per condition
  UPDATE public.thrift_stocks s
  SET
    quantity = s.quantity + t.quantity,
    status = CASE
      WHEN t.condition = 'DAMAGED' THEN 'DAMAGED'::public.thrift_stock_status
      ELSE 'AVAILABLE'::public.thrift_stock_status
    END,
    updated_at = NOW()
  FROM tmp_return_lines t
  WHERE s.id = t.stock_id
    AND s.tenant_id = p_tenant_id;

  -- Ledger insert-only (REFUND excludes non-refundable advance share)
  IF v_ledger_refund > 0 THEN
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
      v_ledger_refund,
      'item_refund ' || v_return_number
        || CASE WHEN v_advance_withheld > 0
             THEN ' (advance retained ' || v_advance_withheld::TEXT || ')'
             ELSE ''
           END
        || COALESCE(' — ' || NULLIF(trim(p_notes), ''), ''),
      v_actor,
      v_event_at
    );
  END IF;

  IF v_return_courier > 0 THEN
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
      'LOSS'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      p_invoice_id,
      v_return_courier,
      'return_courier ' || v_return_number,
      v_actor,
      v_event_at
    );
  END IF;

  -- PnL: only returned lines → CUSTOMER_RETURN; keep sunk shop fees; add return courier share
  FOR v_line IN
    SELECT *
    FROM tmp_return_lines
    ORDER BY invoice_item_id
  LOOP
    v_idx := v_idx + 1;

    IF v_total_value > 0 THEN
      v_share := v_line.refund_amount / v_total_value;
    ELSE
      v_share := 1.0 / v_item_count;
    END IF;

    IF v_idx = v_item_count THEN
      v_alloc_return := ROUND(v_return_courier - v_cum_return, 2);
    ELSE
      v_alloc_return := ROUND(v_return_courier * v_share, 2);
      v_cum_return := v_cum_return + v_alloc_return;
    END IF;

    UPDATE public.thrift_sales_pnl_lines
    SET
      outcome = 'CUSTOMER_RETURN',
      return_id = v_return_id,
      sell_amount = 0.00,
      allocated_shop_delivery = v_line.prior_delivery,
      allocated_shop_cod_fee = v_line.prior_cod_fee,
      allocated_shop_packing = v_line.prior_packing,
      allocated_return_courier = ROUND(v_line.prior_return_courier + v_alloc_return, 2),
      allocated_fees_total = ROUND(
        v_line.prior_delivery
        + v_line.prior_cod_fee
        + v_line.prior_packing
        + v_line.prior_return_courier
        + v_alloc_return,
        2
      ),
      cogs_is_loss = (v_line.condition = 'DAMAGED'),
      event_at = v_event_at,
      event_date = (v_event_at AT TIME ZONE 'UTC')::DATE,
      updated_at = NOW()
    WHERE tenant_id = p_tenant_id
      AND invoice_item_id = v_line.invoice_item_id;
  END LOOP;

  SELECT COUNT(*)::INT
  INTO v_remaining
  FROM public.thrift_sales_invoice_items i
  WHERE i.tenant_id = p_tenant_id
    AND i.invoice_id = p_invoice_id
    AND NOT EXISTS (
      SELECT 1
      FROM public.thrift_sales_return_items ri
      WHERE ri.invoice_item_id = i.id
    );

  IF v_remaining > 0 THEN
    v_new_status := 'PARTIALLY_RETURNED';
    v_close_reason := NULL;
    IF upper(COALESCE(v_invoice.payment_status, '')) = 'PAID'
       OR upper(COALESCE(v_invoice.payment_status, '')) = 'PARTIALLY_REFUNDED'
    THEN
      v_new_payment := 'PARTIALLY_REFUNDED';
    ELSE
      v_new_payment := v_invoice.payment_status;
    END IF;

    UPDATE public.thrift_sales_invoices
    SET
      status = v_new_status,
      payment_status = v_new_payment,
      close_reason = NULL,
      updated_at = NOW()
    WHERE id = p_invoice_id
      AND tenant_id = p_tenant_id;
  ELSE
    v_new_status := 'RETURNED';
    v_close_reason := 'CUSTOMER_RETURN';
    v_new_payment := 'REFUNDED';

    UPDATE public.thrift_sales_invoices
    SET
      status = v_new_status,
      payment_status = v_new_payment,
      close_reason = v_close_reason,
      reverted_at = v_event_at,
      reverted_by = v_actor,
      revert_reason = 'CUSTOMER_RETURN',
      revert_notes = NULLIF(trim(p_notes), ''),
      updated_at = NOW()
    WHERE id = p_invoice_id
      AND tenant_id = p_tenant_id;
  END IF;

  RETURN jsonb_build_object(
    'return_id', v_return_id,
    'return_number', v_return_number,
    'invoice_id', p_invoice_id,
    'refund_amount', v_refund_total,
    'ledger_refund_amount', v_ledger_refund,
    'advance_retained', v_advance_withheld,
    'return_courier_amount', v_return_courier,
    'status', v_new_status,
    'payment_status', v_new_payment,
    'close_reason', v_close_reason
  );
END;
$$;

COMMENT ON FUNCTION public.create_thrift_sales_return(BIGINT, BIGINT, JSONB, NUMERIC, TEXT, TEXT) IS
  'Post-pay return: docs + stock + PnL CUSTOMER_RETURN. Ledger REFUND excludes non-refundable advance share.';

REVOKE ALL ON FUNCTION public.create_thrift_sales_return(BIGINT, BIGINT, JSONB, NUMERIC, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_thrift_sales_return(BIGINT, BIGINT, JSONB, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_thrift_sales_return(BIGINT, BIGINT, JSONB, NUMERIC, TEXT, TEXT) TO service_role;

CREATE OR REPLACE FUNCTION public.revert_thrift_sales_invoice(
  p_tenant_id BIGINT,
  p_invoice_id BIGINT,
  p_reason TEXT,
  p_reverted_by TEXT DEFAULT 'cashier',
  p_notes TEXT DEFAULT NULL,
  p_force BOOLEAN DEFAULT false,
  p_return_courier_amount NUMERIC(12,2) DEFAULT 0.00
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
  v_force BOOLEAN := COALESCE(p_force, false);
  v_has_returns BOOLEAN := FALSE;
  v_return_courier NUMERIC(12,2);
  v_event_at TIMESTAMPTZ := NOW();
  v_is_online BOOLEAN;
  v_uncollected_delivery NUMERIC(12,2) := 0.00;
  v_advance_amount NUMERIC(12,2) := 0.00;
  v_ledger_refund NUMERIC(12,2) := 0.00;
  v_pool_delivery NUMERIC(12,2) := 0.00;
  v_pool_packing NUMERIC(12,2) := 0.00;
  v_pool_return NUMERIC(12,2) := 0.00;
  v_total_value NUMERIC(12,2) := 0.00;
  v_line_count INT := 0;
  v_idx INT := 0;
  v_cum_delivery NUMERIC(12,2) := 0.00;
  v_cum_packing NUMERIC(12,2) := 0.00;
  v_cum_return NUMERIC(12,2) := 0.00;
  v_line RECORD;
  v_line_value NUMERIC(12,2);
  v_share NUMERIC;
  v_alloc_delivery NUMERIC(12,2);
  v_alloc_packing NUMERIC(12,2);
  v_alloc_return NUMERIC(12,2);
  v_inbound_shipment_id BIGINT;
BEGIN
  v_reason := upper(trim(COALESCE(p_reason, '')));
  -- Legacy RETURN → RTO (temporary compat)
  IF v_reason = 'RETURN' THEN
    v_reason := 'RTO';
  END IF;

  IF v_reason NOT IN ('RTO', 'STAFF_MISTAKE') THEN
    RAISE EXCEPTION 'Invalid revert reason %. Expected RTO or STAFF_MISTAKE', p_reason;
  END IF;

  v_return_courier := ROUND(COALESCE(p_return_courier_amount, 0.00), 2);
  IF v_return_courier < 0 THEN
    RAISE EXCEPTION 'return_courier_amount cannot be negative';
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

  SELECT EXISTS (
    SELECT 1
    FROM public.thrift_sales_returns r
    WHERE r.tenant_id = p_tenant_id
      AND r.invoice_id = p_invoice_id
  )
  INTO v_has_returns;

  IF v_has_returns THEN
    RAISE EXCEPTION
      'Invoice % already has return documents; use create_thrift_sales_return, not whole-invoice RTO/staff mistake.',
      p_invoice_id;
  END IF;

  v_is_online := COALESCE(v_invoice.sale_channel, 'IN_STORE') = 'ONLINE';

  IF v_reason = 'STAFF_MISTAKE' THEN
    IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'staff_mistake') THEN
      RAISE EXCEPTION 'Staff mistake revert requires thrift_sales staff_mistake permission';
    END IF;
  ELSE
    -- RTO
    IF COALESCE(v_invoice.delivery_status, '') = 'DELIVERED' THEN
      RAISE EXCEPTION
        'Invoice % is already DELIVERED — use post-accept return (Return items), not Mark RTO',
        p_invoice_id;
    END IF;

    IF v_force THEN
      IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'force_return') THEN
        RAISE EXCEPTION
          'Force RTO requires thrift_sales force_return permission for tenant %',
          p_tenant_id;
      END IF;
    ELSE
      IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'return') THEN
        RAISE EXCEPTION 'Mark RTO requires thrift_sales return permission';
      END IF;
    END IF;

    IF NOT v_is_online THEN
      RAISE EXCEPTION 'Mark RTO applies to Online invoices only (use Return items for in-store)';
    END IF;
  END IF;

  v_invoice_number := v_invoice.invoice_number;

  -- Restore every sell line stock
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

    DELETE FROM public.thrift_sales_pnl_lines
    WHERE tenant_id = p_tenant_id
      AND invoice_id = p_invoice_id;

    DELETE FROM public.thrift_sales_invoices
    WHERE id = p_invoice_id
      AND tenant_id = p_tenant_id;

    RETURN jsonb_build_object(
      'id', p_invoice_id,
      'invoice_number', v_invoice_number,
      'status', 'DELETED',
      'reason', 'STAFF_MISTAKE',
      'deleted', true,
      'counter_unchanged', true
    );
  END IF;

  -- ── RTO soft close ──────────────────────────────────────────────
  -- Ledger insert-only: REFUND item total minus non-refundable advance;
  -- LOSS uncollected customer delivery; LOSS return courier.
  -- Keep prior EXPENSE rows (shop packing / shop delivery). Advance is never paid back.

  v_advance_amount := ROUND(COALESCE(v_invoice.advance_amount, 0.00), 2);
  v_ledger_refund := GREATEST(
    0.00,
    ROUND(COALESCE(v_invoice.total_invoice_amount, 0.00) - v_advance_amount, 2)
  );

  IF v_ledger_refund > 0 THEN
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
      v_ledger_refund,
      'RTO refund for Sales Invoice #' || v_invoice_number
        || CASE WHEN v_advance_amount > 0
             THEN ' (advance retained ' || v_advance_amount::TEXT || ')'
             ELSE ''
           END
        || COALESCE(' — ' || NULLIF(trim(p_notes), ''), ''),
      p_reverted_by,
      v_event_at
    );
  END IF;

  IF upper(COALESCE(v_invoice.courier_paid_by, '')) = 'CUSTOMER'
     AND COALESCE(v_invoice.courier_amount, 0) > 0
  THEN
    v_uncollected_delivery := ROUND(v_invoice.courier_amount, 2);
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
      'LOSS'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      p_invoice_id,
      v_uncollected_delivery,
      'uncollected_delivery',
      p_reverted_by,
      v_event_at
    );
  END IF;

  IF v_return_courier > 0 THEN
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
      'LOSS'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      p_invoice_id,
      v_return_courier,
      'return_courier',
      p_reverted_by,
      v_event_at
    );
  END IF;

  -- PnL: all lines → RTO; pool = full forward delivery + packing + return courier
  v_pool_delivery := ROUND(COALESCE(v_invoice.courier_amount, 0), 2);
  v_pool_packing := ROUND(COALESCE(v_invoice.packing_amount, 0), 2);
  v_pool_return := v_return_courier;

  SELECT
    COALESCE(SUM(ROUND(i.final_price * i.quantity, 2)), 0),
    COUNT(*)::INT
  INTO v_total_value, v_line_count
  FROM public.thrift_sales_invoice_items i
  WHERE i.tenant_id = p_tenant_id
    AND i.invoice_id = p_invoice_id;

  IF v_line_count = 0 THEN
    RAISE EXCEPTION 'Invoice % has no lines; cannot close RTO', p_invoice_id;
  END IF;

  FOR v_line IN
    SELECT
      i.id AS invoice_item_id,
      i.stock_id,
      i.quantity,
      ROUND(i.final_price * i.quantity, 2) AS sell_amount,
      s.shipment_id
    FROM public.thrift_sales_invoice_items i
    JOIN public.thrift_stocks s
      ON s.id = i.stock_id
     AND s.tenant_id = i.tenant_id
    WHERE i.tenant_id = p_tenant_id
      AND i.invoice_id = p_invoice_id
    ORDER BY i.id
  LOOP
    v_idx := v_idx + 1;
    v_inbound_shipment_id := v_line.shipment_id;
    IF v_inbound_shipment_id IS NULL THEN
      RAISE EXCEPTION
        'Stock item % has no inbound shipment; cannot write RTO PnL',
        v_line.stock_id;
    END IF;

    v_line_value := v_line.sell_amount;
    IF v_total_value > 0 THEN
      v_share := v_line_value / v_total_value;
    ELSE
      v_share := 1.0 / v_line_count;
    END IF;

    IF v_idx = v_line_count THEN
      v_alloc_delivery := ROUND(v_pool_delivery - v_cum_delivery, 2);
      v_alloc_packing := ROUND(v_pool_packing - v_cum_packing, 2);
      v_alloc_return := ROUND(v_pool_return - v_cum_return, 2);
    ELSE
      v_alloc_delivery := ROUND(v_pool_delivery * v_share, 2);
      v_alloc_packing := ROUND(v_pool_packing * v_share, 2);
      v_alloc_return := ROUND(v_pool_return * v_share, 2);
      v_cum_delivery := v_cum_delivery + v_alloc_delivery;
      v_cum_packing := v_cum_packing + v_alloc_packing;
      v_cum_return := v_cum_return + v_alloc_return;
    END IF;

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
      p_invoice_id,
      v_line.invoice_item_id,
      v_line.stock_id,
      v_inbound_shipment_id,
      'RTO',
      NULL,
      v_line.quantity,
      0.00,
      v_alloc_delivery,
      0.00,
      v_alloc_packing,
      v_alloc_return,
      ROUND(v_alloc_delivery + v_alloc_packing + v_alloc_return, 2),
      FALSE,
      v_event_at,
      (v_event_at AT TIME ZONE 'UTC')::DATE
    )
    ON CONFLICT (invoice_item_id) DO UPDATE SET
      outcome = 'RTO',
      return_id = NULL,
      sell_amount = 0.00,
      allocated_shop_delivery = EXCLUDED.allocated_shop_delivery,
      allocated_shop_cod_fee = 0.00,
      allocated_shop_packing = EXCLUDED.allocated_shop_packing,
      allocated_return_courier = EXCLUDED.allocated_return_courier,
      allocated_fees_total = EXCLUDED.allocated_fees_total,
      cogs_is_loss = FALSE,
      event_at = EXCLUDED.event_at,
      event_date = EXCLUDED.event_date,
      updated_at = NOW();
  END LOOP;

  UPDATE public.thrift_sales_invoices
  SET
    status = 'RETURNED',
    payment_status = 'REFUNDED',
    close_reason = 'RTO',
    delivery_status = 'RETURNED',
    return_courier_amount = v_return_courier,
    economics_closed_at = v_event_at,
    cod_expected = NULL,
    cod_remitted_amount = NULL,
    cod_remitted_at = NULL,
    cod_remittance_ref = NULL,
    reverted_at = v_event_at,
    reverted_by = p_reverted_by,
    revert_reason = 'RTO',
    revert_notes = NULLIF(trim(p_notes), ''),
    updated_at = NOW()
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id;

  RETURN jsonb_build_object(
    'id', p_invoice_id,
    'invoice_number', v_invoice_number,
    'status', 'RETURNED',
    'close_reason', 'RTO',
    'delivery_status', 'RETURNED',
    'payment_status', 'REFUNDED',
    'return_courier_amount', v_return_courier,
    'ledger_refund_amount', v_ledger_refund,
    'advance_retained', v_advance_amount,
    'reason', 'RTO',
    'deleted', false
  );
END;
$$;

COMMENT ON FUNCTION public.revert_thrift_sales_invoice(BIGINT, BIGINT, TEXT, TEXT, TEXT, BOOLEAN, NUMERIC) IS
  'RTO: soft-close; ledger REFUND excludes advance_amount (non-refundable). STAFF_MISTAKE: hard-delete. Legacy RETURN→RTO.';

REVOKE ALL ON FUNCTION public.revert_thrift_sales_invoice(BIGINT, BIGINT, TEXT, TEXT, TEXT, BOOLEAN, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.revert_thrift_sales_invoice(BIGINT, BIGINT, TEXT, TEXT, TEXT, BOOLEAN, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revert_thrift_sales_invoice(BIGINT, BIGINT, TEXT, TEXT, TEXT, BOOLEAN, NUMERIC) TO service_role;

COMMIT;

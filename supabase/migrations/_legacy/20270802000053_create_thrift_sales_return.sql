-- Post-pay / post-accept return (Situation B).
-- Partial or full line set → thrift_sales_returns + PnL CUSTOMER_RETURN.
-- Not for no-pickup RTO (use revert_thrift_sales_invoice).

BEGIN;

CREATE OR REPLACE FUNCTION public.generate_thrift_return_number(
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

  INSERT INTO public.thrift_return_counters (tenant_id, year_month, last_value)
  VALUES (p_tenant_id, v_year_month, 1)
  ON CONFLICT (tenant_id, year_month)
  DO UPDATE
    SET last_value = public.thrift_return_counters.last_value + 1
  RETURNING last_value INTO v_next;

  RETURN 'RET-' || v_year_month || '-' || lpad(v_next::TEXT, 5, '0');
END;
$$;

REVOKE ALL ON FUNCTION public.generate_thrift_return_number(BIGINT, TIMESTAMPTZ) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.generate_thrift_return_number(BIGINT, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_thrift_return_number(BIGINT, TIMESTAMPTZ) TO service_role;

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

  -- Ledger insert-only
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
    v_refund_total,
    'item_refund ' || v_return_number
      || COALESCE(' — ' || NULLIF(trim(p_notes), ''), ''),
    v_actor,
    v_event_at
  );

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
    'return_courier_amount', v_return_courier,
    'status', v_new_status,
    'payment_status', v_new_payment,
    'close_reason', v_close_reason
  );
END;
$$;

COMMENT ON FUNCTION public.create_thrift_sales_return(BIGINT, BIGINT, JSONB, NUMERIC, TEXT, TEXT) IS
  'Post-pay partial/full return: return docs, stock restore, ledger REFUND+LOSS, PnL CUSTOMER_RETURN.';

REVOKE ALL ON FUNCTION public.create_thrift_sales_return(BIGINT, BIGINT, JSONB, NUMERIC, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_thrift_sales_return(BIGINT, BIGINT, JSONB, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_thrift_sales_return(BIGINT, BIGINT, JSONB, NUMERIC, TEXT, TEXT) TO service_role;

COMMIT;

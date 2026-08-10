-- Phase B (task-rto): revert_thrift_sales_invoice RTO economics.
-- RTO soft-close (no thrift_sales_returns). STAFF_MISTAKE hard-delete unchanged.
-- Legacy p_reason=RETURN maps → RTO temporarily.

BEGIN;

DROP FUNCTION IF EXISTS public.revert_thrift_sales_invoice(BIGINT, BIGINT, TEXT, TEXT, TEXT, BOOLEAN);

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
  -- Ledger insert-only: REFUND item total; LOSS uncollected customer delivery; LOSS return courier.
  -- Keep prior EXPENSE rows (shop packing / shop delivery).

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
    'RTO refund for Sales Invoice #' || v_invoice_number
      || COALESCE(' — ' || NULLIF(trim(p_notes), ''), ''),
    p_reverted_by,
    v_event_at
  );

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
    'reason', 'RTO',
    'deleted', false
  );
END;
$$;

COMMENT ON FUNCTION public.revert_thrift_sales_invoice(BIGINT, BIGINT, TEXT, TEXT, TEXT, BOOLEAN, NUMERIC) IS
  'RTO: soft-close Online refuse (stock restore, ledger REFUND+LOSS, PnL RTO, close_reason=RTO). STAFF_MISTAKE: hard-delete. Legacy RETURN maps to RTO.';

REVOKE ALL ON FUNCTION public.revert_thrift_sales_invoice(BIGINT, BIGINT, TEXT, TEXT, TEXT, BOOLEAN, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.revert_thrift_sales_invoice(BIGINT, BIGINT, TEXT, TEXT, TEXT, BOOLEAN, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revert_thrift_sales_invoice(BIGINT, BIGINT, TEXT, TEXT, TEXT, BOOLEAN, NUMERIC) TO service_role;

COMMIT;

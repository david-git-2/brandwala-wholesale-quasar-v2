-- Phase 6: Hybrid revert window RPC
-- - p_force (default false) bypasses return window for RETURN only
-- - RETURN enforces thrift_settings.return_window_days (0 = block)
-- - STAFF_MISTAKE ignores window
-- - force requires thrift_sales edit membership

BEGIN;

DROP FUNCTION IF EXISTS public.revert_thrift_sales_invoice(
  BIGINT, BIGINT, TEXT, TEXT, TEXT
);

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

  -- RETURN: enforce return window unless forced (STAFF_MISTAKE ignores window)
  IF v_reason = 'RETURN' THEN
    IF v_force THEN
      IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'edit') THEN
        RAISE EXCEPTION
          'Force revert requires thrift_sales edit permission for tenant %',
          p_tenant_id;
      END IF;
    ELSE
      SELECT return_window_days INTO v_return_window_days
      FROM public.thrift_settings
      WHERE tenant_id = p_tenant_id;

      IF NOT FOUND THEN
        v_return_window_days := 30;
      END IF;

      IF v_return_window_days = 0 THEN
        RAISE EXCEPTION
          'Customer returns are disabled (return_window_days=0). Use p_force with thrift_sales edit, or STAFF_MISTAKE.';
      END IF;

      v_deadline := v_invoice.date + make_interval(days => v_return_window_days);
      IF NOW() > v_deadline THEN
        RAISE EXCEPTION
          'Return window expired: invoice date % + % day(s) ended at %. Use p_force with thrift_sales edit to override.',
          v_invoice.date,
          v_return_window_days,
          v_deadline;
      END IF;
    END IF;
  END IF;

  v_invoice_number := v_invoice.invoice_number;

  -- Restore stock for all line items
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

  -- Staff mistake: hard delete invoice + scrub ledger (no orphan REVENUE)
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

  -- Return: soft revert
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

GRANT EXECUTE ON FUNCTION public.revert_thrift_sales_invoice(
  BIGINT, BIGINT, TEXT, TEXT, TEXT, BOOLEAN
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revert_thrift_sales_invoice(
  BIGINT, BIGINT, TEXT, TEXT, TEXT, BOOLEAN
) TO service_role;

COMMIT;

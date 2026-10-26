-- Migration: revert_thrift_sales_invoice — STAFF_MISTAKE hard-delete per sales/workflow §6
-- Docs: doc/v2/thrift/sales/rpc/revert_thrift_sales_invoice.md
-- Counter never decremented. Block if thrift_sales_returns exist.
-- RETURN path kept as legacy soft-return until RTO phase.

BEGIN;

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
  v_has_returns BOOLEAN := FALSE;
BEGIN
  v_reason := upper(trim(COALESCE(p_reason, '')));
  IF v_reason NOT IN ('RETURN', 'STAFF_MISTAKE') THEN
    RAISE EXCEPTION
      'Invalid revert reason %. Expected RETURN or STAFF_MISTAKE (RTO path lands in a later migration)',
      p_reason;
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

  IF v_reason = 'STAFF_MISTAKE' THEN
    IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'staff_mistake') THEN
      RAISE EXCEPTION 'Staff mistake revert requires thrift_sales staff_mistake permission';
    END IF;

    IF v_has_returns THEN
      RAISE EXCEPTION
        'Cannot staff-mistake invoice %: post-pay returns already exist. Use return/reverse ops instead.',
        p_invoice_id;
    END IF;
  ELSIF v_reason = 'RETURN' THEN
    IF v_has_returns THEN
      RAISE EXCEPTION
        'Invoice % already has return documents; use create_thrift_sales_return or reverse ops, not whole-invoice RETURN.',
        p_invoice_id;
    END IF;

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

  -- Restore every sell line stock (AVAILABLE clears holds via stock trigger)
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
    -- Scrub money events; do not post REFUND/LOSS
    DELETE FROM public.thrift_accounting_ledger
    WHERE tenant_id = p_tenant_id
      AND source = 'INVOICE'::public.thrift_ledger_source
      AND reference_id = p_invoice_id;

    -- Explicit PnL scrub (also cascades from invoice delete)
    DELETE FROM public.thrift_sales_pnl_lines
    WHERE tenant_id = p_tenant_id
      AND invoice_id = p_invoice_id;

    -- Hard-delete commercial document (+ items CASCADE). Never touch thrift_invoice_counters.
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

  -- Legacy soft RETURN (pre full RTO path) — keep expenses scrub inconsistent with goal docs;
  -- RTO phase will replace this branch.
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

COMMENT ON FUNCTION public.revert_thrift_sales_invoice(BIGINT, BIGINT, TEXT, TEXT, TEXT, BOOLEAN) IS
  'STAFF_MISTAKE: hard-delete invoice+ledger+PnL, restore stock, leave invoice counter gaps. RETURN: legacy soft return until RTO phase.';

COMMIT;

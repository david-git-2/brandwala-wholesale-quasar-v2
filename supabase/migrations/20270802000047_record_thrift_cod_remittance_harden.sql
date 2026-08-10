-- Harden record_thrift_cod_remittance to locked cash-track plan:
-- - Online invoices only
-- - WRITTEN_OFF requires non-empty notes

CREATE OR REPLACE FUNCTION public.record_thrift_cod_remittance(
  p_tenant_id BIGINT,
  p_invoice_id BIGINT,
  p_remitted_amount NUMERIC(12,2),
  p_actor TEXT,
  p_remitted_at TIMESTAMPTZ DEFAULT NOW(),
  p_remittance_ref TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_outcome TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice public.thrift_sales_invoices%ROWTYPE;
  v_remitted NUMERIC(12,2);
  v_outcome TEXT;
  v_payment_status TEXT;
  v_notes TEXT;
BEGIN
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'edit')
    OR public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create')
  ) THEN
    RAISE EXCEPTION 'Recording COD remittance requires thrift_sales edit or create permission';
  END IF;

  v_remitted := ROUND(COALESCE(p_remitted_amount, 0.00), 2);
  IF v_remitted < 0 THEN
    RAISE EXCEPTION 'Remitted amount cannot be negative';
  END IF;

  SELECT * INTO v_invoice
  FROM public.thrift_sales_invoices
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice % not found for tenant %', p_invoice_id, p_tenant_id;
  END IF;

  IF upper(trim(COALESCE(v_invoice.sale_channel, ''))) IS DISTINCT FROM 'ONLINE' THEN
    RAISE EXCEPTION
      'Invoice % sale_channel is % — remittance only allowed on ONLINE invoices',
      p_invoice_id,
      v_invoice.sale_channel;
  END IF;

  IF v_invoice.status IS DISTINCT FROM 'ACTIVE' THEN
    RAISE EXCEPTION 'Invoice % is % — remittance only allowed on ACTIVE invoices', p_invoice_id, v_invoice.status;
  END IF;

  IF v_invoice.payment_status IS DISTINCT FROM 'COD_PENDING' THEN
    RAISE EXCEPTION
      'Invoice % payment_status is % — remittance only allowed when COD_PENDING',
      p_invoice_id,
      v_invoice.payment_status;
  END IF;

  v_outcome := upper(trim(COALESCE(p_outcome, '')));
  IF v_outcome = '' THEN
    IF v_invoice.cod_expected IS NULL OR v_remitted >= v_invoice.cod_expected THEN
      v_outcome := 'PAID';
    ELSE
      v_outcome := 'KEEP_PENDING';
    END IF;
  END IF;

  IF v_outcome NOT IN ('PAID', 'KEEP_PENDING', 'WRITTEN_OFF') THEN
    RAISE EXCEPTION 'Invalid outcome % (expected PAID, KEEP_PENDING, or WRITTEN_OFF)', p_outcome;
  END IF;

  IF v_outcome = 'WRITTEN_OFF' AND NULLIF(trim(COALESCE(p_notes, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Notes are required when writing off COD remittance';
  END IF;

  IF v_outcome = 'PAID' THEN
    v_payment_status := 'PAID';
  ELSIF v_outcome = 'WRITTEN_OFF' THEN
    v_payment_status := 'WRITTEN_OFF';
  ELSE
    v_payment_status := 'COD_PENDING';
  END IF;

  v_notes := v_invoice.notes;
  IF NULLIF(trim(p_notes), '') IS NOT NULL THEN
    v_notes := CASE
      WHEN NULLIF(trim(v_notes), '') IS NULL THEN trim(p_notes)
      ELSE trim(v_notes) || E'\n' || trim(p_notes)
    END;
  END IF;

  UPDATE public.thrift_sales_invoices
  SET
    cod_remitted_amount = v_remitted,
    cod_remitted_at = COALESCE(p_remitted_at, NOW()),
    cod_remittance_ref = COALESCE(NULLIF(trim(p_remittance_ref), ''), cod_remittance_ref),
    payment_status = v_payment_status,
    notes = v_notes,
    updated_at = NOW()
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id;

  RETURN jsonb_build_object(
    'invoice_id', p_invoice_id,
    'payment_status', v_payment_status,
    'cod_expected', v_invoice.cod_expected,
    'cod_remitted_amount', v_remitted,
    'outcome', v_outcome
  );
END;
$$;

COMMENT ON FUNCTION public.record_thrift_cod_remittance(
  BIGINT, BIGINT, NUMERIC, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT
) IS
  'Record Online COD cash on invoice. Outcomes PAID/KEEP_PENDING/WRITTEN_OFF. No ledger/PnL. WRITTEN_OFF requires notes.';

GRANT EXECUTE ON FUNCTION public.record_thrift_cod_remittance(
  BIGINT, BIGINT, NUMERIC, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_thrift_cod_remittance(
  BIGINT, BIGINT, NUMERIC, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT
) TO service_role;

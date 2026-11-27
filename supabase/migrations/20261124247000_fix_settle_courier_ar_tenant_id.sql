-- settle_dropship_courier_ar_from_remittance: bills view uses tenant_id (parent_tenant_id retired).

CREATE OR REPLACE FUNCTION public.settle_dropship_courier_ar_from_remittance(
  p_ar_bill_id bigint,
  p_order_id bigint,
  p_order_no text,
  p_remittance_ref text,
  p_receipt_payment_id bigint DEFAULT NULL
) RETURNS numeric
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO public
AS $$
DECLARE
  v_ar public.bills;
  v_bal jsonb;
  v_family_due numeric(12, 2);
  v_remaining numeric(12, 2);
  v_chunk numeric(12, 2);
  v_total_settled numeric(12, 2) := 0;
  v_bill record;
  v_note text;
BEGIN
  IF p_ar_bill_id IS NULL THEN
    RETURN 0;
  END IF;

  SELECT * INTO v_ar FROM public.bills WHERE id = p_ar_bill_id FOR UPDATE;
  IF v_ar.id IS NULL THEN
    RAISE EXCEPTION 'courier AR bill not found';
  END IF;

  IF NOT public.is_dropship_courier_ar_bill(v_ar) THEN
    RAISE EXCEPTION 'bill is not a dropship courier AR bill';
  END IF;

  IF v_ar.invoice_status <> 'issued'::public.global_invoice_status THEN
    RETURN 0;
  END IF;

  v_bal := public.get_bill_net_balances(p_ar_bill_id);
  v_family_due := greatest(coalesce((v_bal->>'due_amount')::numeric, 0), 0);
  v_remaining := v_family_due;

  IF v_remaining <= 0 THEN
    RETURN 0;
  END IF;

  v_note := format(
    'Courier AR cleared from remittance — order #%s — ref %s',
    coalesce(nullif(trim(p_order_no), ''), p_order_id::text),
    coalesce(nullif(trim(p_remittance_ref), ''), '—')
  );

  FOR v_bill IN
    SELECT
      b.id,
      b.due_amount,
      b.tenant_id,
      b.issued_by_tenant_id
    FROM public.bills b
    WHERE (
        b.id = p_ar_bill_id
        OR b.parent_bill_id = p_ar_bill_id
      )
      AND b.invoice_status = 'issued'::public.global_invoice_status
      AND greatest(coalesce(b.due_amount, 0), 0) > 0
    ORDER BY
      CASE WHEN b.id = p_ar_bill_id THEN 0 ELSE 1 END,
      b.id
    FOR UPDATE
  LOOP
    v_chunk := least(v_remaining, greatest(coalesce(v_bill.due_amount, 0), 0));
    IF v_chunk <= 0 THEN
      CONTINUE;
    END IF;

    INSERT INTO public.invoice_write_offs (
      tenant_id,
      invoice_id,
      payment_id,
      amount,
      reason,
      note,
      approved_by
    )
    VALUES (
      v_bill.tenant_id,
      v_bill.id,
      p_receipt_payment_id,
      v_chunk,
      'dispute_settlement',
      v_note,
      CASE
        WHEN auth.uid() IS NOT NULL
          AND EXISTS (SELECT 1 FROM auth.users u WHERE u.id = auth.uid())
        THEN auth.uid()
        ELSE NULL
      END
    );

    PERFORM public.recompute_global_invoice_payment_status(v_bill.id);

    v_total_settled := v_total_settled + v_chunk;
    v_remaining := v_remaining - v_chunk;

    IF v_remaining <= 0 THEN
      EXIT;
    END IF;
  END LOOP;

  PERFORM public.recompute_global_invoice_payment_status(p_ar_bill_id);

  RETURN round(v_total_settled, 2);
END;
$$;
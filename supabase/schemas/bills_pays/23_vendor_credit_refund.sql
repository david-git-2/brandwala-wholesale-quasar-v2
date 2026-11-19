-- Vendor AP credit note cash refund: kernel deposit + bill settlement (no legacy public.pays).

CREATE OR REPLACE FUNCTION public.post_vendor_credit_refund(
  p_credit_note_id bigint,
  p_amount numeric,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_received_on date DEFAULT CURRENT_DATE,
  p_note text DEFAULT NULL,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_source_currency_code text DEFAULT NULL,
  p_transaction_rate numeric DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL,
  p_cash_location_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_cn_k money_kernel.bills;
  v_cn_v public.bills;
  v_parent_kind text;
  v_refund numeric(12, 2);
  v_reason text;
  v_settle_currency text := 'BDT';
  v_foreign_amt numeric(12, 2);
  v_fx_rate numeric(15, 6) := 1.000000;
  v_base_currency text := 'BDT';
  v_source_currency text;
  v_transaction_rate numeric(15, 6) := 1.000000;
  v_payment_face numeric(12, 2);
  v_cash_amount numeric(18, 4);
  v_bill_currency text;
  v_due_face numeric(18, 4);
  v_refund_face numeric(18, 4);
  v_books_rate numeric(15, 6);
  v_alloc_bill numeric(18, 4);
  v_alloc_books numeric(18, 4);
  v_tenant_profile_id bigint;
  v_books_tenant_id bigint;
  v_location_ref bigint;
  v_location_id bigint;
  v_bundle_id bigint;
  v_pay money_kernel.pays;
  v_settle money_kernel.bill_settlements;
BEGIN
  IF p_credit_note_id IS NULL THEN
    RAISE EXCEPTION 'credit_note_id is required';
  END IF;
  v_location_ref := coalesce(p_cash_location_id, p_cashbook_point_id);
  IF v_location_ref IS NULL THEN
    RAISE EXCEPTION 'Choose a receive location for the refund';
  END IF;

  v_refund := round(coalesce(p_amount, 0), 2);
  IF v_refund <= 0 AND coalesce(p_foreign_amount, 0) <= 0 THEN
    RAISE EXCEPTION 'Refund amount must be greater than zero';
  END IF;

  SELECT * INTO v_cn_k
  FROM money_kernel.bills
  WHERE id = p_credit_note_id
  FOR UPDATE;
  IF v_cn_k.id IS NULL THEN
    RAISE EXCEPTION 'bill not found';
  END IF;
  IF v_cn_k.kind <> 'credit_note' THEN
    RAISE EXCEPTION 'Refund applies only to a credit note';
  END IF;
  IF v_cn_k.status IN ('draft', 'voided') THEN
    RAISE EXCEPTION 'Credit note must be issued';
  END IF;

  SELECT * INTO v_cn_v FROM public.bills WHERE id = p_credit_note_id;
  IF v_cn_v.invoice_type IS DISTINCT FROM 'ap'::public.global_invoice_type THEN
    RAISE EXCEPTION 'Vendor refund applies only to AP credit notes';
  END IF;

  IF v_cn_k.parent_bill_id IS NOT NULL THEN
    SELECT kind INTO v_parent_kind
    FROM money_kernel.bills
    WHERE id = v_cn_k.parent_bill_id;
    IF v_parent_kind IS NULL
       OR v_parent_kind NOT IN ('shipment_cost_ap', 'dropship_courier_ap') THEN
      -- allow any AP parent via desk invoice_type on parent
      IF NOT EXISTS (
        SELECT 1 FROM public.bills pb
        WHERE pb.id = v_cn_k.parent_bill_id
          AND pb.invoice_type = 'ap'::public.global_invoice_type
      ) THEN
        RAISE EXCEPTION 'Vendor refund applies only to AP credit notes';
      END IF;
    END IF;
  END IF;

  v_tenant_profile_id := v_cn_k.to_profile_id;
  IF v_tenant_profile_id IS NULL THEN
    RAISE EXCEPTION 'Credit note has no tenant payee profile';
  END IF;

  IF NOT (
    coalesce(auth.role(), '') = 'service_role'
    OR public.user_can_manage_books_tenant(v_cn_k.tenant_id)
    OR public.membership_has_module_action(v_cn_k.tenant_id, 'payments', 'collect_payment')
    OR public.membership_has_module_action(v_cn_k.tenant_id, 'global_invoice', 'edit')
  ) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  v_books_tenant_id := public.resolve_books_tenant_id(v_cn_k.tenant_id);
  v_location_id := public._kernel_resolve_cash_location_id(
    v_books_tenant_id,
    v_tenant_profile_id,
    v_location_ref
  );

  v_reason := coalesce(nullif(trim(coalesce(p_note, '')), ''), 'Vendor credit refund');
  v_base_currency := public.resolve_tenant_base_currency_code(v_cn_k.tenant_id);

  SELECT n.settlement_currency_code, n.foreign_amount, n.exchange_rate, n.amount_bdt
  INTO v_settle_currency, v_foreign_amt, v_fx_rate, v_refund
  FROM public.normalize_pay_settlement_fx(
    v_refund,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    v_base_currency
  ) n;

  IF v_refund <= 0 THEN
    RAISE EXCEPTION 'Refund amount must be greater than zero';
  END IF;

  v_bill_currency := upper(coalesce(nullif(trim(v_cn_k.currency_code), ''), v_base_currency));
  v_due_face := coalesce(v_cn_k.due_amount, 0);

  IF coalesce(v_foreign_amt, 0) > 0 THEN
    v_refund_face := round(v_foreign_amt, 2);
    IF v_refund_face > v_due_face THEN
      RAISE EXCEPTION 'Refund % exceeds open credit % on the note', v_refund_face, v_due_face;
    END IF;
  ELSIF v_bill_currency = v_base_currency THEN
    IF v_refund > v_due_face THEN
      RAISE EXCEPTION 'Refund % exceeds open credit % on the note', v_refund, v_due_face;
    END IF;
    v_refund_face := v_refund;
  ELSE
    v_books_rate := coalesce(
      nullif((v_cn_v.books_exchange_rate), 0),
      nullif(p_exchange_rate, 0),
      0
    );
    IF v_books_rate <= 0 THEN
      RAISE EXCEPTION 'exchange_rate required for % credit note refund', v_bill_currency;
    END IF;
    v_refund_face := round(v_refund / v_books_rate, 2);
    IF v_refund_face > v_due_face THEN
      RAISE EXCEPTION 'Refund % exceeds open credit % on the note', v_refund_face, v_due_face;
    END IF;
  END IF;

  v_alloc_bill := round(v_refund_face, 2);

  v_source_currency := upper(trim(coalesce(p_source_currency_code, '')));
  IF v_source_currency = '' THEN
    v_source_currency := upper(coalesce(nullif(trim(v_cn_k.currency_code), ''), v_base_currency));
  END IF;

  IF upper(v_settle_currency) = v_source_currency THEN
    v_transaction_rate := 1.000000;
  ELSE
    v_transaction_rate := coalesce(p_transaction_rate, 0);
    IF v_transaction_rate <= 0 THEN
      RAISE EXCEPTION 'transaction_rate required when pot currency (%) differs from refund currency (%)',
        v_source_currency, v_settle_currency;
    END IF;
  END IF;

  IF upper(v_settle_currency) = v_base_currency THEN
    v_payment_face := v_refund;
  ELSE
    v_payment_face := coalesce(v_foreign_amt, v_refund_face);
  END IF;

  IF v_source_currency = v_bill_currency THEN
    v_cash_amount := v_alloc_bill;
  ELSE
    v_cash_amount := round(v_payment_face * v_transaction_rate, 2);
  END IF;

  IF v_source_currency = v_base_currency THEN
    v_books_rate := 1.000000;
  ELSIF v_bill_currency = v_source_currency THEN
    v_books_rate := coalesce(
      nullif(p_transaction_rate, 0),
      nullif((v_cn_v.books_exchange_rate), 0),
      nullif(p_exchange_rate, 0),
      money_kernel.fn_resolve_books_rate(v_cn_k.tenant_id, v_source_currency)
    );
  ELSE
    v_books_rate := coalesce(
      nullif((v_cn_v.books_exchange_rate), 0),
      nullif(p_exchange_rate, 0),
      nullif(p_transaction_rate, 0),
      money_kernel.fn_resolve_books_rate(v_cn_k.tenant_id, v_source_currency),
      1.000000
    );
  END IF;

  IF v_books_rate <= 0 THEN
    RAISE EXCEPTION 'invalid_rate: books_rate must be > 0';
  END IF;

  v_alloc_books := round(v_alloc_bill * v_books_rate, 4);

  PERFORM 1 FROM money_kernel.cash_locations WHERE id = v_location_id FOR UPDATE;

  v_bundle_id := money_kernel.fn_open_cash_bundle(
    v_cn_k.tenant_id,
    v_location_id,
    v_source_currency,
    v_books_rate,
    NULL
  );

  INSERT INTO money_kernel.pays (
    tenant_id, kind, from_profile_id, to_profile_id,
    from_cash_bundle_id, to_cash_bundle_id,
    amount, currency_code, books_amount, books_rate, exchange_rate,
    payment_date, status, refs, meta, created_by
  ) VALUES (
    v_cn_k.tenant_id, 'deposit', NULL, v_tenant_profile_id,
    NULL, v_bundle_id,
    v_cash_amount, v_source_currency, round(v_cash_amount * v_books_rate, 4), v_books_rate, 1,
    coalesce(p_received_on, current_date), 'posted',
    jsonb_build_object('credit_note_id', p_credit_note_id),
    jsonb_build_object(
      'note', v_reason,
      'purpose', 'vendor_credit_refund',
      'credit_note_id', p_credit_note_id,
      'credit_note_no', v_cn_k.invoice_no,
      'parent_bill_id', v_cn_k.parent_bill_id,
      'settlement_currency_code', v_settle_currency,
      'foreign_amount', v_foreign_amt,
      'exchange_rate', v_fx_rate,
      'source_currency_code', v_source_currency,
      'transaction_rate', v_transaction_rate,
      'cash_location_id', v_location_id
    ),
    auth.uid()
  )
  RETURNING * INTO v_pay;

  PERFORM money_kernel.fn_ensure_header_pay_bundle_lines(v_cn_k.tenant_id, v_pay.id);

  INSERT INTO money_kernel.bill_settlements (
    tenant_id, bill_id, settlement_kind, pays_id, source_bill_id,
    allocated_amount, allocated_books_amount
  ) VALUES (
    v_cn_k.tenant_id, v_cn_k.id, 'pay', v_pay.id, NULL,
    v_alloc_bill, v_alloc_books
  )
  RETURNING * INTO v_settle;

  RETURN jsonb_build_object(
    'pays_id', v_pay.id,
    'settlement_id', v_settle.id,
    'cash_bundle_id', v_bundle_id,
    'amount', v_alloc_bill,
    'currency_code', v_bill_currency,
    'cash_amount', v_cash_amount,
    'cash_currency_code', v_source_currency
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.post_vendor_credit_refund(
  bigint, numeric, bigint, date, text, text, numeric, numeric, text, numeric, bigint, bigint
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_vendor_credit_refund(
  bigint, numeric, bigint, date, text, text, numeric, numeric, text, numeric, bigint, bigint
) TO service_role;
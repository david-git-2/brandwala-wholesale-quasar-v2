-- Kernel vendor credit refund + recompute guard + deposit/CN settlement guard.

DROP FUNCTION IF EXISTS public.post_vendor_credit_refund(
  bigint, numeric, bigint, date, text, text, numeric, numeric, text, numeric, bigint
);

-- fn_bill_settlements_pay_guard (deposit settles credit_note)
CREATE OR REPLACE FUNCTION money_kernel.fn_bill_settlements_pay_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_pay    money_kernel.pays;
  v_bill   money_kernel.bills;
  v_source money_kernel.bills;
  v_target money_kernel.bills;
BEGIN
  IF NEW.settlement_kind = 'pay' THEN
    IF NEW.pays_id IS NULL THEN
      RAISE EXCEPTION 'invalid_settlement: pay kind requires pays_id';
    END IF;

    SELECT * INTO v_pay
      FROM money_kernel.pays
     WHERE id = NEW.pays_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'not_found: pays %', NEW.pays_id;
    END IF;

    SELECT * INTO v_bill FROM money_kernel.bills WHERE id = NEW.bill_id;

    IF v_pay.status = 'posted'
       AND v_pay.kind = 'deposit'
       AND v_pay.tenant_id = NEW.tenant_id
       AND v_bill.kind = 'credit_note' THEN
      RETURN NEW;
    END IF;

    IF v_pay.status <> 'posted'
       OR v_pay.kind <> 'payment'
       OR v_pay.tenant_id <> NEW.tenant_id THEN
      RAISE EXCEPTION
        'invalid_pays: pay settlement requires posted payment pays in same tenant (I31)';
    END IF;

    RETURN NEW;
  END IF;

  IF NEW.settlement_kind = 'document' THEN
    IF NEW.source_bill_id IS NULL THEN
      RAISE EXCEPTION 'invalid_settlement: document kind requires source_bill_id';
    END IF;

    SELECT * INTO v_source
      FROM money_kernel.bills
     WHERE id = NEW.source_bill_id;

    SELECT * INTO v_target
      FROM money_kernel.bills
     WHERE id = NEW.bill_id;

    IF v_source.id IS NULL OR v_target.id IS NULL THEN
      RAISE EXCEPTION 'not_found: source or target bill for document settlement';
    END IF;

    IF v_source.kind <> 'credit_note' THEN
      RAISE EXCEPTION
        'invalid_arguments: document settlement source must be credit_note, got %',
        v_source.kind;
    END IF;

    IF v_target.from_profile_id IS DISTINCT FROM v_source.to_profile_id
       OR v_target.to_profile_id IS DISTINCT FROM v_source.from_profile_id THEN
      RAISE EXCEPTION
        'invalid_arguments: document apply requires target.from=source.to and target.to=source.from (I29)';
    END IF;

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

-- recompute_global_invoice_payment_status (kernel-safe; never UPDATE public.bills view)
CREATE OR REPLACE FUNCTION public.recompute_global_invoice_payment_status(p_global_invoice_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_bill money_kernel.bills;
  v_root_id bigint;
  v_total numeric(18, 4);
  v_paid numeric(18, 4);
  v_written_off numeric(18, 4);
  v_credits numeric(18, 4);
  v_debits numeric(18, 4);
  v_due numeric(18, 4);
  v_child record;
  v_child_paid numeric(18, 4);
  v_child_written_off numeric(18, 4);
  v_child_cross numeric(18, 4);
  v_child_due numeric(18, 4);
  v_child_total numeric(18, 4);
  v_child_status text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM money_kernel.bills kb WHERE kb.id = p_global_invoice_id
  ) THEN
    RETURN;
  END IF;

  SELECT * INTO v_bill FROM money_kernel.bills WHERE id = p_global_invoice_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_root_id := coalesce(v_bill.parent_bill_id, v_bill.id);

  SELECT * INTO v_bill FROM money_kernel.bills WHERE id = v_root_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT coalesce(sum(bs.allocated_amount), 0) INTO v_paid
  FROM money_kernel.bill_settlements bs
  WHERE bs.bill_id = v_root_id
    AND bs.settlement_kind = 'pay';

  v_written_off := coalesce(v_bill.written_off_amount, 0);

  SELECT coalesce(sum(total_amount), 0) INTO v_credits
  FROM money_kernel.bills
  WHERE parent_bill_id = v_root_id
    AND kind = 'credit_note'
    AND status NOT IN ('draft', 'voided');

  SELECT coalesce(sum(total_amount), 0) INTO v_debits
  FROM money_kernel.bills
  WHERE parent_bill_id = v_root_id
    AND kind = 'debit_note'
    AND status NOT IN ('draft', 'voided');

  v_total := coalesce(v_bill.total_amount, 0);
  v_due := greatest(v_total - v_paid - v_written_off - v_credits + v_debits, 0);

  UPDATE money_kernel.bills
  SET
    paid_amount = v_paid,
    due_amount = v_due,
    status = CASE
      WHEN status = 'voided' THEN status
      ELSE money_kernel.derive_bill_status(v_total, v_paid, v_due, v_written_off)
    END,
    updated_at = now()
  WHERE id = v_root_id;

  FOR v_child IN
    SELECT id, kind, total_amount, status
    FROM money_kernel.bills
    WHERE parent_bill_id = v_root_id
    ORDER BY id
  LOOP
    SELECT coalesce(sum(bs.allocated_amount), 0) INTO v_child_paid
    FROM money_kernel.bill_settlements bs
    WHERE bs.bill_id = v_child.id
      AND bs.settlement_kind = 'pay';

    SELECT coalesce(b.written_off_amount, 0) INTO v_child_written_off
    FROM money_kernel.bills b
    WHERE b.id = v_child.id;

    v_child_total := coalesce(v_child.total_amount, 0);
    v_child_cross := 0;
    IF v_child.kind = 'credit_note' THEN
      SELECT coalesce(sum(bs.allocated_amount), 0) INTO v_child_cross
      FROM money_kernel.bill_settlements bs
      WHERE bs.settlement_kind = 'document'
        AND bs.source_bill_id = v_child.id;
    END IF;

    v_child_status := v_child.status;
    IF v_child_status IN ('draft', 'voided') THEN
      v_child_due := 0;
    ELSIF v_due = 0 AND (v_written_off > 0 OR v_paid > 0) THEN
      v_child_due := 0;
    ELSE
      v_child_due := greatest(
        v_child_total - v_child_paid - v_child_written_off - v_child_cross,
        0
      );
    END IF;

    UPDATE money_kernel.bills
    SET
      paid_amount = v_child_paid,
      written_off_amount = v_child_written_off,
      due_amount = v_child_due,
      status = CASE
        WHEN v_child_status = 'voided' THEN status
        WHEN v_child_total <= 0 THEN 'paid'
        ELSE money_kernel.derive_bill_status(
          v_child_total,
          v_child_paid,
          v_child_due,
          v_child_written_off
        )
      END,
      updated_at = now()
    WHERE id = v_child.id;
  END LOOP;
END;
$$;

-- post_vendor_credit_refund (kernel deposit + settlement)
CREATE OR REPLACE FUNCTION public.post_vendor_credit_refund(
  p_credit_note_id bigint,
  p_amount numeric,
  p_cashbook_point_id bigint,
  p_received_on date DEFAULT CURRENT_DATE,
  p_note text DEFAULT NULL,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_source_currency_code text DEFAULT NULL,
  p_transaction_rate numeric DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL
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
  v_location_id bigint;
  v_bundle_id bigint;
  v_pay money_kernel.pays;
  v_settle money_kernel.bill_settlements;
BEGIN
  IF p_credit_note_id IS NULL THEN
    RAISE EXCEPTION 'credit_note_id is required';
  END IF;
  IF p_cashbook_point_id IS NULL THEN
    RAISE EXCEPTION 'Choose a cash point for the refund';
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

  v_location_id := p_cashbook_point_id;
  IF NOT EXISTS (
    SELECT 1
    FROM money_kernel.cash_locations cp
    JOIN money_kernel.cashbooks ca ON ca.id = cp.cashbook_id
    WHERE cp.id = v_location_id
      AND cp.is_active = true
      AND ca.tenant_id = v_cn_k.tenant_id
      AND ca.profile_id = v_tenant_profile_id
  ) THEN
    RAISE EXCEPTION 'Invalid cash point for this tenant';
  END IF;

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
  bigint, numeric, bigint, date, text, text, numeric, numeric, text, numeric, bigint
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_vendor_credit_refund(
  bigint, numeric, bigint, date, text, text, numeric, numeric, text, numeric, bigint
) TO service_role;
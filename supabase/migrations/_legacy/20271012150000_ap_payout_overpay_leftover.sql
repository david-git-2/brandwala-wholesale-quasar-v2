-- Allow AP payout amount to exceed bill allocations; remainder stays on pays.unallocated_amount.

CREATE OR REPLACE FUNCTION public.post_ap_payout_with_allocations(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_paid_on date,
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_instruments jsonb DEFAULT '[]'::jsonb,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL
)
RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_parent_id bigint;
  v_received_on date := coalesce(p_paid_on, current_date);
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_reference text := nullif(trim(coalesce(p_reference, '')), '');
  v_pay public.pays;
  v_line record;
  v_method_code text;
  v_line_amount numeric(12, 2);
  v_line_count int := 0;
  v_amount numeric(12, 2) := 0.00;
  v_header_method text;
  v_alloc jsonb;
  v_bill public.bills;
  v_bill_id bigint;
  v_alloc_amount numeric(12, 2);
  v_total_alloc numeric(12, 2) := 0.00;
  v_settle_currency text := 'BDT';
  v_foreign_amt numeric(12, 2);
  v_fx_rate numeric(15, 6) := 1.000000;
  v_shipment_ids bigint[] := '{}';
  v_sid bigint;
  v_leftover numeric(12, 2);
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Tenant is required';
  END IF;
  IF p_profile_id IS NULL THEN
    RAISE EXCEPTION 'Profile is required';
  END IF;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  IF NOT (
    coalesce(auth.role(), '') = 'service_role'
    OR public.user_can_manage_parent_tenant(v_parent_id)
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'collect_payment')
    OR EXISTS (
      SELECT 1 FROM public.memberships m
      WHERE m.tenant_id = p_tenant_id
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
        AND m.role IN ('admin', 'staff')
    )
  ) THEN
    RAISE EXCEPTION 'Permission denied: cannot record AP payouts for this tenant';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles pr
    WHERE pr.id = p_profile_id AND pr.parent_tenant_id = v_parent_id
  ) THEN
    RAISE EXCEPTION 'Profile % does not belong to these books', p_profile_id;
  END IF;

  IF coalesce(jsonb_typeof(p_instruments), 'null') = 'array' THEN
    FOR v_line IN SELECT value FROM jsonb_array_elements(p_instruments)
    LOOP
      v_line_amount := round(coalesce((v_line.value ->> 'amount')::numeric, 0.00), 2);
      IF v_line_amount <= 0 THEN
        CONTINUE;
      END IF;
      v_method_code := upper(trim(coalesce(v_line.value ->> 'payment_method_code', '')));
      v_amount := v_amount + v_line_amount;
      v_line_count := v_line_count + 1;
      IF v_line_count = 1 THEN
        v_header_method := lower(v_method_code);
      ELSE
        v_header_method := 'split';
      END IF;
    END LOOP;
  END IF;

  IF v_line_count = 0 THEN
    RAISE EXCEPTION 'Enter at least one payment line';
  END IF;

  IF v_header_method IS NOT NULL AND v_header_method NOT IN (
    'cash', 'bank', 'bank_transfer', 'mobile_banking', 'bkash', 'nagad', 'other', 'cheque', 'rocket',
    'upay', 'tap', 'card_pos', 'wire_transfer', 'paypal', 'stripe', 'letter_of_credit', 'cod', 'split'
  ) THEN
    v_header_method := 'other';
  END IF;

  SELECT n.settlement_currency_code, n.foreign_amount, n.exchange_rate, n.amount_bdt
  INTO v_settle_currency, v_foreign_amt, v_fx_rate, v_amount
  FROM public.normalize_pay_settlement_fx(
    v_amount, p_settlement_currency_code, p_foreign_amount, p_exchange_rate
  ) n;

  INSERT INTO public.pays (
    tenant_id, profile_id, source, amount, unallocated_amount,
    payment_date, method, reference, note,
    settlement_currency_code, foreign_amount, exchange_rate
  ) VALUES (
    v_parent_id, p_profile_id, 'ap_payout', v_amount, 0,
    v_received_on, v_header_method, v_reference, v_note,
    v_settle_currency, v_foreign_amt, v_fx_rate
  ) RETURNING * INTO v_pay;

  PERFORM public.insert_global_payment_instruments(v_pay.id, p_instruments);

  IF coalesce(jsonb_typeof(p_allocations), 'null') = 'array' THEN
    FOR v_alloc IN SELECT value FROM jsonb_array_elements(p_allocations)
    LOOP
      v_bill_id := coalesce(nullif(v_alloc ->> 'bill_id', '')::bigint, nullif(v_alloc ->> 'invoice_id', '')::bigint);
      v_alloc_amount := round(coalesce((v_alloc ->> 'amount')::numeric, 0.00), 2);
      IF v_bill_id IS NULL OR v_alloc_amount <= 0 THEN
        CONTINUE;
      END IF;

      SELECT * INTO v_bill FROM public.bills WHERE id = v_bill_id FOR UPDATE;
      IF v_bill.id IS NULL THEN
        RAISE EXCEPTION 'Bill % not found', v_bill_id;
      END IF;
      IF v_bill.parent_tenant_id <> v_parent_id THEN
        RAISE EXCEPTION 'Bill % belongs to other books', v_bill_id;
      END IF;
      IF v_bill.invoice_type <> 'ap'::public.global_invoice_type THEN
        RAISE EXCEPTION 'Bill % is not AP', v_bill.invoice_no;
      END IF;
      IF v_bill.invoice_status <> 'issued'::public.global_invoice_status THEN
        RAISE EXCEPTION 'Bill % is not issued', v_bill.invoice_no;
      END IF;
      IF v_bill.profile_id IS DISTINCT FROM p_profile_id THEN
        RAISE EXCEPTION 'Bill % is billed to a different profile', v_bill.invoice_no;
      END IF;
      IF v_alloc_amount > coalesce(v_bill.due_amount, 0.00) THEN
        RAISE EXCEPTION 'Allocation % exceeds bill % due %', v_alloc_amount, v_bill.invoice_no, v_bill.due_amount;
      END IF;

      INSERT INTO public.pay_allocations (tenant_id, payment_id, global_invoice_id, amount)
      VALUES (v_parent_id, v_pay.id, v_bill_id, v_alloc_amount);

      PERFORM public.recompute_global_invoice_payment_status(v_bill_id);
      v_total_alloc := v_total_alloc + v_alloc_amount;

      IF v_bill.ap_shipment_id IS NOT NULL
         AND NOT (v_bill.ap_shipment_id = ANY(v_shipment_ids)) THEN
        v_shipment_ids := array_append(v_shipment_ids, v_bill.ap_shipment_id);
      END IF;
    END LOOP;
  END IF;

  IF v_total_alloc > v_amount THEN
    RAISE EXCEPTION 'AP payout allocations (%) exceed payment amount (%)', v_total_alloc, v_amount;
  END IF;

  v_leftover := v_amount - v_total_alloc;

  UPDATE public.pays
  SET unallocated_amount = v_leftover
  WHERE id = v_pay.id
  RETURNING * INTO v_pay;

  PERFORM public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_parent_id,
    p_type => 'debit',
    p_amount => v_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_pay.id::text,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'ap_payout',
      'transaction_type', 'ap_paid_out',
      'label', 'AP paid out',
      'payment_id', v_pay.id,
      'method', v_header_method,
      'reference', v_reference,
      'settlement_currency_code', v_settle_currency,
      'foreign_amount', v_foreign_amt,
      'exchange_rate', v_fx_rate
    )
  );

  IF coalesce(array_length(v_shipment_ids, 1), 0) > 0 THEN
    FOREACH v_sid IN ARRAY v_shipment_ids
    LOOP
      PERFORM public.refresh_global_shipment_fx_from_ap_payments(v_sid);
    END LOOP;
  END IF;

  RETURN v_pay;
END;
$$;

-- Temporary: allow owner withdraw when tenant custody balance is negative (books drift).

CREATE OR REPLACE FUNCTION public._kernel_post_owner_withdraw(
  p_tenant_id bigint,
  p_paid_on date,
  p_amount numeric,
  p_cashbook_point_id bigint,
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_pay public.pays;
  v_existing public.pays;
BEGIN
  IF NOT (
    public.cashbook_staff_can_view(p_tenant_id)
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'create')
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;
  PERFORM public._kernel_assert_purpose('owner_withdraw', NULL, NULL)::public.money_purposes;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'amount must be positive';
  END IF;
  IF p_cashbook_point_id IS NULL THEN
    RAISE EXCEPTION 'cashbook_point_id required';
  END IF;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);

  IF p_idempotency_key IS NOT NULL AND btrim(p_idempotency_key) <> '' THEN
    SELECT * INTO v_existing
    FROM public.pays
    WHERE tenant_id = v_books_id AND idempotency_key = p_idempotency_key;
    IF v_existing.id IS NOT NULL THEN
      RETURN v_existing;
    END IF;
  END IF;

  PERFORM public._kernel_lock_cashbook_point_pots(p_cashbook_point_id);

  INSERT INTO public.pays (
    tenant_id, profile_id, source, purpose_code, amount, unallocated_amount,
    payment_date, method, reference, note, cashbook_point_id, idempotency_key
  ) VALUES (
    v_books_id, NULL, 'owner_withdraw', 'owner_withdraw', p_amount, 0,
    coalesce(p_paid_on, current_date), 'cash', p_reference, p_note,
    p_cashbook_point_id, p_idempotency_key
  ) RETURNING * INTO v_pay;

  PERFORM public.record_ledger_transaction(
    p_tenant_id => v_books_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_books_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1,
    p_source_type => 'pay',
    p_source_id => v_pay.id::text,
    p_metadata => jsonb_build_object('purpose', 'owner_withdraw'),
    p_target_bucket => 'available',
    p_allow_overdraft => true,
    p_cashbook_point_id => p_cashbook_point_id
  );

  RETURN v_pay;
END;
$$;

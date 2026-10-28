-- BP25: duplicate idempotency_key returns same pay (smoke; run as superuser/service on local)

DO $$
DECLARE
  v_parent bigint;
  v_profile bigint;
  v_key text := 'bp25-smoke-' || gen_random_uuid()::text;
  v_pay1 public.pays;
  v_pay2 public.pays;
  v_ledger_count int;
BEGIN
  SELECT t.id INTO v_parent FROM public.tenants t WHERE t.parent_tenant_id IS NULL ORDER BY t.id LIMIT 1;
  IF v_parent IS NULL THEN
    RAISE NOTICE 'skip bp25 smoke: no parent tenant';
    RETURN;
  END IF;

  SELECT p.id INTO v_profile
  FROM public.profiles p
  WHERE p.parent_tenant_id = v_parent
  ORDER BY p.id
  LIMIT 1;

  IF v_profile IS NULL THEN
    RAISE NOTICE 'skip bp25 smoke: no profile';
    RETURN;
  END IF;

  v_pay1 := public.post_money_in(
    v_parent,
    v_profile,
    current_date,
    null,
    null,
    'customer_cash',
    jsonb_build_array(jsonb_build_object('payment_method_code', 'CASH', 'amount', 1.00)),
    '[]'::jsonb,
    null,
    'BDT',
    null,
    null,
    v_key
  );

  v_pay2 := public.post_money_in(
    v_parent,
    v_profile,
    current_date,
    null,
    null,
    'customer_cash',
    jsonb_build_array(jsonb_build_object('payment_method_code', 'CASH', 'amount', 1.00)),
    '[]'::jsonb,
    null,
    'BDT',
    null,
    null,
    v_key
  );

  IF v_pay1.id IS DISTINCT FROM v_pay2.id THEN
    RAISE EXCEPTION 'BP25 failed: expected same pays.id, got % and %', v_pay1.id, v_pay2.id;
  END IF;

  SELECT count(*) INTO v_ledger_count
  FROM public.cashbook_entries ce
  WHERE ce.source_type = 'payout'
    AND ce.source_id = v_pay1.id::text;

  -- customer collect uses credit ledger source sales_invoice / customer — count tenant credit lines for payment_id in metadata
  SELECT count(*) INTO v_ledger_count
  FROM public.cashbook_entries ce
  WHERE (ce.metadata->>'payment_id')::bigint = v_pay1.id;

  IF v_ledger_count > 1 THEN
    RAISE EXCEPTION 'BP25 failed: expected one ledger movement for pay %, found %', v_pay1.id, v_ledger_count;
  END IF;

  RAISE NOTICE 'BP25 smoke ok pay_id=%', v_pay1.id;
END;
$$;

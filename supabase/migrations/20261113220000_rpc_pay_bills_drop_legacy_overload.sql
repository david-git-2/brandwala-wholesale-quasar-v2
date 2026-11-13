-- Drop legacy 8-arg rpc_pay_bills (PGRST203); single signature with p_bundle_debits; books_rate from from-bundle.

DROP FUNCTION IF EXISTS public.rpc_pay_bills(
  bigint, bigint, bigint, numeric, jsonb, bigint, jsonb, text
);
DROP FUNCTION IF EXISTS public.rpc_pay_bills(
  bigint, bigint, bigint, numeric, jsonb, bigint, jsonb, jsonb, text
);

CREATE OR REPLACE FUNCTION public.rpc_pay_bills(
  p_tenant_id        bigint,
  p_payer_profile_id bigint,
  p_from_pot_id      bigint,
  p_amount           numeric,
  p_allocations      jsonb,
  p_to_pot_id        bigint DEFAULT NULL,
  p_bundle_debits    jsonb DEFAULT NULL,
  p_meta             jsonb DEFAULT '{}'::jsonb,
  p_idempotency_key  text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
v_pays money_kernel.pays;
  v_from_lot money_kernel.cash_bundles;
  v_to_lot money_kernel.cash_bundles;
  v_to_lot_id  bigint;
  v_books      numeric(18,4);
  v_bill_ids   bigint[];
  v_bill_id    bigint;
  v_alloc_amt  numeric(18,4);
  v_alloc      jsonb;
  v_bill money_kernel.bills;
  v_settlements jsonb := '[]'::jsonb;
  v_settlement money_kernel.bill_settlements;
  v_sum_alloc  numeric(18,4);
  v_settle_books numeric(18,4);
  v_books_left numeric(18,4);
  v_line_books numeric(18,4);
  v_alloc_n    int;
  v_alloc_i    int;
  v_err        text;
BEGIN

  v_exchange_rate := 1;
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  SELECT coalesce(nullif(cb.books_rate, 0), 1::numeric(15, 6)) INTO v_books_rate
    FROM money_kernel.cash_bundles cb
   WHERE cb.id = p_from_pot_id AND cb.tenant_id = p_tenant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: from bundle %', p_from_pot_id;
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount: must be > 0';
  END IF;
  IF p_allocations IS NULL OR jsonb_typeof(p_allocations) <> 'array'
     OR jsonb_array_length(p_allocations) = 0 THEN
    RAISE EXCEPTION 'invalid_arguments: p_allocations must be a non-empty array';
  END IF;
  IF (
    SELECT count(*) <> count(DISTINCT (a->>'bill_id')::bigint)
      FROM jsonb_array_elements(p_allocations) a
  ) THEN
    RAISE EXCEPTION 'invalid_arguments: duplicate bill_id in p_allocations';
  END IF;

  -- [SHIP] Derive to_pot from bill.to_profile_id + currency (Option C / I30–I32).
  -- If p_to_pot_id passed, must equal derived pot for every bill in p_allocations.
  -- Reject mixed payees; reject from_pot = to_pot.
  -- Body below still shows legacy tenant-default path until rewritten.
  IF p_to_pot_id IS NOT NULL THEN
    v_to_lot_id := p_to_pot_id;
  ELSE
    SELECT default_cash_bundle_id INTO v_to_lot_id
      FROM money_kernel.cashbooks
     WHERE tenant_id = p_tenant_id AND profile_id IN (SELECT id FROM public.profiles WHERE tenant_id = p_tenant_id AND profile_type = 'tenant' LIMIT 1);
    IF v_to_lot_id IS NULL THEN
      RAISE EXCEPTION 'not_found: payee pot; provision payee cashbook';
    END IF;
  END IF;

  -- Idempotency before locks
  -- [CORRECTED: was kind+amount only → also pots, books_rate, allocations]
  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_pays FROM money_kernel.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF FOUND THEN
      IF v_pays.kind <> 'payment'
         OR v_pays.amount <> p_amount
         OR v_pays.from_cash_bundle_id IS DISTINCT FROM p_from_pot_id
         OR v_pays.to_cash_bundle_id IS DISTINCT FROM v_to_lot_id
         OR v_pays.books_amount <> round(p_amount * v_books_rate, 4)
         OR COALESCE(v_pays.refs->'allocations', 'null'::jsonb)
            IS DISTINCT FROM COALESCE(p_allocations, 'null'::jsonb)
      THEN
        RAISE EXCEPTION 'idempotency_conflict: key % used for different parameters', p_idempotency_key;
      END IF;
      RETURN jsonb_build_object(
        'pays_id', v_pays.id, 'amount', v_pays.amount, 'status', v_pays.status,
        'idempotent', true
      );
    END IF;
  END IF;

  SELECT COALESCE(array_agg(x ORDER BY x), '{}') INTO v_bill_ids
    FROM (
      SELECT DISTINCT (a->>'bill_id')::bigint AS x
        FROM jsonb_array_elements(p_allocations) a
    ) s;

  -- One lock statement for all bills (ascending id)
  PERFORM 1 FROM money_kernel.bills
   WHERE tenant_id = p_tenant_id AND id = ANY(v_bill_ids)
   ORDER BY id
   FOR UPDATE;

  -- Lock + read pots in id order (no second SELECT)
  IF p_from_pot_id < v_to_lot_id THEN
    SELECT * INTO v_from_lot FROM money_kernel.cash_bundles WHERE id = p_from_pot_id FOR UPDATE;
    SELECT * INTO v_to_lot   FROM money_kernel.cash_bundles WHERE id = v_to_lot_id   FOR UPDATE;
  ELSE
    SELECT * INTO v_to_lot   FROM money_kernel.cash_bundles WHERE id = v_to_lot_id   FOR UPDATE;
    SELECT * INTO v_from_lot FROM money_kernel.cash_bundles WHERE id = p_from_pot_id FOR UPDATE;
  END IF;
  IF v_from_lot.id IS NULL OR v_to_lot.id IS NULL THEN
    RAISE EXCEPTION 'not_found: pot';
  END IF;
  IF v_from_lot.tenant_id <> p_tenant_id OR v_to_lot.tenant_id <> p_tenant_id THEN
    RAISE EXCEPTION 'invalid_arguments: pots must belong to tenant %', p_tenant_id;
  END IF;

  v_books_rate := coalesce(nullif(v_from_lot.books_rate, 0), 1::numeric(15, 6));

  PERFORM public.money_kernel_assert_profile_in_tenant(p_tenant_id, p_payer_profile_id);

  PERFORM 1 FROM money_kernel.cash_bundles pp
    JOIN money_kernel.cash_locations pt ON pt.id = pp.cash_location_id
    JOIN money_kernel.cashbooks a ON a.id = pt.cashbook_id
   WHERE pp.id = p_from_pot_id AND a.profile_id IS NOT NULL
     AND a.entity_id = p_payer_profile_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: from_lot % does not belong to profile %', p_from_pot_id, p_payer_profile_id;
  END IF;

  IF v_from_lot.amount < p_amount THEN
    RAISE EXCEPTION 'insufficient_balance: pot % has %, payment is %',
      p_from_pot_id, v_from_lot.amount, p_amount;
  END IF;

  -- Set-based allocation validation (one join pass; first failure wins)
  SELECT x.err INTO v_err
    FROM (
      SELECT
        (a.elem->>'bill_id')::bigint AS bill_id,
        round((a.elem->>'amount')::numeric, 2) AS alloc_amt,
        CASE
          WHEN round((a.elem->>'amount')::numeric, 2) IS NULL
            OR round((a.elem->>'amount')::numeric, 2) <= 0
            THEN 'invalid_amount: each allocation amount must be > 0'
          WHEN b.id IS NULL
            THEN format('not_found: bill %s', a.elem->>'bill_id')
          WHEN b.kind = 'credit_note' OR COALESCE(r.can_be_paid, true) = false
            THEN format(
              'invalid_arguments: bill %s kind %s cannot be cash-paid; use rpc_apply_document_settlement',
              b.id, b.kind)
          WHEN b.status IN ('draft','voided')
            THEN format('invalid_state: cannot pay bill %s status %s', b.id, b.status)
          WHEN b.from_profile_id IS NULL OR b.from_profile_id <> p_payer_profile_id
            THEN format(
              'invalid_arguments: payer_profile %s must equal bill.from_profile_id %s',
              p_payer_profile_id, b.from_profile_id)
          WHEN b.currency_code <> v_from_lot.currency_code
            OR b.currency_code <> v_to_lot.currency_code
            THEN format('invalid_arguments: pots and bill %s must share currency (I7b)', b.id)
          WHEN round((a.elem->>'amount')::numeric, 2) > b.due_amount
            THEN format(
              'invalid_amount: allocation %s exceeds bill %s due %s',
              round((a.elem->>'amount')::numeric, 2), b.id, b.due_amount)
          ELSE NULL
        END AS err
      FROM jsonb_array_elements(p_allocations) WITH ORDINALITY AS a(elem, ord)
      LEFT JOIN money_kernel.bills b
        ON b.id = (a.elem->>'bill_id')::bigint AND b.tenant_id = p_tenant_id
      LEFT JOIN money_kernel.bill_kind_registry r ON r.kind = b.kind
      ORDER BY a.ord
    ) x
   WHERE x.err IS NOT NULL
   LIMIT 1;
  IF v_err IS NOT NULL THEN
    RAISE EXCEPTION '%', v_err;
  END IF;

  SELECT COALESCE(SUM(round((a->>'amount')::numeric, 2)), 0) INTO v_sum_alloc
    FROM jsonb_array_elements(p_allocations) a;
  IF v_sum_alloc > round(p_amount, 2) THEN
    RAISE EXCEPTION 'invalid_amount: sum(allocations) % exceeds pays amount %',
      v_sum_alloc, p_amount;
  END IF;

  v_books := round(p_amount * v_books_rate, 4);
  -- Books for settlements cover allocated cash only; unapplied cash leaves books on pays
  v_settle_books := round(v_sum_alloc * v_books_rate, 4);
  v_books_left := v_settle_books;
  v_alloc_n := jsonb_array_length(p_allocations);

  BEGIN
    INSERT INTO money_kernel.pays (
      tenant_id, kind, from_cash_bundle_id, to_cash_bundle_id,
      amount, currency_code, books_amount, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'payment', p_from_pot_id, v_to_lot_id,
      p_amount, v_from_lot.currency_code, v_books, 1,
      CURRENT_DATE, 'posted', p_idempotency_key,
      jsonb_build_object('allocations', p_allocations),
      COALESCE(p_meta, '{}'::jsonb), auth.uid()
    ) RETURNING * INTO v_pays;
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_pays FROM money_kernel.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF NOT FOUND THEN RAISE; END IF;
    -- [CORRECTED: same full param match as pre-lock path]
    IF v_pays.kind <> 'payment'
       OR v_pays.amount <> p_amount
       OR v_pays.from_cash_bundle_id IS DISTINCT FROM p_from_pot_id
       OR v_pays.to_cash_bundle_id IS DISTINCT FROM v_to_lot_id
       OR v_pays.books_amount <> round(p_amount * v_books_rate, 4)
       OR COALESCE(v_pays.refs->'allocations', 'null'::jsonb)
          IS DISTINCT FROM COALESCE(p_allocations, 'null'::jsonb)
    THEN
      RAISE EXCEPTION 'idempotency_conflict: key % used for different parameters', p_idempotency_key;
    END IF;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'amount', v_pays.amount, 'status', v_pays.status,
      'idempotent', true
    );
  END;

  IF p_bundle_debits IS NOT NULL AND jsonb_array_length(p_bundle_debits) > 0 THEN
    PERFORM money_kernel.fn_apply_pay_bundle_debits(p_tenant_id, v_pays.id, p_bundle_debits, v_books_rate);
  END IF;
  PERFORM money_kernel.fn_ensure_header_pay_bundle_lines(p_tenant_id, v_pays.id);

  v_alloc_i := 0;
  FOR v_alloc IN SELECT * FROM jsonb_array_elements(p_allocations) LOOP
    v_alloc_i := v_alloc_i + 1;
    v_bill_id := (v_alloc->>'bill_id')::bigint;
    v_alloc_amt := round((v_alloc->>'amount')::numeric, 2);
    IF v_alloc_i = v_alloc_n THEN
      v_line_books := v_books_left;  -- absorb rounding residue
    ELSE
      v_line_books := round(v_alloc_amt * v_books_rate, 4);
      v_books_left := v_books_left - v_line_books;
    END IF;
    INSERT INTO money_kernel.bill_settlements (
      tenant_id, bill_id, settlement_kind, pays_id, source_bill_id,
      allocated_amount, allocated_books_amount
    ) VALUES (
      p_tenant_id, v_bill_id, 'pay', v_pays.id, NULL,
      v_alloc_amt, v_line_books
    ) RETURNING * INTO v_settlement;
    v_settlements := v_settlements || jsonb_build_object(
      'settlement_id', v_settlement.id,
      'bill_id', v_bill_id,
      'allocated_amount', v_alloc_amt
    );
  END LOOP;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'amount', p_amount, 'books_amount', v_books,
    'from_cash_bundle_id', p_from_pot_id, 'to_cash_bundle_id', v_to_lot_id,
    'settlements', v_settlements, 'status', 'posted', 'idempotent', false
  );
END;
$$;

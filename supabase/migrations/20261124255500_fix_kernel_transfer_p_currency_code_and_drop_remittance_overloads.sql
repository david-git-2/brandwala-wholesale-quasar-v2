-- Fix nonexistent p_currency_code references in kernel RPCs, flush deferred transfer pays,
-- and drop redundant legacy record_dropship_courier_remittance overloads.

CREATE OR REPLACE FUNCTION public.rpc_transfer_same_profile(
  p_tenant_id       bigint,
  p_from_pot_id     bigint,
  p_to_pot_id       bigint,
  p_amount          numeric,
  p_meta            jsonb   DEFAULT '{}'::jsonb,
  p_idempotency_key text    DEFAULT NULL
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
  v_from_bal     numeric(18,4);
  v_to_bal       numeric(18,4);
  v_to_amount    numeric(18,4);
  v_books        numeric(18,4);
  v_from_profile bigint;
  v_to_profile   bigint;
BEGIN
  v_exchange_rate := money_kernel.fn_resolve_transfer_rate(
    (SELECT currency_code FROM money_kernel.cash_bundles WHERE id = p_from_pot_id),
    (SELECT currency_code FROM money_kernel.cash_bundles WHERE id = p_to_pot_id),
    p_tenant_id);
  v_books_rate := money_kernel.fn_resolve_books_rate(
    p_tenant_id,
    COALESCE((SELECT currency_code FROM money_kernel.cash_bundles WHERE id = p_from_pot_id), 'BDT')
  );
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'withdraw');

  IF p_amount <= 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  IF v_exchange_rate <= 0 THEN RAISE EXCEPTION 'invalid_rate: exchange_rate'; END IF;
  IF v_books_rate <= 0 THEN RAISE EXCEPTION 'invalid_rate: books_rate'; END IF;
  IF p_from_pot_id = p_to_pot_id THEN
    RAISE EXCEPTION 'invalid_arguments: from_cash_bundle_id and to_cash_bundle_id must differ';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_pays FROM money_kernel.pays
      WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF FOUND THEN
      SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = v_pays.from_cash_bundle_id;
      SELECT amount INTO v_to_bal   FROM money_kernel.cash_bundles WHERE id = v_pays.to_cash_bundle_id;
      RETURN jsonb_build_object(
        'pays_id', v_pays.id, 'kind', 'transfer',
        'from_cash_bundle_id', v_pays.from_cash_bundle_id, 'to_cash_bundle_id', v_pays.to_cash_bundle_id,
        'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
        'to_amount', round(v_pays.amount * v_pays.exchange_rate, 4),
        'books_amount', v_pays.books_amount, 'exchange_rate', v_pays.exchange_rate,
        'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
        'status', v_pays.status, 'idempotent', true
      );
    END IF;
  END IF;

  IF p_from_pot_id < p_to_pot_id THEN
    SELECT * INTO v_from_lot FROM money_kernel.cash_bundles WHERE id = p_from_pot_id FOR UPDATE;
    SELECT * INTO v_to_lot   FROM money_kernel.cash_bundles WHERE id = p_to_pot_id   FOR UPDATE;
  ELSE
    SELECT * INTO v_to_lot   FROM money_kernel.cash_bundles WHERE id = p_to_pot_id   FOR UPDATE;
    SELECT * INTO v_from_lot FROM money_kernel.cash_bundles WHERE id = p_from_pot_id FOR UPDATE;
  END IF;

  IF v_from_lot.id IS NULL THEN
    RAISE EXCEPTION 'not_found: from_lot %', p_from_pot_id;
  END IF;
  IF v_to_lot.id IS NULL THEN
    RAISE EXCEPTION 'not_found: to_lot %', p_to_pot_id;
  END IF;
  IF v_from_lot.tenant_id <> p_tenant_id OR v_to_lot.tenant_id <> p_tenant_id THEN
    RAISE EXCEPTION 'invalid_arguments: both pots must belong to tenant %', p_tenant_id;
  END IF;

  SELECT a.profile_id INTO v_from_profile
    FROM money_kernel.cash_locations pt
    JOIN money_kernel.cashbooks a ON a.id = pt.cashbook_id
   WHERE pt.id = v_from_lot.cash_location_id AND a.profile_id IS NOT NULL;
  SELECT a.profile_id INTO v_to_profile
    FROM money_kernel.cash_locations pt
    JOIN money_kernel.cashbooks a ON a.id = pt.cashbook_id
   WHERE pt.id = v_to_lot.cash_location_id AND a.profile_id IS NOT NULL;

  IF v_from_profile IS NULL OR v_to_profile IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: both pots must belong to a profile';
  END IF;
  IF v_from_profile <> v_to_profile THEN
    RAISE EXCEPTION
      'invalid_arguments: pots belong to different profiles (% vs %); use rpc_transfer_p2p',
      v_from_profile, v_to_profile;
  END IF;

  IF v_from_lot.currency_code = v_to_lot.currency_code AND v_exchange_rate <> 1 THEN
    RAISE EXCEPTION
      'invalid_rate: exchange_rate must be 1 for same-currency transfer';
  END IF;

  IF v_from_lot.amount < p_amount THEN
    RAISE EXCEPTION
      'insufficient_balance: pot % has %, transfer is %',
      p_from_pot_id, v_from_lot.amount, p_amount;
  END IF;

  v_to_amount := round(p_amount * v_exchange_rate, 4);
  v_books     := round(p_amount * v_books_rate, 4);

  BEGIN
    INSERT INTO money_kernel.pays (
      tenant_id, kind, from_cash_bundle_id, to_cash_bundle_id,
      amount, currency_code, books_amount, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'transfer', p_from_pot_id, p_to_pot_id,
      p_amount, v_from_lot.currency_code, v_books, v_exchange_rate,
      CURRENT_DATE, 'posted', p_idempotency_key, '{}'::jsonb, p_meta, auth.uid()
    ) RETURNING * INTO v_pays;
    PERFORM money_kernel.fn_ensure_header_pay_bundle_lines(p_tenant_id, v_pays.id);
    PERFORM money_kernel.flush_deferred_pays();
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_pays FROM money_kernel.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF NOT FOUND THEN RAISE; END IF;
    IF v_pays.kind <> 'transfer' OR v_pays.amount <> p_amount
       OR v_pays.from_cash_bundle_id IS DISTINCT FROM p_from_pot_id
       OR v_pays.to_cash_bundle_id IS DISTINCT FROM p_to_pot_id THEN
      RAISE EXCEPTION
        'idempotency_conflict: key % used for different parameters', p_idempotency_key;
    END IF;
    SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = v_pays.from_cash_bundle_id;
    SELECT amount INTO v_to_bal   FROM money_kernel.cash_bundles WHERE id = v_pays.to_cash_bundle_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'kind', 'transfer',
      'from_cash_bundle_id', v_pays.from_cash_bundle_id, 'to_cash_bundle_id', v_pays.to_cash_bundle_id,
      'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
      'to_amount', round(v_pays.amount * v_pays.exchange_rate, 4),
      'books_amount', v_pays.books_amount, 'exchange_rate', v_pays.exchange_rate,
      'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
      'status', v_pays.status, 'idempotent', true
    );
  END;

  SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = p_from_pot_id;
  SELECT amount INTO v_to_bal   FROM money_kernel.cash_bundles WHERE id = p_to_pot_id;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'kind', 'transfer',
    'from_cash_bundle_id', p_from_pot_id, 'to_cash_bundle_id', p_to_pot_id,
    'amount', p_amount, 'currency_code', v_from_lot.currency_code,
    'to_amount', v_to_amount, 'to_currency_code', v_to_lot.currency_code,
    'books_amount', v_books, 'exchange_rate', v_exchange_rate,
    'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
    'status', v_pays.status, 'idempotent', false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_transfer_p2p(
  p_tenant_id       bigint,
  p_from_pot_id     bigint,
  p_to_pot_id       bigint,
  p_amount          numeric,
  p_meta            jsonb   DEFAULT '{}'::jsonb,
  p_idempotency_key text    DEFAULT NULL
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
  v_from_bal numeric(18,4);
  v_to_bal   numeric(18,4);
  v_to_amount numeric(18,4);
  v_books    numeric(18,4);
BEGIN
  v_exchange_rate := money_kernel.fn_resolve_transfer_rate(
    (SELECT currency_code FROM money_kernel.cash_bundles WHERE id = p_from_pot_id),
    (SELECT currency_code FROM money_kernel.cash_bundles WHERE id = p_to_pot_id),
    p_tenant_id);
  v_books_rate := money_kernel.fn_resolve_books_rate(
    p_tenant_id,
    COALESCE((SELECT currency_code FROM money_kernel.cash_bundles WHERE id = p_from_pot_id), 'BDT')
  );
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'withdraw');

  IF p_amount <= 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  IF v_exchange_rate <= 0 THEN RAISE EXCEPTION 'invalid_rate: exchange_rate'; END IF;
  IF v_books_rate <= 0 THEN RAISE EXCEPTION 'invalid_rate: books_rate'; END IF;
  IF p_from_pot_id = p_to_pot_id THEN
    RAISE EXCEPTION 'invalid_arguments: from_cash_bundle_id and to_cash_bundle_id must differ';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_pays FROM money_kernel.pays
      WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF FOUND THEN
      SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = v_pays.from_cash_bundle_id;
      SELECT amount INTO v_to_bal   FROM money_kernel.cash_bundles WHERE id = v_pays.to_cash_bundle_id;
      RETURN jsonb_build_object(
        'pays_id', v_pays.id, 'kind', 'transfer',
        'from_cash_bundle_id', v_pays.from_cash_bundle_id, 'to_cash_bundle_id', v_pays.to_cash_bundle_id,
        'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
        'to_amount', round(v_pays.amount * v_pays.exchange_rate, 4),
        'books_amount', v_pays.books_amount,
        'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
        'status', v_pays.status, 'idempotent', true
      );
    END IF;
  END IF;

  IF p_from_pot_id < p_to_pot_id THEN
    SELECT * INTO v_from_lot FROM money_kernel.cash_bundles WHERE id = p_from_pot_id FOR UPDATE;
    SELECT * INTO v_to_lot   FROM money_kernel.cash_bundles WHERE id = p_to_pot_id   FOR UPDATE;
  ELSE
    SELECT * INTO v_to_lot   FROM money_kernel.cash_bundles WHERE id = p_to_pot_id   FOR UPDATE;
    SELECT * INTO v_from_lot FROM money_kernel.cash_bundles WHERE id = p_from_pot_id FOR UPDATE;
  END IF;

  IF v_from_lot.id IS NULL THEN RAISE EXCEPTION 'not_found: from_lot %', p_from_pot_id; END IF;
  IF v_to_lot.id IS NULL   THEN RAISE EXCEPTION 'not_found: to_lot %', p_to_pot_id;     END IF;
  IF v_from_lot.tenant_id <> p_tenant_id OR v_to_lot.tenant_id <> p_tenant_id THEN
    RAISE EXCEPTION 'invalid_arguments: both pots must belong to tenant %', p_tenant_id;
  END IF;

  IF v_from_lot.currency_code = v_to_lot.currency_code AND v_exchange_rate <> 1 THEN
    RAISE EXCEPTION 'invalid_rate: exchange_rate must be 1 for same-currency transfer';
  END IF;

  IF v_from_lot.amount < p_amount THEN
    RAISE EXCEPTION
      'insufficient_balance: pot % has %, transfer is %',
      p_from_pot_id, v_from_lot.amount, p_amount;
  END IF;

  v_to_amount := round(p_amount * v_exchange_rate, 4);
  v_books     := round(p_amount * v_books_rate, 4);

  BEGIN
    INSERT INTO money_kernel.pays (
      tenant_id, kind, from_cash_bundle_id, to_cash_bundle_id,
      amount, currency_code, books_amount, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'transfer', p_from_pot_id, p_to_pot_id,
      p_amount, v_from_lot.currency_code, v_books, v_exchange_rate,
      CURRENT_DATE, 'posted', p_idempotency_key, '{}'::jsonb, p_meta, auth.uid()
    ) RETURNING * INTO v_pays;
    PERFORM money_kernel.fn_ensure_header_pay_bundle_lines(p_tenant_id, v_pays.id);
    PERFORM money_kernel.flush_deferred_pays();
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_pays FROM money_kernel.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF NOT FOUND THEN RAISE; END IF;
    IF v_pays.kind <> 'transfer' OR v_pays.amount <> p_amount
       OR v_pays.from_cash_bundle_id IS DISTINCT FROM p_from_pot_id
       OR v_pays.to_cash_bundle_id IS DISTINCT FROM p_to_pot_id THEN
      RAISE EXCEPTION
        'idempotency_conflict: key % used for different parameters', p_idempotency_key;
    END IF;
    SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = v_pays.from_cash_bundle_id;
    SELECT amount INTO v_to_bal   FROM money_kernel.cash_bundles WHERE id = v_pays.to_cash_bundle_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'kind', 'transfer',
      'from_cash_bundle_id', v_pays.from_cash_bundle_id, 'to_cash_bundle_id', v_pays.to_cash_bundle_id,
      'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
      'to_amount', round(v_pays.amount * v_pays.exchange_rate, 4),
      'books_amount', v_pays.books_amount,
      'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
      'status', v_pays.status, 'idempotent', true
    );
  END;

  SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = p_from_pot_id;
  SELECT amount INTO v_to_bal   FROM money_kernel.cash_bundles WHERE id = p_to_pot_id;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'kind', 'transfer',
    'from_cash_bundle_id', p_from_pot_id, 'to_cash_bundle_id', p_to_pot_id,
    'amount', p_amount, 'currency_code', v_from_lot.currency_code,
    'to_amount', v_to_amount, 'to_currency_code', v_to_lot.currency_code,
    'books_amount', v_books, 'exchange_rate', v_exchange_rate,
    'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
    'status', v_pays.status, 'idempotent', false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_pay_bill(
  p_tenant_id        bigint,
  p_bill_id          bigint,
  p_payer_profile_id bigint,
  p_from_pot_id      bigint,
  p_amount           numeric,
  p_to_pot_id        bigint  DEFAULT NULL,
  p_meta             jsonb   DEFAULT '{}'::jsonb,
  p_idempotency_key  text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_exchange_rate numeric(15,6);
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);
  v_exchange_rate := 1;

  IF v_exchange_rate IS DISTINCT FROM 1 THEN
    RAISE EXCEPTION 'invalid_rate: exchange_rate must be 1 for kind=payment (I7b)';
  END IF;
  RETURN public.rpc_pay_bills(
    p_tenant_id,
    p_payer_profile_id,
    p_from_pot_id,
    p_amount,
    jsonb_build_array(jsonb_build_object('bill_id', p_bill_id, 'amount', p_amount)),
    p_to_pot_id,
    NULL,
    p_meta,
    p_idempotency_key
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_update_pays(
  p_tenant_id        bigint,
  p_pays_id          bigint,
  p_kind             text,
  p_from_pot_id      bigint,
  p_to_pot_id        bigint,
  p_amount           numeric,
  p_bill_id          bigint  DEFAULT NULL,
  p_meta             jsonb   DEFAULT '{}'::jsonb,
  p_refs             jsonb   DEFAULT '{}'::jsonb,
  p_idempotency_key  text    DEFAULT NULL,
  p_reason           text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
  v_old       pays;
  v_new       pays;
  v_bill      money_kernel.bills;
  v_from_lot  money_kernel.cash_bundles;
  v_to_lot    money_kernel.cash_bundles;
  v_settle    bill_settlements;
  v_from_bal  numeric(18,4);
  v_to_bal    numeric(18,4);
  v_to_amt    numeric(18,4);
  v_alloc     numeric(12,2);
  v_books     numeric(18,4);
  v_lot_ids   bigint[];
  v_bill_ids  bigint[];
  v_new_refs  jsonb;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_new FROM money_kernel.pays
      WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
        AND status = 'posted';
    IF FOUND THEN
      IF (v_new.refs->>'replaces_pays_id')::bigint = p_pays_id THEN
        SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = v_new.from_cash_bundle_id;
        SELECT amount INTO v_to_bal   FROM money_kernel.cash_bundles WHERE id = v_new.to_cash_bundle_id;
        RETURN jsonb_build_object(
          'voided_pays_id', p_pays_id, 'new_pays_id', v_new.id,
          'kind', v_new.kind, 'amount', v_new.amount, 'status', v_new.status,
          'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
          'idempotent', true
        );
      ELSE
        RAISE EXCEPTION
          'idempotency_conflict: key % already used by pays %', p_idempotency_key, v_new.id;
      END IF;
    END IF;
  END IF;

  SELECT * INTO v_old FROM money_kernel.pays
    WHERE id = p_pays_id AND tenant_id = p_tenant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: pays %', p_pays_id;
  END IF;
  IF v_old.status = 'voided' THEN
    RAISE EXCEPTION 'invalid_state: pays % already voided', p_pays_id;
  END IF;

  v_books_rate := COALESCE(
    NULLIF(v_old.books_rate, 0),
    money_kernel.fn_resolve_books_rate(p_tenant_id, COALESCE(v_old.currency_code, 'BDT'))
  );
  v_exchange_rate := COALESCE(NULLIF(v_old.exchange_rate, 0), 1);

  IF (
    SELECT count(*) FROM money_kernel.bill_settlements
     WHERE pays_id = p_pays_id AND settlement_kind = 'pay'
  ) > 1 THEN
    RAISE EXCEPTION
      'invalid_arguments: pays % has multiple bill settlements; use rpc_void_pays + rpc_pay_bills',
      p_pays_id;
  END IF;

  IF p_kind NOT IN ('deposit','withdrawal','transfer','payment') THEN
    RAISE EXCEPTION 'invalid_arguments: unknown kind %', p_kind;
  END IF;
  IF p_kind = 'deposit' AND (p_from_pot_id IS NOT NULL OR p_to_pot_id IS NULL) THEN
    RAISE EXCEPTION 'invalid_arguments: deposit requires from=NULL, to!=NULL';
  END IF;
  IF p_kind = 'withdrawal' AND (p_from_pot_id IS NULL OR p_to_pot_id IS NOT NULL) THEN
    RAISE EXCEPTION 'invalid_arguments: withdrawal requires from!=NULL, to=NULL';
  END IF;
  IF p_kind IN ('transfer','payment')
     AND (p_from_pot_id IS NULL OR p_to_pot_id IS NULL OR p_from_pot_id = p_to_pot_id) THEN
    RAISE EXCEPTION 'invalid_arguments: % requires distinct from/to pots', p_kind;
  END IF;
  IF p_kind = 'payment' AND p_bill_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: payment requires p_bill_id';
  END IF;
  IF p_amount <= 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  IF v_exchange_rate <= 0 OR v_books_rate <= 0 THEN RAISE EXCEPTION 'invalid_rate'; END IF;

  SELECT COALESCE(array_agg(x ORDER BY x), '{}') INTO v_bill_ids
    FROM (
      SELECT DISTINCT bill_id AS x FROM money_kernel.bill_settlements
       WHERE pays_id = p_pays_id AND settlement_kind = 'pay'
      UNION
      SELECT p_bill_id WHERE p_kind = 'payment' AND p_bill_id IS NOT NULL
    ) s;
  SELECT COALESCE(array_agg(x ORDER BY x), '{}') INTO v_lot_ids
    FROM unnest(ARRAY[
      v_old.from_cash_bundle_id, v_old.to_cash_bundle_id, p_from_pot_id, p_to_pot_id
    ]) AS x
   WHERE x IS NOT NULL;

  IF cardinality(v_bill_ids) > 0 THEN
    PERFORM 1 FROM money_kernel.bills WHERE id = ANY(v_bill_ids) ORDER BY id FOR UPDATE;
  END IF;
  IF cardinality(v_lot_ids) > 0 THEN
    PERFORM 1 FROM money_kernel.cash_bundles WHERE id = ANY(v_lot_ids) ORDER BY id FOR UPDATE;
  END IF;
  SELECT * INTO v_old FROM money_kernel.pays
    WHERE id = p_pays_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF v_old.status = 'voided' THEN
    RAISE EXCEPTION 'invalid_state: pays % already voided', p_pays_id;
  END IF;

  IF p_from_pot_id IS NOT NULL THEN
    SELECT * INTO v_from_lot FROM money_kernel.cash_bundles WHERE id = p_from_pot_id;
    IF v_from_lot.tenant_id <> p_tenant_id THEN
      RAISE EXCEPTION 'invalid_arguments: from_pot % not in tenant', p_from_pot_id;
    END IF;
  END IF;
  IF p_to_pot_id IS NOT NULL THEN
    SELECT * INTO v_to_lot FROM money_kernel.cash_bundles WHERE id = p_to_pot_id;
    IF v_to_lot.tenant_id <> p_tenant_id THEN
      RAISE EXCEPTION 'invalid_arguments: to_pot % not in tenant', p_to_pot_id;
    END IF;
  END IF;
  IF v_from_lot.id IS NOT NULL AND v_to_lot.id IS NOT NULL
     AND v_from_lot.currency_code = v_to_lot.currency_code
     AND v_exchange_rate <> 1 THEN
    RAISE EXCEPTION 'invalid_rate: exchange_rate must be 1 for same-currency';
  END IF;

  IF v_old.to_cash_bundle_id IS NOT NULL THEN
    v_to_amt := CASE
      WHEN v_old.kind = 'transfer' THEN round(v_old.amount * v_old.exchange_rate, 4)
      ELSE v_old.amount
    END;
    SELECT amount INTO v_to_bal FROM money_kernel.cash_bundles WHERE id = v_old.to_cash_bundle_id;
    IF v_to_bal < v_to_amt THEN
      RAISE EXCEPTION
        'insufficient_balance: cannot update pays %; to_pot % has % but reverse needs %',
        p_pays_id, v_old.to_cash_bundle_id, v_to_bal, v_to_amt;
    END IF;
  END IF;

  PERFORM money_kernel.fn_kernel_settlement_delete_allowed();
  DELETE FROM money_kernel.bill_settlements
   WHERE pays_id = p_pays_id AND settlement_kind = 'pay';
  UPDATE money_kernel.pays
     SET status = 'voided', voided_at = now(), updated_at = now(),
         meta = COALESCE(meta, '{}'::jsonb)
                || jsonb_build_object(
                     'void_reason', p_reason,
                     'replaced_by_key', p_idempotency_key
                   )
   WHERE id = p_pays_id;

  IF p_kind = 'payment' THEN
    SELECT * INTO v_bill FROM money_kernel.bills WHERE id = p_bill_id;
    IF v_bill.id IS NULL OR v_bill.tenant_id <> p_tenant_id THEN
      RAISE EXCEPTION 'not_found: bill %', p_bill_id;
    END IF;
    IF v_bill.kind = 'credit_note' THEN
      RAISE EXCEPTION
        'invalid_arguments: credit_note cannot be cash-paid; use rpc_apply_document_settlement';
    END IF;
    IF v_bill.status = 'voided' THEN
      RAISE EXCEPTION 'invalid_state: cannot pay voided bill %', p_bill_id;
    END IF;
    IF v_bill.from_profile_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM money_kernel.cash_bundles pp
        JOIN money_kernel.cash_locations pt ON pt.id = pp.cash_location_id
        JOIN money_kernel.cashbooks a ON a.id = pt.cashbook_id
       WHERE pp.id = p_from_pot_id
         AND a.profile_id IS NOT NULL
         AND a.entity_id = v_bill.from_profile_id
    ) THEN
      RAISE EXCEPTION
        'invalid_arguments: from_pot must belong to bill.from_profile_id %',
        v_bill.from_profile_id;
    END IF;
    IF v_from_lot.currency_code <> v_bill.currency_code
       OR v_to_lot.currency_code <> v_bill.currency_code THEN
      RAISE EXCEPTION 'invalid_arguments: both pots must match bill currency for payment';
    END IF;
    IF v_exchange_rate <> 1 THEN
      RAISE EXCEPTION 'invalid_rate: exchange_rate must be 1 for kind=payment';
    END IF;
    v_alloc := round(p_amount, 2);
    v_to_amt := p_amount;
    IF v_alloc > v_bill.due_amount THEN
      RAISE EXCEPTION
        'invalid_amount: allocation % exceeds bill due % (post-void)',
        v_alloc, v_bill.due_amount;
    END IF;
  END IF;

  IF p_from_pot_id IS NOT NULL THEN
    SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = p_from_pot_id;
    IF v_from_bal < p_amount THEN
      RAISE EXCEPTION
        'insufficient_balance: pot % has % after reverse; new pays needs %',
        p_from_pot_id, v_from_bal, p_amount;
    END IF;
  END IF;

  v_books := round(p_amount * v_books_rate, 4);

  v_new_refs := COALESCE(p_refs, '{}'::jsonb)
                || jsonb_build_object('replaces_pays_id', p_pays_id);
  IF p_kind = 'payment' AND p_bill_id IS NOT NULL THEN
    v_new_refs := v_new_refs || jsonb_build_object('bill_id', p_bill_id);
  END IF;

  INSERT INTO money_kernel.pays (
    tenant_id, kind, from_cash_bundle_id, to_cash_bundle_id,
    amount, currency_code, books_amount, exchange_rate,
    payment_date, status, idempotency_key, refs, meta, created_by
  ) VALUES (
    p_tenant_id, p_kind, p_from_pot_id, p_to_pot_id,
    p_amount,
    COALESCE(v_from_lot.currency_code, v_to_lot.currency_code),
    v_books,
    CASE WHEN p_kind = 'payment' THEN 1 ELSE v_exchange_rate END,
    CURRENT_DATE, 'posted', p_idempotency_key, v_new_refs,
    COALESCE(p_meta, '{}'::jsonb) || jsonb_build_object('update_reason', p_reason),
    auth.uid()
  ) RETURNING * INTO v_new;

  IF p_kind = 'payment' THEN
    INSERT INTO money_kernel.bill_settlements (
      tenant_id, bill_id, settlement_kind, pays_id, source_bill_id,
      allocated_amount, allocated_books_amount
    ) VALUES (
      p_tenant_id, p_bill_id, 'pay', v_new.id, NULL, v_alloc, v_books
    ) RETURNING * INTO v_settle;
  END IF;

  IF p_from_pot_id IS NOT NULL THEN
    SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = p_from_pot_id;
  END IF;
  IF p_to_pot_id IS NOT NULL THEN
    SELECT amount INTO v_to_bal FROM money_kernel.cash_bundles WHERE id = p_to_pot_id;
  END IF;

  RETURN jsonb_build_object(
    'voided_pays_id', p_pays_id, 'new_pays_id', v_new.id, 'kind', p_kind,
    'amount', p_amount, 'currency_code', v_new.currency_code,
    'to_amount', v_to_amt, 'allocated_amount', v_alloc, 'bill_id', p_bill_id,
    'from_cash_bundle_id', p_from_pot_id, 'to_cash_bundle_id', p_to_pot_id,
    'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
    'status', 'posted', 'idempotent', false
  );
END;
$$;

-- Drop redundant legacy wrapper overloads of record_dropship_courier_remittance
-- (the 11-arg function has DEFAULTs on args 4..11).
DROP FUNCTION IF EXISTS public.record_dropship_courier_remittance(bigint, numeric, text, text, date, text, text);
DROP FUNCTION IF EXISTS public.record_dropship_courier_remittance(bigint, numeric, text, text, date, text, text, numeric);
DROP FUNCTION IF EXISTS public.record_dropship_courier_remittance(bigint, numeric, text, text, date, text, text, numeric, bigint);

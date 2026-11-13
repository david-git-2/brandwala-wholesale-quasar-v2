-- Money spine v2 write RPCs (from 02-actions.md)

CREATE OR REPLACE FUNCTION public.rpc_deposit(
  p_tenant_id       bigint,
  p_profile_id      bigint,
  p_amount          numeric,
  p_currency_code   text    DEFAULT 'BDT',
  p_pot_id          bigint  DEFAULT NULL,
  p_meta            jsonb   DEFAULT '{}'::jsonb,
  p_idempotency_key text    DEFAULT NULL,
  p_books_rate      numeric DEFAULT NULL,
  p_location_code   text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
  v_ccy text;
v_pays money_kernel.pays;
  v_lot_id   bigint;
  v_point_id bigint;
  v_balance numeric(18,4);
  v_books   numeric(18,4);
  v_loc_code text;
BEGIN

  v_exchange_rate := 1;
  v_ccy := upper(btrim(coalesce(p_currency_code, 'BDT')));
  v_loc_code := coalesce(nullif(btrim(p_location_code), ''), 'main');
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'deposit');

  -- Validation
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount: must be > 0';
  END IF;

  PERFORM public.money_kernel_assert_profile_in_tenant(p_tenant_id, p_profile_id);

  -- Idempotency (posted only)
  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_pays FROM money_kernel.pays
      WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
        AND status = 'posted';
    IF FOUND THEN
      IF v_pays.kind <> 'deposit' OR v_pays.amount <> p_amount
         OR v_pays.currency_code <> p_currency_code THEN
        RAISE EXCEPTION
          'idempotency_conflict: key % used for different parameters', p_idempotency_key;
      END IF;
      SELECT amount INTO v_balance FROM money_kernel.cash_bundles WHERE id = v_pays.to_cash_bundle_id;
      RETURN jsonb_build_object(
        'pays_id', v_pays.id, 'kind', 'deposit',
        'pot_id', v_pays.to_cash_bundle_id, 'cash_bundle_id', v_pays.to_cash_bundle_id,
        'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
        'books_amount', v_pays.books_amount, 'balance_after', v_balance,
        'payment_date', v_pays.payment_date, 'status', v_pays.status,
        'idempotent', true
      );
    END IF;
  END IF;

  -- Destination lot: explicit id, or open a new FX lot at location (default main) at resolved books_rate.
  IF p_pot_id IS NOT NULL THEN
    SELECT pp.id, pp.books_rate INTO v_lot_id, v_books_rate
      FROM money_kernel.cash_bundles pp
      JOIN money_kernel.cash_locations    pt ON pt.id = pp.cash_location_id
      JOIN money_kernel.cashbooks  a  ON a.id  = pt.cashbook_id
     WHERE pp.id = p_pot_id AND pp.currency_code = v_ccy
       AND a.tenant_id = p_tenant_id AND a.profile_id = p_profile_id;
    IF v_lot_id IS NULL THEN
      RAISE EXCEPTION
        'not_found: lot % valid for profile % in %', p_pot_id, p_profile_id, v_ccy;
    END IF;
    PERFORM 1 FROM money_kernel.cash_bundles WHERE id = v_lot_id FOR UPDATE;
  ELSE
  IF v_ccy = 'BDT' THEN
      v_books_rate := 1;
    ELSIF p_books_rate IS NOT NULL AND p_books_rate > 0 THEN
      v_books_rate := p_books_rate;
    ELSE
      v_books_rate := money_kernel.fn_resolve_books_rate(p_tenant_id, v_ccy);
    END IF;
    IF v_books_rate IS NULL OR v_books_rate <= 0 THEN
      RAISE EXCEPTION 'invalid_rate: books_rate must be > 0';
    END IF;
    SELECT cp.id INTO v_point_id
      FROM money_kernel.cashbooks a
      JOIN money_kernel.cash_locations cp ON cp.cashbook_id = a.id AND cp.location_code = v_loc_code
     WHERE a.tenant_id = p_tenant_id AND a.profile_id = p_profile_id
     LIMIT 1;
    IF v_point_id IS NULL THEN
      PERFORM public.fn_provision_kernel_cashbook_for_profile_row(p_tenant_id, p_profile_id);
      SELECT cp.id INTO v_point_id
        FROM money_kernel.cashbooks a
        JOIN money_kernel.cash_locations cp ON cp.cashbook_id = a.id AND cp.location_code = v_loc_code
       WHERE a.tenant_id = p_tenant_id AND a.profile_id = p_profile_id
       LIMIT 1;
    END IF;
    v_lot_id := money_kernel.fn_open_cash_bundle(
      p_tenant_id,
      v_point_id,
      v_ccy,
      v_books_rate,
      NULL
    );
  END IF;
  IF v_books_rate IS NULL OR v_books_rate <= 0 THEN
    RAISE EXCEPTION 'invalid_rate: books_rate must be > 0';
  END IF;
  v_books := round(p_amount * v_books_rate, 4);

  BEGIN
    INSERT INTO money_kernel.pays (
      tenant_id, kind, from_profile_id, to_profile_id,
      from_cash_bundle_id, to_cash_bundle_id,
      amount, currency_code, books_amount, books_rate, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'deposit', NULL, p_profile_id,
      NULL, v_lot_id,
      p_amount, p_currency_code, v_books, v_books_rate, 1,
      CURRENT_DATE, 'posted', p_idempotency_key, '{}'::jsonb, p_meta, auth.uid()
    ) RETURNING * INTO v_pays;
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_pays FROM money_kernel.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF NOT FOUND THEN RAISE; END IF;
    IF v_pays.kind <> 'deposit' OR v_pays.amount <> p_amount
       OR v_pays.currency_code <> p_currency_code THEN
      RAISE EXCEPTION
        'idempotency_conflict: key % used for different parameters', p_idempotency_key;
    END IF;
    SELECT amount INTO v_balance FROM money_kernel.cash_bundles WHERE id = v_pays.to_cash_bundle_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'kind', 'deposit',
      'pot_id', v_pays.to_cash_bundle_id, 'cash_bundle_id', v_pays.to_cash_bundle_id,
      'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
      'books_amount', v_pays.books_amount, 'balance_after', v_balance,
      'payment_date', v_pays.payment_date, 'status', v_pays.status,
      'idempotent', true
    );
  END;

  PERFORM money_kernel.fn_ensure_header_pay_bundle_lines(p_tenant_id, v_pays.id);

  SELECT amount INTO v_balance FROM money_kernel.cash_bundles WHERE id = v_lot_id;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'kind', 'deposit',
    'pot_id', v_lot_id, 'cash_bundle_id', v_lot_id,
    'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
    'books_amount', v_pays.books_amount, 'balance_after', v_balance,
    'payment_date', v_pays.payment_date, 'status', v_pays.status,
    'idempotent', false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_withdraw(
  p_tenant_id       bigint,
  p_profile_id      bigint,
  p_amount          numeric,
  p_currency_code   text    DEFAULT 'BDT',
  p_pot_id          bigint  DEFAULT NULL,
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
  v_lot_id  bigint;
  v_balance numeric(18,4);
  v_books   numeric(18,4);
BEGIN

  v_books_rate := money_kernel.fn_resolve_books_rate(p_tenant_id, COALESCE(p_currency_code, 'BDT'));
  v_exchange_rate := 1;
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'withdraw');

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount: must be > 0';
  END IF;
  IF v_books_rate IS NULL OR v_books_rate <= 0 THEN
    RAISE EXCEPTION 'invalid_rate: books_rate must be > 0';
  END IF;

  PERFORM public.money_kernel_assert_profile_in_tenant(p_tenant_id, p_profile_id);

  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_pays FROM money_kernel.pays
      WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF FOUND THEN
      IF v_pays.kind <> 'withdrawal' OR v_pays.amount <> p_amount
         OR v_pays.currency_code <> p_currency_code THEN
        RAISE EXCEPTION
          'idempotency_conflict: key % used for different parameters', p_idempotency_key;
      END IF;
      SELECT amount INTO v_balance FROM money_kernel.cash_bundles WHERE id = v_pays.from_cash_bundle_id;
      RETURN jsonb_build_object(
        'pays_id', v_pays.id, 'kind', 'withdrawal', 'pot_id', v_pays.from_cash_bundle_id,
        'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
        'books_amount', v_pays.books_amount, 'balance_after', v_balance,
        'payment_date', v_pays.payment_date, 'status', v_pays.status,
        'idempotent', true
      );
    END IF;
  END IF;

  IF p_pot_id IS NOT NULL THEN
    SELECT pp.id INTO v_lot_id
      FROM money_kernel.cash_bundles pp
      JOIN money_kernel.cash_locations    pt ON pt.id = pp.cash_location_id
      JOIN money_kernel.cashbooks  a  ON a.id  = pt.cashbook_id
     WHERE pp.id = p_pot_id AND pp.currency_code = p_currency_code
       AND a.tenant_id = p_tenant_id AND a.profile_id = p_profile_id;
    IF v_lot_id IS NULL THEN
      RAISE EXCEPTION
        'not_found: pot % valid for profile % in %', p_pot_id, p_profile_id, p_currency_code;
    END IF;
  ELSE
    SELECT pp.id INTO v_lot_id
      FROM money_kernel.cashbooks a
      JOIN money_kernel.cash_locations    pt ON pt.cashbook_id = a.id
      JOIN money_kernel.cash_bundles pp ON pp.cash_location_id = pt.id
     WHERE a.tenant_id = p_tenant_id AND a.profile_id = p_profile_id AND pp.currency_code = p_currency_code
     ORDER BY (a.default_cash_bundle_id = pp.id) DESC, pp.id ASC
     LIMIT 1;
    IF v_lot_id IS NULL THEN
      RAISE EXCEPTION 'not_found: no % pot for profile %', p_currency_code, p_profile_id;
    END IF;
  END IF;

  -- Lock + balance check (only withdraw needs this)
  SELECT amount INTO v_balance
    FROM money_kernel.cash_bundles WHERE id = v_lot_id FOR UPDATE;
  IF v_balance < p_amount THEN
    RAISE EXCEPTION
      'insufficient_balance: pot % has %, withdrawal is %', v_lot_id, v_balance, p_amount;
  END IF;

  v_books := round(p_amount * v_books_rate, 4);

  BEGIN
    INSERT INTO money_kernel.pays (
      tenant_id, kind, from_profile_id, to_profile_id,
      from_cash_bundle_id, to_cash_bundle_id,
      amount, currency_code, books_amount, books_rate, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'withdrawal', p_profile_id, NULL,
      v_lot_id, NULL,
      p_amount, p_currency_code, v_books, v_books_rate, 1,
      CURRENT_DATE, 'posted', p_idempotency_key, '{}'::jsonb, p_meta, auth.uid()
    ) RETURNING * INTO v_pays;
  PERFORM money_kernel.fn_ensure_header_pay_bundle_lines(p_tenant_id, v_pays.id);
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_pays FROM money_kernel.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF NOT FOUND THEN RAISE; END IF;
    IF v_pays.kind <> 'withdrawal' OR v_pays.amount <> p_amount
       OR v_pays.currency_code <> p_currency_code THEN
      RAISE EXCEPTION
        'idempotency_conflict: key % used for different parameters', p_idempotency_key;
    END IF;
    SELECT amount INTO v_balance FROM money_kernel.cash_bundles WHERE id = v_pays.from_cash_bundle_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'kind', 'withdrawal', 'pot_id', v_pays.from_cash_bundle_id,
      'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
      'books_amount', v_pays.books_amount, 'balance_after', v_balance,
      'payment_date', v_pays.payment_date, 'status', v_pays.status,
      'idempotent', true
    );
  END;

  SELECT amount INTO v_balance FROM money_kernel.cash_bundles WHERE id = v_lot_id;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'kind', 'withdrawal', 'pot_id', v_lot_id,
    'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
    'books_amount', v_pays.books_amount, 'balance_after', v_balance,
    'payment_date', v_pays.payment_date, 'status', v_pays.status,
    'idempotent', false
  );
END;
$$;

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
  v_books_rate := money_kernel.fn_resolve_books_rate(p_tenant_id, COALESCE(p_currency_code, 'BDT'));
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

  -- Lock both pots in id order (deadlock-safe)
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

  -- Both pots must belong to the same profile
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
  v_books_rate := money_kernel.fn_resolve_books_rate(p_tenant_id, COALESCE(p_currency_code, 'BDT'));
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
  v_payee_profile_id bigint;
  v_payee_cashbook_enabled boolean;
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

  -- Payee bundle: only when payee profile has cashbook_enabled (AR collect inflow).
  -- AP vendor pay: debit payer bundle only; to_cash_bundle_id stays NULL (money spec).
  IF p_to_pot_id IS NOT NULL THEN
    v_to_lot_id := p_to_pot_id;
  ELSE
    v_to_lot_id := NULL;
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

  IF v_to_lot_id IS NULL AND p_to_pot_id IS NULL THEN
    SELECT b.to_profile_id, coalesce(pr.cashbook_enabled, false)
      INTO v_payee_profile_id, v_payee_cashbook_enabled
      FROM money_kernel.bills b
      JOIN public.profiles pr
        ON pr.id = b.to_profile_id AND pr.tenant_id = b.tenant_id
     WHERE b.tenant_id = p_tenant_id AND b.id = v_bill_ids[1];
    IF v_payee_cashbook_enabled THEN
      v_to_lot_id := public.fn_provision_kernel_cashbook_currency(
        p_tenant_id,
        v_payee_profile_id,
        (SELECT currency_code FROM money_kernel.bills
          WHERE tenant_id = p_tenant_id AND id = v_bill_ids[1]),
        'main',
        NULL
      );
      IF v_to_lot_id IS NULL THEN
        RAISE EXCEPTION 'not_found: payee bundle for profile %', v_payee_profile_id;
      END IF;
    END IF;
  END IF;

  IF v_payee_profile_id IS NULL AND coalesce(array_length(v_bill_ids, 1), 0) > 0 THEN
    SELECT b.to_profile_id INTO v_payee_profile_id
      FROM money_kernel.bills b
     WHERE b.tenant_id = p_tenant_id AND b.id = v_bill_ids[1];
  END IF;

  SELECT * INTO v_from_lot
    FROM money_kernel.cash_bundles
   WHERE id = p_from_pot_id AND tenant_id = p_tenant_id
   FOR UPDATE;
  IF v_from_lot.id IS NULL THEN
    RAISE EXCEPTION 'not_found: from bundle %', p_from_pot_id;
  END IF;

  IF v_to_lot_id IS NOT NULL THEN
    IF p_from_pot_id = v_to_lot_id THEN
      RAISE EXCEPTION 'invalid_arguments: from and to bundle must differ';
    END IF;
  END IF;

  IF v_to_lot_id IS NOT NULL THEN
    IF p_from_pot_id < v_to_lot_id THEN
      SELECT * INTO v_to_lot FROM money_kernel.cash_bundles WHERE id = v_to_lot_id FOR UPDATE;
    ELSE
      SELECT * INTO v_to_lot FROM money_kernel.cash_bundles WHERE id = v_to_lot_id FOR UPDATE;
    END IF;
    IF v_to_lot.id IS NULL THEN
      RAISE EXCEPTION 'not_found: to bundle %', v_to_lot_id;
    END IF;
    IF v_to_lot.tenant_id <> p_tenant_id THEN
      RAISE EXCEPTION 'invalid_arguments: to bundle must belong to tenant %', p_tenant_id;
    END IF;
  END IF;

  v_books_rate := coalesce(nullif(v_from_lot.books_rate, 0), 1::numeric(15, 6));

  PERFORM public.money_kernel_assert_profile_in_tenant(p_tenant_id, p_payer_profile_id);

  PERFORM 1 FROM money_kernel.cash_bundles pp
    JOIN money_kernel.cash_locations pt ON pt.id = pp.cash_location_id
    JOIN money_kernel.cashbooks a ON a.id = pt.cashbook_id
   WHERE pp.id = p_from_pot_id AND a.profile_id = p_payer_profile_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: from bundle % does not belong to profile %', p_from_pot_id, p_payer_profile_id;
  END IF;

  IF v_from_lot.amount < p_amount THEN
    RAISE EXCEPTION 'insufficient_balance: bundle % has %, payment is %',
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
            THEN format(
              'invalid_arguments: bill %s currency %s must match payer bundle %s',
              b.id, b.currency_code, v_from_lot.currency_code)
          WHEN v_to_lot_id IS NOT NULL AND b.currency_code <> v_to_lot.currency_code
            THEN format(
              'invalid_arguments: bill %s currency %s must match payee bundle %s',
              b.id, b.currency_code, v_to_lot.currency_code)
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
      tenant_id, kind, from_profile_id, to_profile_id,
      from_cash_bundle_id, to_cash_bundle_id,
      amount, currency_code, books_amount, books_rate, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'payment', p_payer_profile_id, v_payee_profile_id,
      p_from_pot_id, v_to_lot_id,
      p_amount, v_from_lot.currency_code, v_books, v_books_rate, 1,
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
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
BEGIN

  v_books_rate := money_kernel.fn_resolve_books_rate(p_tenant_id, COALESCE(p_currency_code, 'BDT'));
  v_exchange_rate := 1;
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  IF v_exchange_rate IS DISTINCT FROM 1 THEN
    RAISE EXCEPTION 'invalid_rate: exchange_rate must be 1 for kind=payment (I7b)';
  END IF;
  RETURN public.rpc_pay_bills(
    p_tenant_id,
    p_payer_profile_id,
    p_from_pot_id,
    p_to_pot_id,
    p_amount,
    v_books_rate,
    jsonb_build_array(jsonb_build_object('bill_id', p_bill_id, 'amount', p_amount)),
    p_meta,
    p_idempotency_key
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_apply_document_settlement(
  p_tenant_id       bigint,
  p_source_bill_id  bigint,
  p_target_bill_id  bigint,
  p_amount          numeric,
  p_idempotency_key text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
  v_source bills;
  v_target bills;
  v_settle bill_settlements;
  v_amt    numeric(18,4);
  v_first  bigint;
  v_second bigint;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount: must be > 0';
  END IF;
  IF p_source_bill_id = p_target_bill_id THEN
    RAISE EXCEPTION 'invalid_arguments: source and target must differ';
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_settle FROM money_kernel.bill_settlements
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key;
    IF FOUND THEN
      IF v_settle.settlement_kind <> 'document'
         OR v_settle.bill_id <> p_target_bill_id
         OR v_settle.source_bill_id <> p_source_bill_id
         OR v_settle.allocated_amount <> round(p_amount, 2) THEN
        RAISE EXCEPTION 'idempotency_conflict: key %', p_idempotency_key;
      END IF;
      RETURN jsonb_build_object(
        'settlement_id', v_settle.id,
        'source_bill_id', p_source_bill_id,
        'target_bill_id', p_target_bill_id,
        'allocated_amount', v_settle.allocated_amount,
        'idempotent', true
      );
    END IF;
  END IF;

  v_amt := round(p_amount, 2);
  IF p_source_bill_id < p_target_bill_id THEN
    v_first := p_source_bill_id; v_second := p_target_bill_id;
  ELSE
    v_first := p_target_bill_id; v_second := p_source_bill_id;
  END IF;
  PERFORM 1 FROM money_kernel.bills
   WHERE tenant_id = p_tenant_id AND id = ANY(ARRAY[v_first, v_second])
   ORDER BY id
   FOR UPDATE;

  SELECT * INTO v_source FROM money_kernel.bills WHERE id = p_source_bill_id;
  SELECT * INTO v_target FROM money_kernel.bills WHERE id = p_target_bill_id;
  IF v_source.id IS NULL OR v_target.id IS NULL THEN
    RAISE EXCEPTION 'not_found: bill';
  END IF;
  IF v_source.kind <> 'credit_note' THEN
    RAISE EXCEPTION 'invalid_arguments: source must be credit_note, got %', v_source.kind;
  END IF;
  IF v_target.kind = 'credit_note' THEN
    RAISE EXCEPTION 'invalid_arguments: cannot apply credit_note onto another credit_note';
  END IF;
  IF v_source.status IN ('draft','voided') OR v_target.status IN ('draft','voided') THEN
    RAISE EXCEPTION 'invalid_state: both bills must be live (issued/partial/paid/written_off)';
  END IF;
  IF v_source.currency_code <> v_target.currency_code THEN
    RAISE EXCEPTION 'invalid_arguments: currency mismatch';
  END IF;
  -- I29: CN parties are swap of obligation; target must be same pair (payer/payee)
  IF v_target.from_profile_id IS DISTINCT FROM v_source.to_profile_id
     OR v_target.to_profile_id IS DISTINCT FROM v_source.from_profile_id THEN
    RAISE EXCEPTION
      'invalid_arguments: document apply requires target.from=source.to and target.to=source.from';
  END IF;
  IF v_amt > v_target.due_amount THEN
    RAISE EXCEPTION 'invalid_amount: % exceeds target due %', v_amt, v_target.due_amount;
  END IF;
  IF v_amt > v_source.due_amount THEN
    RAISE EXCEPTION 'invalid_amount: % exceeds credit remaining %', v_amt, v_source.due_amount;
  END IF;

  BEGIN
    INSERT INTO money_kernel.bill_settlements (
      tenant_id, bill_id, settlement_kind, pays_id, source_bill_id,
      allocated_amount, allocated_books_amount, idempotency_key
    ) VALUES (
      p_tenant_id, p_target_bill_id, 'document', NULL, p_source_bill_id,
      v_amt, v_amt, p_idempotency_key
    ) RETURNING * INTO v_settle;
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_settle FROM money_kernel.bill_settlements
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key;
    IF NOT FOUND THEN RAISE; END IF;
    IF v_settle.settlement_kind <> 'document'
       OR v_settle.bill_id <> p_target_bill_id
       OR v_settle.source_bill_id <> p_source_bill_id
       OR v_settle.allocated_amount <> v_amt THEN
      RAISE EXCEPTION 'idempotency_conflict: key %', p_idempotency_key;
    END IF;
    RETURN jsonb_build_object(
      'settlement_id', v_settle.id,
      'source_bill_id', p_source_bill_id,
      'target_bill_id', p_target_bill_id,
      'allocated_amount', v_settle.allocated_amount,
      'idempotent', true
    );
  END;

  RETURN jsonb_build_object(
    'settlement_id', v_settle.id,
    'source_bill_id', p_source_bill_id,
    'target_bill_id', p_target_bill_id,
    'allocated_amount', v_amt,
    'idempotent', false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_void_document_settlement(
  p_tenant_id     bigint,
  p_settlement_id bigint,
  p_reason        text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
  v_settle bill_settlements;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'void');

  SELECT * INTO v_settle FROM money_kernel.bill_settlements
   WHERE id = p_settlement_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: settlement %', p_settlement_id;
  END IF;
  IF v_settle.settlement_kind <> 'document' THEN
    RAISE EXCEPTION 'invalid_arguments: settlement % is not document; use rpc_void_pays', p_settlement_id;
  END IF;

  -- Lock target + source bills in one statement (id order)
  PERFORM 1 FROM money_kernel.bills
   WHERE id = ANY(ARRAY[v_settle.bill_id, v_settle.source_bill_id])
   ORDER BY id
   FOR UPDATE;

  DELETE FROM money_kernel.bill_settlements WHERE id = p_settlement_id;

  RETURN jsonb_build_object(
    'settlement_id', p_settlement_id,
    'target_bill_id', v_settle.bill_id,
    'source_bill_id', v_settle.source_bill_id,
    'voided', true,
    'reason', p_reason
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_void_pays(
  p_tenant_id bigint,
  p_pays_id   bigint,
  p_reason    text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
  v_pays money_kernel.pays;
  v_from_bal  numeric(18,4);
  v_to_bal    numeric(18,4);
  v_bill_ids  bigint[];
  v_impacts   jsonb := '[]'::jsonb;
  v_lot_ids   bigint[];
  v_to_credit numeric(18,4);
BEGIN

  v_books_rate := money_kernel.fn_resolve_books_rate(p_tenant_id, COALESCE(p_currency_code, 'BDT'));
  v_exchange_rate := 1;
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'void');

  -- Peek pays (no lock) so we can follow bills → pots → pays lock order
  SELECT * INTO v_pays FROM money_kernel.pays
    WHERE id = p_pays_id AND tenant_id = p_tenant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: pays % in tenant %', p_pays_id, p_tenant_id;
  END IF;

  IF v_pays.status = 'voided' THEN
    SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = v_pays.from_cash_bundle_id;
    SELECT amount INTO v_to_bal   FROM money_kernel.cash_bundles WHERE id = v_pays.to_cash_bundle_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'status', 'voided', 'kind', v_pays.kind,
      'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
      'bill_impacts', '[]'::jsonb, 'idempotent', true
    );
  END IF;

  SELECT COALESCE(array_agg(bill_id ORDER BY bill_id), '{}')
    INTO v_bill_ids
    FROM (SELECT DISTINCT bill_id FROM money_kernel.bill_settlements WHERE pays_id = p_pays_id) s;

  SELECT COALESCE(array_agg(x ORDER BY x), '{}')
    INTO v_lot_ids
    FROM unnest(ARRAY[v_pays.from_cash_bundle_id, v_pays.to_cash_bundle_id]) AS x
   WHERE x IS NOT NULL;

  IF cardinality(v_bill_ids) > 0 THEN
    PERFORM 1 FROM money_kernel.bills WHERE id = ANY(v_bill_ids) ORDER BY id FOR UPDATE;
  END IF;
  IF cardinality(v_lot_ids) > 0 THEN
    PERFORM 1 FROM money_kernel.cash_bundles WHERE id = ANY(v_lot_ids) ORDER BY id FOR UPDATE;
  END IF;

  -- Lock pays last; re-check status under lock
  SELECT * INTO v_pays FROM money_kernel.pays
    WHERE id = p_pays_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF v_pays.status = 'voided' THEN
    SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = v_pays.from_cash_bundle_id;
    SELECT amount INTO v_to_bal   FROM money_kernel.cash_bundles WHERE id = v_pays.to_cash_bundle_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'status', 'voided', 'kind', v_pays.kind,
      'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
      'bill_impacts', '[]'::jsonb, 'idempotent', true
    );
  END IF;

  -- Must match T1 fn_pays_apply credit expression (I22); pot rows already locked
  v_to_credit := CASE
    WHEN v_pays.kind = 'transfer' THEN round(v_pays.amount * v_pays.exchange_rate, 4)
    ELSE v_pays.amount
  END;
  IF v_pays.to_cash_bundle_id IS NOT NULL THEN
    SELECT amount INTO v_to_bal FROM money_kernel.cash_bundles WHERE id = v_pays.to_cash_bundle_id;
    IF v_to_bal < v_to_credit THEN
      RAISE EXCEPTION
        'insufficient_balance: cannot void pays %; to_pot % has % but reverse needs %',
        p_pays_id, v_pays.to_cash_bundle_id, v_to_bal, v_to_credit;
    END IF;
  END IF;

  DELETE FROM money_kernel.bill_settlements
   WHERE pays_id = p_pays_id AND settlement_kind = 'pay';

  UPDATE money_kernel.pays
     SET status = 'voided',
         voided_at = now(),
         updated_at = now(),
         meta = COALESCE(meta, '{}'::jsonb)
                || jsonb_build_object('void_reason', p_reason)
   WHERE id = p_pays_id;

  SELECT COALESCE(
           jsonb_agg(
             jsonb_build_object('bill_id', id, 'due_after', due_amount)
             ORDER BY id
           ),
           '[]'::jsonb
         )
    INTO v_impacts
    FROM money_kernel.bills
   WHERE id = ANY(v_bill_ids);

  IF v_pays.from_cash_bundle_id IS NOT NULL THEN
    SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = v_pays.from_cash_bundle_id;
  END IF;
  IF v_pays.to_cash_bundle_id IS NOT NULL THEN
    SELECT amount INTO v_to_bal FROM money_kernel.cash_bundles WHERE id = v_pays.to_cash_bundle_id;
  END IF;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'kind', v_pays.kind, 'amount', v_pays.amount,
    'status', 'voided',
    'from_cash_bundle_id', v_pays.from_cash_bundle_id, 'to_cash_bundle_id', v_pays.to_cash_bundle_id,
    'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
    'bill_impacts', v_impacts, 'idempotent', false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_revert_pays(
  p_tenant_id       bigint,
  p_pays_id         bigint,
  p_reason          text,
  p_idempotency_key text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_reason          text;
  v_orig            money_kernel.pays;
  v_rev             money_kernel.pays;
  v_rev_kind        text;
  v_from_bundle     bigint;
  v_to_bundle       bigint;
  v_from_bal        numeric(18,4);
  v_lot_ids         bigint[];
  v_books_rate      numeric(15,6);
BEGIN
  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  IF v_reason IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: reason is required';
  END IF;

  PERFORM public.assert_kernel_money_access(p_tenant_id, 'void');

  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_rev FROM money_kernel.pays
     WHERE tenant_id = p_tenant_id
       AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF FOUND THEN
      IF (v_rev.refs->>'reverses_pays_id')::bigint = p_pays_id THEN
        RETURN jsonb_build_object(
          'original_pays_id', p_pays_id,
          'reversal_pays_id', v_rev.id,
          'kind', v_rev.kind,
          'idempotent', true
        );
      END IF;
      RAISE EXCEPTION 'idempotency_conflict: key % already used by pays %',
        p_idempotency_key, v_rev.id;
    END IF;
  END IF;

  SELECT * INTO v_orig FROM money_kernel.pays
   WHERE id = p_pays_id AND tenant_id = p_tenant_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: pays % in tenant %', p_pays_id, p_tenant_id;
  END IF;

  IF v_orig.status <> 'posted' THEN
    RAISE EXCEPTION 'invalid_state: pays % is not posted', p_pays_id;
  END IF;

  IF v_orig.meta ? 'reverted_at' THEN
    RAISE EXCEPTION 'invalid_state: pays % already reverted', p_pays_id;
  END IF;

  IF v_orig.refs ? 'reverses_pays_id' THEN
    RAISE EXCEPTION 'invalid_arguments: cannot revert a reversal pays %', p_pays_id;
  END IF;

  IF v_orig.kind NOT IN ('deposit', 'withdrawal', 'transfer') THEN
    RAISE EXCEPTION 'invalid_arguments: kind % cannot be reverted here', v_orig.kind;
  END IF;

  IF v_orig.kind = 'deposit' THEN
    v_rev_kind := 'withdrawal';
    v_from_bundle := v_orig.to_cash_bundle_id;
    v_to_bundle := NULL;
    IF v_from_bundle IS NULL THEN
      RAISE EXCEPTION 'invalid_state: deposit % has no to_cash_bundle_id', p_pays_id;
    END IF;
  ELSIF v_orig.kind = 'withdrawal' THEN
    v_rev_kind := 'deposit';
    v_from_bundle := NULL;
    v_to_bundle := v_orig.from_cash_bundle_id;
    IF v_to_bundle IS NULL THEN
      RAISE EXCEPTION 'invalid_state: withdrawal % has no from_cash_bundle_id', p_pays_id;
    END IF;
  ELSE
    v_rev_kind := 'transfer';
    v_from_bundle := v_orig.to_cash_bundle_id;
    v_to_bundle := v_orig.from_cash_bundle_id;
    IF v_from_bundle IS NULL OR v_to_bundle IS NULL OR v_from_bundle = v_to_bundle THEN
      RAISE EXCEPTION 'invalid_state: transfer % missing distinct bundles', p_pays_id;
    END IF;
  END IF;

  v_lot_ids := ARRAY(
    SELECT x FROM unnest(ARRAY[v_from_bundle, v_to_bundle]) AS x WHERE x IS NOT NULL
  );
  IF cardinality(v_lot_ids) > 0 THEN
    PERFORM 1 FROM money_kernel.cash_bundles
     WHERE id = ANY(v_lot_ids) ORDER BY id FOR UPDATE;
  END IF;

  IF v_rev_kind IN ('withdrawal', 'transfer') AND v_from_bundle IS NOT NULL THEN
    SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = v_from_bundle;
    IF v_from_bal < v_orig.amount THEN
      RAISE EXCEPTION
        'insufficient_balance: bundle % has % but reversal needs %',
        v_from_bundle, v_from_bal, v_orig.amount;
    END IF;
  END IF;

  IF v_rev_kind = 'transfer' AND v_from_bundle IS NOT NULL THEN
    SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = v_from_bundle;
    IF v_from_bal < v_orig.amount THEN
      RAISE EXCEPTION
        'insufficient_balance: cannot revert transfer %; bundle % has % needs %',
        p_pays_id, v_from_bundle, v_from_bal, v_orig.amount;
    END IF;
  END IF;

  v_books_rate := v_orig.books_rate;

  INSERT INTO money_kernel.pays (
    tenant_id, kind,
    from_profile_id, to_profile_id,
    from_cash_bundle_id, to_cash_bundle_id,
    amount, currency_code, books_amount, books_rate, exchange_rate,
    payment_date, status, idempotency_key, refs, meta, created_by
  ) VALUES (
    p_tenant_id, v_rev_kind,
    v_orig.to_profile_id, v_orig.from_profile_id,
    v_from_bundle, v_to_bundle,
    v_orig.amount, v_orig.currency_code, v_orig.books_amount, v_books_rate,
    v_orig.exchange_rate,
    CURRENT_DATE, 'posted', p_idempotency_key,
    jsonb_build_object('reverses_pays_id', v_orig.id),
    jsonb_build_object('reversal', true, 'revert_reason', v_reason),
    auth.uid()
  ) RETURNING * INTO v_rev;

  PERFORM money_kernel.fn_ensure_header_pay_bundle_lines(p_tenant_id, v_rev.id);

  PERFORM set_config('money.revert_writer', '1', true);
  UPDATE money_kernel.pays
     SET meta = COALESCE(meta, '{}'::jsonb) || jsonb_build_object(
           'revert_reason', v_reason,
           'reverted_at', to_jsonb(now()),
           'reversal_pays_id', v_rev.id
         ),
         updated_at = now()
   WHERE id = v_orig.id;

  RETURN jsonb_build_object(
    'original_pays_id', v_orig.id,
    'reversal_pays_id', v_rev.id,
    'reversal_kind', v_rev.kind,
    'idempotent', false
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
  v_bill money_kernel.bills;
  v_from_lot money_kernel.cash_bundles;
  v_to_lot money_kernel.cash_bundles;
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

  v_books_rate := money_kernel.fn_resolve_books_rate(p_tenant_id, COALESCE(p_currency_code, 'BDT'));
  v_exchange_rate := 1;
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  -- Idempotency before locks
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

  -- Peek original pays (lock later: bills → pots → pays)
  SELECT * INTO v_old FROM money_kernel.pays
    WHERE id = p_pays_id AND tenant_id = p_tenant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: pays %', p_pays_id;
  END IF;
  IF v_old.status = 'voided' THEN
    RAISE EXCEPTION 'invalid_state: pays % already voided', p_pays_id;
  END IF;

  -- Multi-bill payment: void + rpc_pay_bills (this RPC re-settles at most one bill)
  IF (
    SELECT count(*) FROM money_kernel.bill_settlements
     WHERE pays_id = p_pays_id AND settlement_kind = 'pay'
  ) > 1 THEN
    RAISE EXCEPTION
      'invalid_arguments: pays % has multiple bill settlements; use rpc_void_pays + rpc_pay_bills',
      p_pays_id;
  END IF;

  -- Validation
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

  -- Lock bills → pots → pays (set-based)
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

  -- I20: old to-pot must still hold credit before reverse (same as rpc_void_pays)
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

  -- Reverse old
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

  -- Validate new payment against restored due
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
    -- from_pot must belong to bill.from_profile_id (payer)
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

  -- After reverse, from-pot must cover the new debit
  IF p_from_pot_id IS NOT NULL THEN
    SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = p_from_pot_id;
    IF v_from_bal < p_amount THEN
      RAISE EXCEPTION
        'insufficient_balance: pot % has % after reverse; new pays needs %',
        p_from_pot_id, v_from_bal, p_amount;
    END IF;
  END IF;

  v_books := round(p_amount * v_books_rate, 4);

  -- Build refs with traceability
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

CREATE OR REPLACE FUNCTION public.rpc_create_bill(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
  v_tenant_id     bigint := (p_payload->>'tenant_id')::bigint;
  v_kind          text   := p_payload->>'kind';
  v_idem          text   := p_payload->>'idempotency_key';
  v_source_entity text   := nullif(btrim(p_payload->>'source_entity'), '');
  v_source_type   text   := nullif(btrim(p_payload->>'source_type'), '');
  v_source_id     text   := nullif(btrim(p_payload->>'source_id'), '');
  v_source_key    text   := nullif(btrim(p_payload->>'source_key'), '');
  v_bill money_kernel.bills;
  v_existing      bills;
  v_registry      bill_kind_registry;
  v_invoice_no    text;
  v_total         numeric(18,4) := 0;
  v_lines         jsonb;
  v_line          jsonb;
  v_line_no       int := 0;
  v_line_total    numeric(18,4);
  v_qty           numeric(18,4);
  v_price         numeric(18,4);
  v_meta          jsonb := COALESCE(p_payload->'meta', '{}'::jsonb);
  v_required_key  text;
BEGIN
  -- Basic validation
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'invalid_arguments: tenant_id required'; END IF;
  PERFORM public.assert_kernel_money_access(v_tenant_id, 'bills');
  IF v_kind IS NULL THEN RAISE EXCEPTION 'invalid_arguments: kind required'; END IF;

  -- Registry lookup
  SELECT * INTO v_registry FROM money_kernel.bill_kind_registry
    WHERE kind = v_kind AND is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_arguments: unknown or inactive kind %', v_kind;
  END IF;

  -- required_meta check
  FOREACH v_required_key IN ARRAY v_registry.required_meta LOOP
    IF NOT (v_meta ? v_required_key) THEN
      RAISE EXCEPTION
        'invalid_arguments: kind % requires meta key %', v_kind, v_required_key;
    END IF;
  END LOOP;

  -- Idempotency short-circuit
  IF v_idem IS NOT NULL THEN
    SELECT * INTO v_existing FROM money_kernel.bills
      WHERE tenant_id = v_tenant_id AND idempotency_key = v_idem
        AND status <> 'voided';
    IF FOUND THEN
      RETURN jsonb_build_object(
        'bill_id', v_existing.id, 'invoice_no', v_existing.invoice_no,
        'status', v_existing.status, 'kind', v_existing.kind,
        'total_amount', v_existing.total_amount, 'due_amount', v_existing.due_amount,
        'idempotent', true
      );
    END IF;
  END IF;

  -- Upsert short-circuit (source_entity or source_type + source_id + source_key)
  IF v_source_id IS NOT NULL
     AND (v_source_entity IS NOT NULL OR v_source_type IS NOT NULL) THEN
    SELECT * INTO v_existing FROM money_kernel.bills
      WHERE tenant_id = v_tenant_id
        AND source_id = v_source_id
        AND COALESCE(source_key, '') = COALESCE(v_source_key, '')
        AND status <> 'voided'
        AND (
          (v_source_entity IS NOT NULL AND source_entity IS NOT DISTINCT FROM v_source_entity)
          OR (v_source_entity IS NULL AND source_type IS NOT DISTINCT FROM v_source_type)
        );
    IF FOUND THEN
      RETURN jsonb_build_object(
        'bill_id', v_existing.id, 'invoice_no', v_existing.invoice_no,
        'status', v_existing.status, 'kind', v_existing.kind,
        'total_amount', v_existing.total_amount, 'due_amount', v_existing.due_amount,
        'idempotent', true
      );
    END IF;
  END IF;

  -- Compute total from lines
  v_lines := COALESCE(p_payload->'lines', '[]'::jsonb);
  IF jsonb_array_length(v_lines) = 0 THEN
    RAISE EXCEPTION 'invalid_arguments: lines required';
  END IF;
  FOR v_line IN SELECT * FROM jsonb_array_elements(v_lines) LOOP
    v_qty   := COALESCE((v_line->>'quantity')::numeric,   1);
    v_price := COALESCE((v_line->>'unit_price')::numeric, 0);
    v_line_total := COALESCE((v_line->>'line_total')::numeric, v_qty * v_price);
    v_total := v_total + v_line_total;
  END LOOP;

  IF v_kind = 'credit_note' THEN
    IF (p_payload->>'parent_bill_id') IS NULL THEN
      RAISE EXCEPTION 'invalid_arguments: credit_note requires parent_bill_id';
    END IF;
    SELECT * INTO v_existing FROM money_kernel.bills
     WHERE id = (p_payload->>'parent_bill_id')::bigint
       AND tenant_id = v_tenant_id;
    IF v_existing.id IS NULL THEN
      RAISE EXCEPTION 'not_found: parent_bill_id %', (p_payload->>'parent_bill_id')::bigint;
    END IF;
    IF v_existing.status NOT IN ('issued','partial','paid','written_off') THEN
      RAISE EXCEPTION
        'invalid_state: credit_note parent must be issued/partial/paid/written_off, got %',
        v_existing.status;
    END IF;
    -- Parties = swap of parent (payer/payee reversed). Omit both → inherit swap.
    IF (p_payload->>'from_profile_id') IS NULL
       <> ((p_payload->>'to_profile_id') IS NULL) THEN
      RAISE EXCEPTION 'invalid_arguments: credit_note from/to must both be set or both omitted';
    END IF;
    IF (p_payload->>'from_profile_id') IS NOT NULL AND (
         (p_payload->>'from_profile_id')::bigint IS DISTINCT FROM v_existing.to_profile_id
      OR (p_payload->>'to_profile_id')::bigint IS DISTINCT FROM v_existing.from_profile_id
    ) THEN
      RAISE EXCEPTION
        'invalid_arguments: credit_note from/to must be swap of parent (from=parent.to, to=parent.from)';
    END IF;
    -- Only validate when caller sends currency; omitted → inherit parent on INSERT
    IF (p_payload->>'currency_code') IS NOT NULL
       AND (p_payload->>'currency_code') <> v_existing.currency_code THEN
      RAISE EXCEPTION 'invalid_arguments: credit_note currency must match parent';
    END IF;
  END IF;

  PERFORM money_kernel.validate_bill_source_plug(
    v_source_entity, v_source_type, v_source_id, v_source_key
  );

  -- Allocate invoice_no atomically
  v_invoice_no := public.rpc_allocate_invoice_no(v_tenant_id, v_kind);

  -- Insert bill
  BEGIN
    INSERT INTO money_kernel.bills (
      tenant_id, kind, status,
      invoice_no, invoice_date, due_date,
      from_profile_id, to_profile_id,
      counterparty_profile_id, counterparty_tenant_id,
      currency_code, total_amount, paid_amount, due_amount, written_off_amount,
      parent_bill_id,
      source_entity, source_type, source_id, source_key, idempotency_key,
      meta, note, created_by
    ) VALUES (
      v_tenant_id, v_kind, 'draft',  -- always draft; issue via auto_issue / rpc_issue_bill
      v_invoice_no,
      COALESCE((p_payload->>'invoice_date')::date, CURRENT_DATE),
      (p_payload->>'due_date')::date,
      CASE WHEN v_kind = 'credit_note' AND (p_payload->>'from_profile_id') IS NULL
           THEN v_existing.to_profile_id
           ELSE (p_payload->>'from_profile_id')::bigint END,
      CASE WHEN v_kind = 'credit_note' AND (p_payload->>'to_profile_id') IS NULL
           THEN v_existing.from_profile_id
           ELSE (p_payload->>'to_profile_id')::bigint END,
      (p_payload->>'counterparty_profile_id')::bigint,
      (p_payload->>'counterparty_tenant_id')::bigint,
      CASE WHEN v_kind = 'credit_note' THEN v_existing.currency_code
           ELSE COALESCE(p_payload->>'currency_code', 'BDT') END,
      v_total, 0, v_total, 0,
      (p_payload->>'parent_bill_id')::bigint,
      v_source_entity, v_source_type, v_source_id, v_source_key, v_idem,
      v_meta,
      p_payload->>'note',
      auth.uid()
    ) RETURNING * INTO v_bill;
  EXCEPTION WHEN unique_violation THEN
    -- Concurrent create with same idempotency_key or source key
    IF v_idem IS NOT NULL THEN
      SELECT * INTO v_bill FROM money_kernel.bills
       WHERE tenant_id = v_tenant_id AND idempotency_key = v_idem AND status <> 'voided';
    END IF;
    IF v_bill.id IS NULL AND v_source_id IS NOT NULL
       AND (v_source_entity IS NOT NULL OR v_source_type IS NOT NULL) THEN
      SELECT * INTO v_bill FROM money_kernel.bills
       WHERE tenant_id = v_tenant_id
         AND source_id = v_source_id
         AND COALESCE(source_key, '') = COALESCE(v_source_key, '')
         AND status <> 'voided'
         AND (
           (v_source_entity IS NOT NULL AND source_entity IS NOT DISTINCT FROM v_source_entity)
           OR (v_source_entity IS NULL AND source_type IS NOT DISTINCT FROM v_source_type)
         );
    END IF;
    IF v_bill.id IS NULL THEN RAISE; END IF;
    RETURN jsonb_build_object(
      'bill_id', v_bill.id, 'invoice_no', v_bill.invoice_no,
      'status', v_bill.status, 'kind', v_bill.kind,
      'total_amount', v_bill.total_amount, 'due_amount', v_bill.due_amount,
      'idempotent', true
    );
  END;

  -- Insert lines in one statement
  INSERT INTO money_kernel.bill_lines (
    tenant_id, bill_id, line_no, item_kind, product_id,
    description, quantity, unit_price, line_total,
    shipment_item_id, global_stock_id, shipment_id, meta
  )
  SELECT
    v_tenant_id,
    v_bill.id,
    a.ord::int,
    COALESCE(a.elem->>'item_kind', 'stock'),
    (a.elem->>'product_id')::bigint,
    a.elem->>'description',
    COALESCE((a.elem->>'quantity')::numeric, 1),
    COALESCE((a.elem->>'unit_price')::numeric, 0),
    COALESCE(
      (a.elem->>'line_total')::numeric,
      COALESCE((a.elem->>'quantity')::numeric, 1)
        * COALESCE((a.elem->>'unit_price')::numeric, 0)
    ),
    COALESCE(
      NULLIF(a.elem->>'shipment_item_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'shipment_item_id', '')::bigint
    ),
    COALESCE(
      NULLIF(a.elem->>'global_stock_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'global_stock_id', '')::bigint,
      NULLIF(a.elem->'meta'->'stock_ref'->>'global_stock_id', '')::bigint
    ),
    COALESCE(
      NULLIF(a.elem->>'shipment_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'shipment_id', '')::bigint,
      gsi.shipment_id
    ),
    COALESCE(a.elem->'meta', '{}'::jsonb)
  FROM jsonb_array_elements(v_lines) WITH ORDINALITY AS a(elem, ord)
  LEFT JOIN public.global_shipment_items gsi
    ON gsi.id = COALESCE(
      NULLIF(a.elem->>'shipment_item_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'shipment_item_id', '')::bigint
    );

  -- Optional auto-issue
  IF (p_payload->>'auto_issue')::boolean = true AND v_registry.can_be_issued THEN
    PERFORM public.rpc_issue_bill(v_tenant_id, v_bill.id);
    SELECT * INTO v_bill FROM money_kernel.bills WHERE id = v_bill.id;
  END IF;

  RETURN jsonb_build_object(
    'bill_id', v_bill.id, 'invoice_no', v_bill.invoice_no,
    'status', v_bill.status, 'kind', v_bill.kind,
    'total_amount', v_bill.total_amount, 'due_amount', v_bill.due_amount,
    'idempotent', false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_update_draft_bill_v2(
  p_tenant_id bigint,
  p_bill_id   bigint,
  p_payload   jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_bill          money_kernel.bills;
  v_lines         jsonb;
  v_line          jsonb;
  v_total         numeric(18,4) := 0;
  v_line_total    numeric(18,4);
  v_qty           numeric(18,4);
  v_price         numeric(18,4);
  v_meta          jsonb;
  v_registry      bill_kind_registry;
BEGIN
  IF p_tenant_id IS NULL OR p_bill_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id and bill_id required';
  END IF;
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'bills');

  SELECT * INTO v_bill FROM money_kernel.bills
    WHERE id = p_bill_id AND tenant_id = p_tenant_id
    FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bill % in tenant %', p_bill_id, p_tenant_id;
  END IF;
  IF v_bill.status <> 'draft' THEN
    RAISE EXCEPTION 'invalid_state: only draft bills can be updated (got %)', v_bill.status;
  END IF;

  SELECT * INTO v_registry FROM money_kernel.bill_kind_registry
    WHERE kind = v_bill.kind AND is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_state: inactive kind %', v_bill.kind;
  END IF;

  v_lines := COALESCE(p_payload->'lines', '[]'::jsonb);
  IF jsonb_array_length(v_lines) = 0 THEN
    RAISE EXCEPTION 'invalid_arguments: lines required';
  END IF;
  FOR v_line IN SELECT * FROM jsonb_array_elements(v_lines) LOOP
    v_qty   := COALESCE((v_line->>'quantity')::numeric, 1);
    v_price := COALESCE((v_line->>'unit_price')::numeric, 0);
    v_line_total := COALESCE((v_line->>'line_total')::numeric, v_qty * v_price);
    v_total := v_total + v_line_total;
  END LOOP;

  v_meta := COALESCE(v_bill.meta, '{}'::jsonb) || COALESCE(p_payload->'meta', '{}'::jsonb);

  UPDATE money_kernel.bills
     SET invoice_date = COALESCE((p_payload->>'invoice_date')::date, invoice_date),
         due_date     = COALESCE((p_payload->>'due_date')::date, due_date),
         note         = COALESCE(p_payload->>'note', note),
         currency_code = COALESCE(NULLIF(p_payload->>'currency_code', ''), currency_code),
         from_profile_id = COALESCE((p_payload->>'from_profile_id')::bigint, from_profile_id),
         to_profile_id   = COALESCE((p_payload->>'to_profile_id')::bigint, to_profile_id),
         counterparty_profile_id = COALESCE(
           (p_payload->>'counterparty_profile_id')::bigint,
           counterparty_profile_id
         ),
         total_amount = v_total,
         due_amount   = v_total - paid_amount - written_off_amount,
         meta         = v_meta,
         updated_at   = now()
   WHERE id = p_bill_id;

  DELETE FROM money_kernel.bill_lines
   WHERE tenant_id = p_tenant_id AND bill_id = p_bill_id;

  INSERT INTO money_kernel.bill_lines (
    tenant_id, bill_id, line_no, item_kind, product_id,
    description, quantity, unit_price, line_total,
    shipment_item_id, global_stock_id, shipment_id, meta
  )
  SELECT
    p_tenant_id,
    p_bill_id,
    a.ord::int,
    COALESCE(a.elem->>'item_kind', 'charge'),
    (a.elem->>'product_id')::bigint,
    a.elem->>'description',
    COALESCE((a.elem->>'quantity')::numeric, 1),
    COALESCE((a.elem->>'unit_price')::numeric, 0),
    COALESCE(
      (a.elem->>'line_total')::numeric,
      COALESCE((a.elem->>'quantity')::numeric, 1)
        * COALESCE((a.elem->>'unit_price')::numeric, 0)
    ),
    COALESCE(
      NULLIF(a.elem->>'shipment_item_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'shipment_item_id', '')::bigint
    ),
    COALESCE(
      NULLIF(a.elem->>'global_stock_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'global_stock_id', '')::bigint,
      NULLIF(a.elem->'meta'->'stock_ref'->>'global_stock_id', '')::bigint
    ),
    COALESCE(
      NULLIF(a.elem->>'shipment_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'shipment_id', '')::bigint,
      gsi.shipment_id
    ),
    COALESCE(a.elem->'meta', '{}'::jsonb)
  FROM jsonb_array_elements(v_lines) WITH ORDINALITY AS a(elem, ord)
  LEFT JOIN public.global_shipment_items gsi
    ON gsi.id = COALESCE(
      NULLIF(a.elem->>'shipment_item_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'shipment_item_id', '')::bigint
    );

  SELECT * INTO v_bill FROM money_kernel.bills WHERE id = p_bill_id;

  RETURN jsonb_build_object(
    'bill_id', v_bill.id,
    'invoice_no', v_bill.invoice_no,
    'status', v_bill.status,
    'kind', v_bill.kind,
    'total_amount', v_bill.total_amount,
    'due_amount', v_bill.due_amount,
    'updated', true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_issue_bill(
  p_tenant_id bigint,
  p_bill_id   bigint
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
  v_bill money_kernel.bills;
  v_registry bill_kind_registry;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'bills');

  SELECT * INTO v_bill FROM money_kernel.bills
    WHERE id = p_bill_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bill % in tenant %', p_bill_id, p_tenant_id;
  END IF;

  IF v_bill.status = 'issued' THEN
    RETURN jsonb_build_object(
      'bill_id', v_bill.id, 'invoice_no', v_bill.invoice_no,
      'status', 'issued', 'idempotent', true
    );
  END IF;
  IF v_bill.status <> 'draft' THEN
    RAISE EXCEPTION 'invalid_state: cannot issue bill with status %', v_bill.status;
  END IF;
  IF v_bill.from_profile_id IS NULL OR v_bill.to_profile_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: from_profile_id and to_profile_id required before issue';
  END IF;

  SELECT * INTO v_registry FROM money_kernel.bill_kind_registry WHERE kind = v_bill.kind;
  IF NOT v_registry.can_be_issued THEN
    RAISE EXCEPTION 'invalid_state: kind % cannot be issued', v_bill.kind;
  END IF;

  IF EXISTS (
    SELECT 1
      FROM money_kernel.bill_lines bl
      LEFT JOIN public.global_shipment_items gsi ON gsi.id = bl.shipment_item_id
     WHERE bl.bill_id = p_bill_id
       AND bl.item_kind = 'stock'
       AND (
         bl.shipment_item_id IS NULL
         OR bl.global_stock_id IS NULL
         OR (
           bl.shipment_id IS NOT NULL
           AND gsi.id IS NOT NULL
           AND bl.shipment_id IS DISTINCT FROM gsi.shipment_id
         )
       )
  ) THEN
    RAISE EXCEPTION
      'invalid_arguments: stock bill lines require shipment_item_id, global_stock_id, and consistent shipment_id';
  END IF;

  UPDATE money_kernel.bills
     SET status = 'issued', updated_at = now()
   WHERE id = p_bill_id;

  RETURN jsonb_build_object(
    'bill_id', v_bill.id, 'invoice_no', v_bill.invoice_no,
    'status', 'issued', 'idempotent', false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_void_bill(
  p_tenant_id        bigint,
  p_bill_id          bigint,
  p_reason           text    DEFAULT NULL,
  p_reverse_payments boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
  v_bill money_kernel.bills;
  v_settlement    record;
  v_reversed_pays bigint[] := '{}';
  v_impact        jsonb := '[]'::jsonb;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'void');

  SELECT * INTO v_bill FROM money_kernel.bills
    WHERE id = p_bill_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bill % in tenant %', p_bill_id, p_tenant_id;
  END IF;

  IF v_bill.status = 'voided' THEN
    RETURN jsonb_build_object(
      'bill_id', p_bill_id, 'status', 'voided',
      'reversed_pays', '[]'::jsonb, 'idempotent', true
    );
  END IF;

  IF NOT p_reverse_payments AND EXISTS (
    SELECT 1 FROM money_kernel.bill_settlements
     WHERE bill_id = p_bill_id OR source_bill_id = p_bill_id
  ) THEN
    RAISE EXCEPTION
      'invalid_arguments: bill % has settlements; reverse_payments must be true',
      p_bill_id;
  END IF;

  -- Multi-bill pays: voiding this bill must not silently reverse sibling bills
  IF p_reverse_payments AND EXISTS (
    SELECT 1
      FROM money_kernel.bill_settlements bs
      JOIN money_kernel.bill_settlements other
        ON other.pays_id = bs.pays_id
       AND other.settlement_kind = 'pay'
       AND other.bill_id <> p_bill_id
     WHERE bs.bill_id = p_bill_id
       AND bs.settlement_kind = 'pay'
       AND bs.pays_id IS NOT NULL
  ) THEN
    RAISE EXCEPTION
      'invalid_arguments: bill % is on a multi-bill pays; call rpc_void_pays on that pays first',
      p_bill_id;
  END IF;

  IF p_reverse_payments THEN
    -- As target of pay/document settles
    FOR v_settlement IN
      SELECT id, settlement_kind, pays_id
        FROM money_kernel.bill_settlements
       WHERE bill_id = p_bill_id
    LOOP
      IF v_settlement.settlement_kind = 'pay' AND v_settlement.pays_id IS NOT NULL THEN
        PERFORM public.rpc_void_pays(
          p_tenant_id, v_settlement.pays_id,
          COALESCE(p_reason, 'parent bill voided')
        );
        v_reversed_pays := v_reversed_pays || v_settlement.pays_id;
      ELSIF v_settlement.settlement_kind = 'document' THEN
        PERFORM public.rpc_void_document_settlement(
          p_tenant_id, v_settlement.id,
          COALESCE(p_reason, 'parent bill voided')
        );
      END IF;
    END LOOP;
    -- As credit_note source of document settles
    FOR v_settlement IN
      SELECT id FROM money_kernel.bill_settlements
       WHERE source_bill_id = p_bill_id AND settlement_kind = 'document'
    LOOP
      PERFORM public.rpc_void_document_settlement(
        p_tenant_id, v_settlement.id,
        COALESCE(p_reason, 'credit note voided')
      );
    END LOOP;
  END IF;

  UPDATE money_kernel.bills
     SET status             = 'voided',
         due_amount         = 0,
         written_off_amount = 0,
         updated_at         = now(),
         note               = COALESCE(note, '') || E'\n[voided] ' || COALESCE(p_reason, '')
   WHERE id = p_bill_id;

  RETURN jsonb_build_object(
    'bill_id', p_bill_id, 'status', 'voided',
    'reversed_pays', to_jsonb(v_reversed_pays),
    'payments_reversed', p_reverse_payments,
    'idempotent', false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_write_off_bill(
  p_tenant_id bigint,
  p_bill_id   bigint,
  p_amount    numeric,
  p_reason    text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
  v_bill money_kernel.bills;
  v_new_due     numeric;
  v_new_written numeric;
  v_new_status  text;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'write_off');

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount: must be > 0';
  END IF;
  IF p_reason IS NULL OR length(btrim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'invalid_arguments: reason is required';
  END IF;

  SELECT * INTO v_bill FROM money_kernel.bills
    WHERE id = p_bill_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bill % in tenant %', p_bill_id, p_tenant_id;
  END IF;
  IF v_bill.status = 'voided' THEN
    RAISE EXCEPTION 'invalid_state: cannot write off voided bill %', p_bill_id;
  END IF;
  IF v_bill.kind = 'credit_note' THEN
    RAISE EXCEPTION
      'invalid_arguments: credit_note cannot be written off; void or apply it';
  END IF;
  IF p_amount > v_bill.due_amount THEN
    RAISE EXCEPTION
      'invalid_amount: write-off % exceeds due %', p_amount, v_bill.due_amount;
  END IF;

  v_new_due     := v_bill.due_amount         - p_amount;
  v_new_written := v_bill.written_off_amount + p_amount;
  v_new_status  := money_kernel.derive_bill_status(
    v_bill.total_amount, v_bill.paid_amount, v_new_due, v_new_written
  );

  UPDATE money_kernel.bills
     SET due_amount         = v_new_due,
         written_off_amount = v_new_written,
         status             = v_new_status,
         updated_at         = now(),
         meta               = COALESCE(meta, '{}'::jsonb)
                              || jsonb_build_object(
                                   'last_write_off_reason', p_reason,
                                   'last_write_off_at',     now()
                                 )
   WHERE id = p_bill_id;

  RETURN jsonb_build_object(
    'bill_id', p_bill_id, 'status', v_new_status,
    'written_off_amount', v_new_written, 'due_amount', v_new_due,
    'idempotent', false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_close_cash_bundle(
  p_tenant_id       bigint,
  p_profile_id      bigint,
  p_bundle_id       bigint,
  p_meta            jsonb DEFAULT '{}'::jsonb,
  p_idempotency_key text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_bundle money_kernel.cash_bundles;
  v_location money_kernel.cash_locations;
  v_cashbook money_kernel.cashbooks;
  v_balance numeric(18, 4);
  v_new_default bigint;
  v_withdraw jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_profile_id IS NULL OR p_bundle_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id, profile_id, and bundle_id required';
  END IF;

  PERFORM public.assert_kernel_money_access(p_tenant_id, 'withdraw');
  PERFORM public.money_kernel_assert_profile_in_tenant(p_tenant_id, p_profile_id);

  SELECT * INTO v_bundle
  FROM money_kernel.cash_bundles
  WHERE id = p_bundle_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bundle % in tenant %', p_bundle_id, p_tenant_id;
  END IF;

  IF v_bundle.closed_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'bundle_id', p_bundle_id,
      'closed_at', v_bundle.closed_at,
      'idempotent', true
    );
  END IF;

  SELECT * INTO v_location
  FROM money_kernel.cash_locations
  WHERE id = v_bundle.cash_location_id;

  SELECT * INTO v_cashbook
  FROM money_kernel.cashbooks
  WHERE id = v_location.cashbook_id;

  IF v_cashbook.profile_id IS DISTINCT FROM p_profile_id THEN
    RAISE EXCEPTION 'not_found: bundle % for profile %', p_bundle_id, p_profile_id;
  END IF;

  v_balance := coalesce(v_bundle.amount, 0);
  IF v_balance > 0 THEN
    v_withdraw := public.rpc_withdraw(
      p_tenant_id,
      p_profile_id,
      v_balance,
      v_bundle.currency_code,
      p_bundle_id,
      coalesce(p_meta, '{}'::jsonb) || jsonb_build_object('close_cash_bundle', true),
      p_idempotency_key
    );
    SELECT amount INTO v_balance
    FROM money_kernel.cash_bundles
    WHERE id = p_bundle_id;
  END IF;

  IF coalesce(v_balance, 0) > 0 THEN
    RAISE EXCEPTION 'insufficient_balance: bundle % still holds % after withdraw attempt',
      p_bundle_id, v_balance;
  END IF;

  UPDATE money_kernel.cash_bundles
  SET closed_at = now(), updated_at = now()
  WHERE id = p_bundle_id;

  IF v_cashbook.default_cash_bundle_id = p_bundle_id THEN
    SELECT pp.id INTO v_new_default
    FROM money_kernel.cash_bundles pp
    JOIN money_kernel.cash_locations pt ON pt.id = pp.cash_location_id
    WHERE pt.cashbook_id = v_cashbook.id
      AND pp.closed_at IS NULL
    ORDER BY (upper(btrim(pp.currency_code)) = upper(btrim(v_bundle.currency_code))) DESC,
             pp.id ASC
    LIMIT 1;

    UPDATE money_kernel.cashbooks
    SET default_cash_bundle_id = v_new_default, updated_at = now()
    WHERE id = v_cashbook.id;
  END IF;

  PERFORM public._desk_sync_point_currencies_from_kernel(
    p_profile_id,
    v_location.location_code
  );

  RETURN jsonb_build_object(
    'bundle_id', p_bundle_id,
    'closed_at', (SELECT closed_at FROM money_kernel.cash_bundles WHERE id = p_bundle_id),
    'withdraw', v_withdraw,
    'idempotent', false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_provision_cashbook_currency(
  p_tenant_id     bigint,
  p_profile_id    bigint,
  p_currency_code text,
  p_point_code    text DEFAULT 'main',
  p_books_rate    numeric DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_rate numeric(15,6);
  v_ccy text;
  v_account_id bigint;
  v_point_id   bigint;
  v_lot_id     bigint;
BEGIN
  v_ccy := upper(btrim(coalesce(p_currency_code, 'BDT')));

  PERFORM money_kernel.assert_kernel_money_read(p_tenant_id);

  v_account_id := public.fn_provision_kernel_cashbook_for_profile_row(p_tenant_id, p_profile_id);
  IF v_account_id IS NULL THEN
    RAISE EXCEPTION
      'not_found: cashbook for profile %; profile may not exist or cashbook_enabled=false', p_profile_id;
  END IF;

  v_lot_id := public.fn_provision_kernel_cashbook_currency(
    p_tenant_id, p_profile_id, v_ccy, p_point_code, p_books_rate
  );

  SELECT cp.id INTO v_point_id
    FROM money_kernel.cash_locations cp
   WHERE cp.cashbook_id = v_account_id AND cp.location_code = p_point_code
   LIMIT 1;

  SELECT books_rate INTO v_books_rate
    FROM money_kernel.cash_bundles
   WHERE id = v_lot_id;

  RETURN jsonb_build_object(
    'cashbook_id', v_account_id,
    'cash_location_id', v_point_id,
    'pot_id', v_lot_id,
    'currency_code', v_ccy,
    'books_rate', v_books_rate
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_provision_tenant_cashbook(
  p_tenant_id     bigint,
  p_currency_code text DEFAULT 'BDT'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
  v_account_id bigint;
  v_point_id   bigint;
  v_lot_id     bigint;
  v_profile_id bigint;
BEGIN

  v_books_rate := money_kernel.fn_resolve_books_rate(p_tenant_id, COALESCE(p_currency_code, 'BDT'));
  v_exchange_rate := 1;
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'deposit');

  SELECT pr.id INTO v_profile_id
    FROM public.profiles pr
   WHERE pr.tenant_id = p_tenant_id
     AND pr.profile_type = 'tenant'
     AND pr.subject_id = p_tenant_id
     AND pr.deleted_at IS NULL
   LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'not_found: tenant profile for tenant %', p_tenant_id;
  END IF;

  v_account_id := public.fn_provision_kernel_cashbook_for_profile_row(p_tenant_id, v_profile_id);
  v_lot_id := public.fn_provision_kernel_cashbook_currency(
    p_tenant_id, v_profile_id, COALESCE(p_currency_code, 'BDT'), 'main'
  );

  SELECT cp.id INTO v_point_id
    FROM money_kernel.cash_locations cp
   WHERE cp.cashbook_id = v_account_id AND cp.location_code = 'main'
   LIMIT 1;

  RETURN jsonb_build_object(
    'cashbook_id', v_account_id,
    'cash_location_id', v_point_id,
    'pot_id', v_lot_id,
    'currency_code', COALESCE(p_currency_code, 'BDT')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_allocate_invoice_no(
  p_tenant_id bigint,
  p_kind      text
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
  v_prefix text;
  v_seq    bigint;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  SELECT numbering_prefix INTO v_prefix FROM money_kernel.bill_kind_registry
    WHERE kind = p_kind AND is_active = true;
  IF v_prefix IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: unknown or inactive kind %', p_kind;
  END IF;

  INSERT INTO money_kernel.invoice_no_counters (tenant_id, prefix, next_seq)
    VALUES (p_tenant_id, v_prefix, 2)
  ON CONFLICT (tenant_id, prefix)
  DO UPDATE SET next_seq = money_kernel.invoice_no_counters.next_seq + 1
  RETURNING next_seq - 1 INTO v_seq;

  RETURN v_prefix || '-' || to_char(CURRENT_DATE, 'YYYYMMDD') || '-'
         || lpad(v_seq::text, 5, '0');
END;
$$;

-- rpc_deposit: use target bundle books_rate when p_pot_id set; optional p_books_rate for new FX bundles.

DROP FUNCTION IF EXISTS public.rpc_deposit(
  bigint, bigint, numeric, text, bigint, jsonb, text
);

CREATE OR REPLACE FUNCTION public.rpc_deposit(
  p_tenant_id       bigint,
  p_profile_id      bigint,
  p_amount          numeric,
  p_currency_code   text    DEFAULT 'BDT',
  p_pot_id          bigint  DEFAULT NULL,
  p_meta            jsonb   DEFAULT '{}'::jsonb,
  p_idempotency_key text    DEFAULT NULL,
  p_books_rate      numeric DEFAULT NULL
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
BEGIN
  v_exchange_rate := 1;
  v_ccy := upper(btrim(coalesce(p_currency_code, 'BDT')));
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'deposit');

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount: must be > 0';
  END IF;

  PERFORM public.money_kernel_assert_profile_in_tenant(p_tenant_id, p_profile_id);

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
        'pays_id', v_pays.id, 'kind', 'deposit', 'pot_id', v_pays.to_cash_bundle_id,
        'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
        'books_amount', v_pays.books_amount, 'balance_after', v_balance,
        'payment_date', v_pays.payment_date, 'status', v_pays.status,
        'idempotent', true
      );
    END IF;
  END IF;

  IF p_pot_id IS NOT NULL THEN
    SELECT pp.id, pp.books_rate INTO v_lot_id, v_books_rate
      FROM money_kernel.cash_bundles pp
      JOIN money_kernel.cash_locations pt ON pt.id = pp.cash_location_id
      JOIN money_kernel.cashbooks a ON a.id = pt.cashbook_id
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
      JOIN money_kernel.cash_locations cp ON cp.cashbook_id = a.id AND cp.location_code = 'main'
     WHERE a.tenant_id = p_tenant_id AND a.profile_id = p_profile_id
     LIMIT 1;
    IF v_point_id IS NULL THEN
      PERFORM public.fn_provision_kernel_cashbook_for_profile_row(p_tenant_id, p_profile_id);
      SELECT cp.id INTO v_point_id
        FROM money_kernel.cashbooks a
        JOIN money_kernel.cash_locations cp ON cp.cashbook_id = a.id AND cp.location_code = 'main'
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
      tenant_id, kind, from_cash_bundle_id, to_cash_bundle_id,
      amount, currency_code, books_amount, books_rate, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'deposit', NULL, v_lot_id,
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
      'pays_id', v_pays.id, 'kind', 'deposit', 'pot_id', v_pays.to_cash_bundle_id,
      'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
      'books_amount', v_pays.books_amount, 'balance_after', v_balance,
      'payment_date', v_pays.payment_date, 'status', v_pays.status,
      'idempotent', true
    );
  END;

  PERFORM money_kernel.fn_ensure_header_pay_bundle_lines(p_tenant_id, v_pays.id);

  SELECT amount INTO v_balance FROM money_kernel.cash_bundles WHERE id = v_lot_id;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'kind', 'deposit', 'cash_bundle_id', v_lot_id,
    'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
    'books_amount', v_pays.books_amount, 'balance_after', v_balance,
    'payment_date', v_pays.payment_date, 'status', v_pays.status,
    'idempotent', false
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_deposit(
  bigint, bigint, numeric, text, bigint, jsonb, text, numeric
) TO authenticated, service_role;

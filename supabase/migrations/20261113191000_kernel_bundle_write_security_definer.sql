-- Kernel bundle writes: SECURITY DEFINER so rpc_deposit can update cash_bundles via deferred trigger.
CREATE OR REPLACE FUNCTION money_kernel.fn_insert_pay_bundle_line(
  p_tenant_id    bigint,
  p_pay_id       bigint,
  p_direction    text,
  p_cash_bundle_id       bigint,
  p_amount       numeric,
  p_books_rate   numeric,
  p_books_amount numeric
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_id bigint;
BEGIN
  INSERT INTO money_kernel.pay_bundle_lines (
    tenant_id, pay_id, direction, cash_bundle_id, amount, books_rate, books_amount
  ) VALUES (
    p_tenant_id, p_pay_id, p_direction, p_cash_bundle_id, p_amount, p_books_rate, p_books_amount
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- Create a new lot at point (deposit / transfer credit). Returns lot id.
CREATE OR REPLACE FUNCTION money_kernel.fn_open_cash_bundle(
  p_tenant_id         bigint,
  p_cash_location_id bigint,
  p_currency_code     text,
  p_books_rate        numeric DEFAULT 1,
  p_opened_pay_id     bigint DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_id bigint;
  v_rate numeric(15, 6);
BEGIN
  v_rate := coalesce(nullif(p_books_rate, 0), 1);
  INSERT INTO money_kernel.cash_bundles (
    tenant_id, cash_location_id, currency_id, currency_code, drawer_group,
    amount, books_rate, opened_pay_id
  )
  SELECT
    p_tenant_id, p_cash_location_id, gc.id, upper(trim(p_currency_code)), '',
    0, v_rate, p_opened_pay_id
    FROM public.global_currencies gc
   WHERE gc.code = upper(trim(p_currency_code))
     AND gc.is_active = true
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_ensure_header_pay_bundle_lines(
  p_tenant_id bigint,
  p_pay_id    bigint
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_pay money_kernel.pays;
  v_credit_amt numeric(18, 4);
  v_credit_books numeric(18, 4);
BEGIN
  SELECT * INTO v_pay
    FROM money_kernel.pays
   WHERE tenant_id = p_tenant_id AND id = p_pay_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: pays %', p_pay_id;
  END IF;

  IF v_pay.from_cash_bundle_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM money_kernel.pay_bundle_lines pll
        WHERE pll.tenant_id = p_tenant_id AND pll.pay_id = p_pay_id AND pll.direction = 'debit'
     ) THEN
    PERFORM money_kernel.fn_insert_pay_bundle_line(
      p_tenant_id, p_pay_id, 'debit', v_pay.from_cash_bundle_id,
      v_pay.amount, v_pay.books_rate, v_pay.books_amount
    );
  END IF;

  IF v_pay.to_cash_bundle_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM money_kernel.pay_bundle_lines pll
        WHERE pll.tenant_id = p_tenant_id AND pll.pay_id = p_pay_id AND pll.direction = 'credit'
     ) THEN
    v_credit_amt := CASE
      WHEN v_pay.kind = 'transfer' THEN round(v_pay.amount * v_pay.exchange_rate, 4)
      ELSE v_pay.amount
    END;
    v_credit_books := CASE
      WHEN v_pay.kind = 'transfer' THEN round(v_credit_amt * v_pay.books_rate, 4)
      ELSE v_pay.books_amount
    END;
    PERFORM money_kernel.fn_insert_pay_bundle_line(
      p_tenant_id, p_pay_id, 'credit', v_pay.to_cash_bundle_id,
      v_credit_amt, v_pay.books_rate, v_credit_books
    );
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_apply_pay_bundle_debits(
  p_tenant_id  bigint,
  p_pay_id     bigint,
  p_debits     jsonb,
  p_books_rate numeric DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_elem   jsonb;
  v_lot_id bigint;
  v_amt    numeric(18, 4);
  v_rate   numeric(15, 6);
  v_lot    money_kernel.cash_bundles;
BEGIN
  IF p_debits IS NULL OR jsonb_typeof(p_debits) <> 'array' OR jsonb_array_length(p_debits) = 0 THEN
    RETURN;
  END IF;

  FOR v_elem IN SELECT value FROM jsonb_array_elements(p_debits)
  LOOP
    v_lot_id := nullif(v_elem ->> 'cash_bundle_id', '')::bigint;
    v_amt := nullif(v_elem ->> 'amount', '')::numeric;
    IF v_lot_id IS NULL OR v_amt IS NULL OR v_amt <= 0 THEN
      RAISE EXCEPTION 'invalid_lot_debit: %', v_elem;
    END IF;

    SELECT * INTO v_lot
      FROM money_kernel.cash_bundles
     WHERE id = v_lot_id AND tenant_id = p_tenant_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'not_found: lot %', v_lot_id;
    END IF;

    v_rate := coalesce(nullif(p_books_rate, 0), nullif(v_lot.books_rate, 0), 1);

    PERFORM money_kernel.fn_insert_pay_bundle_line(
      p_tenant_id,
      p_pay_id,
      'debit',
      v_lot_id,
      v_amt,
      v_rate,
      round(v_amt * v_rate, 4)
    );
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_pays_apply()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  line        record;
  v_to_credit numeric(18, 4);
  v_from_bal  numeric(18, 4);
  v_to_bal    numeric(18, 4);
  v_line_cnt  int;
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'posted' THEN
    PERFORM set_config('money.bundle_writer', '1', true);

    SELECT count(*)::int INTO v_line_cnt
      FROM money_kernel.pay_bundle_lines pll
     WHERE pll.tenant_id = NEW.tenant_id AND pll.pay_id = NEW.id;

    IF v_line_cnt > 0 THEN
      FOR line IN
        SELECT pll.direction, pll.cash_bundle_id, pll.amount, pll.tenant_id
          FROM money_kernel.pay_bundle_lines pll
         WHERE pll.tenant_id = NEW.tenant_id AND pll.pay_id = NEW.id
         ORDER BY pll.direction DESC, pll.cash_bundle_id
      LOOP
        IF line.direction = 'debit' THEN
          UPDATE money_kernel.cash_bundles
             SET amount = amount - line.amount,
                 updated_at = now()
           WHERE id = line.cash_bundle_id
             AND tenant_id = line.tenant_id
             AND amount >= line.amount;
          IF NOT FOUND THEN
            RAISE EXCEPTION
              'insufficient_balance: lot % cannot cover debit % for pays %',
              line.cash_bundle_id, line.amount, NEW.id;
          END IF;
        ELSE
          v_to_credit := line.amount;
          IF NEW.kind = 'transfer'
             AND NEW.to_cash_bundle_id IS NOT NULL
             AND line.cash_bundle_id = NEW.to_cash_bundle_id THEN
            v_to_credit := round(NEW.amount * NEW.exchange_rate, 4);
          END IF;
          UPDATE money_kernel.cash_bundles
             SET amount = amount + v_to_credit,
                 updated_at = now()
           WHERE id = line.cash_bundle_id
             AND tenant_id = line.tenant_id;
          IF NOT FOUND THEN
            RAISE EXCEPTION 'not_found: lot % for pays credit', line.cash_bundle_id;
          END IF;
        END IF;
      END LOOP;
    ELSE
      RAISE EXCEPTION 'pay_bundle_lines_required: pays % has no lot lines', NEW.id;
    END IF;

    IF NEW.from_cash_bundle_id IS NOT NULL THEN
      SELECT amount INTO v_from_bal
        FROM money_kernel.cash_bundles
       WHERE id = NEW.from_cash_bundle_id;
    END IF;
    IF NEW.to_cash_bundle_id IS NOT NULL THEN
      SELECT amount INTO v_to_bal
        FROM money_kernel.cash_bundles
       WHERE id = NEW.to_cash_bundle_id;
    END IF;

    UPDATE money_kernel.pays
       SET from_balance_after = v_from_bal,
           to_balance_after   = v_to_bal,
           updated_at         = now()
     WHERE id = NEW.id;
  END IF;

  IF TG_OP = 'UPDATE'
     AND NEW.status = 'voided'
     AND OLD.status = 'posted' THEN
    PERFORM set_config('money.bundle_writer', '1', true);

    FOR line IN
      SELECT pll.direction, pll.cash_bundle_id, pll.amount, pll.tenant_id
        FROM money_kernel.pay_bundle_lines pll
       WHERE pll.tenant_id = OLD.tenant_id AND pll.pay_id = OLD.id
       ORDER BY pll.direction, pll.cash_bundle_id
    LOOP
      IF line.direction = 'debit' THEN
        UPDATE money_kernel.cash_bundles
           SET amount = amount + line.amount,
               updated_at = now()
         WHERE id = line.cash_bundle_id AND tenant_id = line.tenant_id;
      ELSE
        v_to_credit := line.amount;
        IF OLD.kind = 'transfer'
           AND OLD.to_cash_bundle_id IS NOT NULL
           AND line.cash_bundle_id = OLD.to_cash_bundle_id THEN
          v_to_credit := round(OLD.amount * OLD.exchange_rate, 4);
        END IF;
        UPDATE money_kernel.cash_bundles
           SET amount = amount - v_to_credit,
               updated_at = now()
         WHERE id = line.cash_bundle_id
           AND tenant_id = line.tenant_id
           AND amount >= v_to_credit;
        IF NOT FOUND THEN
          RAISE EXCEPTION
            'insufficient_balance: cannot void pays %; lot % missing credit %',
            OLD.id, line.cash_bundle_id, v_to_credit;
        END IF;
      END IF;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

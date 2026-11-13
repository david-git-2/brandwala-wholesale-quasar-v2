-- Helpers attached after 27 tables (included from 27 via comment reference; merged in 27 tail).

CREATE OR REPLACE FUNCTION money_kernel.fn_ensure_header_pay_lot_lines(
  p_tenant_id bigint,
  p_pay_id    bigint
) RETURNS void
LANGUAGE plpgsql
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

  IF v_pay.from_lot_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM money_kernel.pay_lot_lines pll
        WHERE pll.tenant_id = p_tenant_id AND pll.pay_id = p_pay_id AND pll.direction = 'debit'
     ) THEN
    PERFORM money_kernel.fn_insert_pay_lot_line(
      p_tenant_id, p_pay_id, 'debit', v_pay.from_lot_id,
      v_pay.amount, v_pay.books_rate, v_pay.books_amount
    );
  END IF;

  IF v_pay.to_lot_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM money_kernel.pay_lot_lines pll
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
    PERFORM money_kernel.fn_insert_pay_lot_line(
      p_tenant_id, p_pay_id, 'credit', v_pay.to_lot_id,
      v_credit_amt, v_pay.books_rate, v_credit_books
    );
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_apply_pay_lot_debits(
  p_tenant_id  bigint,
  p_pay_id     bigint,
  p_debits     jsonb,
  p_books_rate numeric DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_elem   jsonb;
  v_lot_id bigint;
  v_amt    numeric(18, 4);
  v_rate   numeric(15, 6);
  v_lot    money_kernel.cashbook_lots;
BEGIN
  IF p_debits IS NULL OR jsonb_typeof(p_debits) <> 'array' OR jsonb_array_length(p_debits) = 0 THEN
    RETURN;
  END IF;

  FOR v_elem IN SELECT value FROM jsonb_array_elements(p_debits)
  LOOP
    v_lot_id := nullif(v_elem ->> 'lot_id', '')::bigint;
    v_amt := nullif(v_elem ->> 'amount', '')::numeric;
    IF v_lot_id IS NULL OR v_amt IS NULL OR v_amt <= 0 THEN
      RAISE EXCEPTION 'invalid_lot_debit: %', v_elem;
    END IF;

    SELECT * INTO v_lot
      FROM money_kernel.cashbook_lots
     WHERE id = v_lot_id AND tenant_id = p_tenant_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'not_found: lot %', v_lot_id;
    END IF;

    v_rate := coalesce(nullif(p_books_rate, 0), nullif(v_lot.books_rate, 0), 1);

    PERFORM money_kernel.fn_insert_pay_lot_line(
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

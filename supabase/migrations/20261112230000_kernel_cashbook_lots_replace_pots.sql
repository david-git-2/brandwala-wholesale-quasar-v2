-- cashbook_lots replace cashbook_point_pots

CREATE TABLE IF NOT EXISTS money_kernel.cashbook_lots (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id         bigint NOT NULL REFERENCES public.tenants (id),
  cashbook_point_id bigint NOT NULL REFERENCES money_kernel.cashbook_points (id) ON DELETE RESTRICT,
  currency_code     text NOT NULL DEFAULT 'BDT' REFERENCES money_kernel.currencies (code),
  amount            numeric(18, 4) NOT NULL DEFAULT 0,
  books_rate        numeric(15, 6) NOT NULL DEFAULT 1,
  opened_pay_id     bigint,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_lot_amount_non_negative CHECK (amount >= 0),
  CONSTRAINT chk_lot_books_rate_positive CHECK (books_rate > 0),
  CONSTRAINT uq_cashbook_lots_tenant_id UNIQUE (tenant_id, id)
);

CREATE INDEX IF NOT EXISTS ix_lots_point_currency
  ON money_kernel.cashbook_lots (cashbook_point_id, currency_code);
CREATE INDEX IF NOT EXISTS ix_lots_tenant ON money_kernel.cashbook_lots (tenant_id);

CREATE TABLE IF NOT EXISTS money_kernel.pay_lot_lines (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id    bigint NOT NULL REFERENCES public.tenants (id),
  pay_id       bigint NOT NULL,
  direction    text NOT NULL CHECK (direction IN ('debit', 'credit')),
  lot_id       bigint NOT NULL,
  amount       numeric(18, 4) NOT NULL CHECK (amount > 0),
  books_rate   numeric(15, 6) NOT NULL CHECK (books_rate > 0),
  books_amount numeric(18, 4) NOT NULL CHECK (books_amount >= 0),
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_pay_lot_lines_tenant_id UNIQUE (tenant_id, id)
);

CREATE INDEX IF NOT EXISTS ix_pay_lot_lines_pay ON money_kernel.pay_lot_lines (pay_id);

DO $migrate$
BEGIN
  IF to_regclass('money_kernel.cashbook_point_pots') IS NOT NULL THEN
    INSERT INTO money_kernel.cashbook_lots (
      id, tenant_id, cashbook_point_id, currency_code, amount, books_rate, created_at, updated_at
    )
    OVERRIDING SYSTEM VALUE
    SELECT
      pp.id, pp.tenant_id, pp.cashbook_point_id, pp.currency_code, pp.amount,
      1::numeric(15, 6), pp.created_at, pp.updated_at
    FROM money_kernel.cashbook_point_pots pp
    WHERE NOT EXISTS (SELECT 1 FROM money_kernel.cashbook_lots cl WHERE cl.id = pp.id);

    PERFORM setval(
      pg_get_serial_sequence('money_kernel.cashbook_lots', 'id'),
      greatest(
        coalesce((SELECT max(id) FROM money_kernel.cashbook_lots), 1),
        coalesce((SELECT max(id) FROM money_kernel.cashbook_point_pots), 1)
      )
    );

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'money_kernel' AND table_name = 'pays' AND column_name = 'from_pot_id'
    ) THEN
      ALTER TABLE money_kernel.pays DROP CONSTRAINT IF EXISTS fk_pays_from_pot;
      ALTER TABLE money_kernel.pays DROP CONSTRAINT IF EXISTS fk_pays_to_pot;
      ALTER TABLE money_kernel.pays RENAME COLUMN from_pot_id TO from_lot_id;
      ALTER TABLE money_kernel.pays RENAME COLUMN to_pot_id TO to_lot_id;
    END IF;

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'money_kernel'
        AND table_name = 'cashbook_accounts'
        AND column_name = 'default_cashbook_point_pot_id'
    ) THEN
      ALTER TABLE money_kernel.cashbook_accounts DROP CONSTRAINT IF EXISTS fk_accounts_default_pot;
      ALTER TABLE money_kernel.cashbook_accounts
        RENAME COLUMN default_cashbook_point_pot_id TO default_cashbook_lot_id;
    END IF;

    DROP TRIGGER IF EXISTS trg_tenant_id_immutable_cashbook_point_pots ON money_kernel.cashbook_point_pots;
    DROP TABLE money_kernel.cashbook_point_pots;
  END IF;
END;
$migrate$;

ALTER TABLE money_kernel.pay_lot_lines
  DROP CONSTRAINT IF EXISTS fk_pay_lot_lines_pay;
ALTER TABLE money_kernel.pay_lot_lines
  ADD CONSTRAINT fk_pay_lot_lines_pay
  FOREIGN KEY (tenant_id, pay_id)
  REFERENCES money_kernel.pays (tenant_id, id) ON DELETE CASCADE;

ALTER TABLE money_kernel.pay_lot_lines
  DROP CONSTRAINT IF EXISTS fk_pay_lot_lines_lot;
ALTER TABLE money_kernel.pay_lot_lines
  ADD CONSTRAINT fk_pay_lot_lines_lot
  FOREIGN KEY (tenant_id, lot_id)
  REFERENCES money_kernel.cashbook_lots (tenant_id, id) ON DELETE RESTRICT;

ALTER TABLE money_kernel.cashbook_accounts
  DROP CONSTRAINT IF EXISTS fk_accounts_default_pot;
ALTER TABLE money_kernel.cashbook_accounts
  DROP CONSTRAINT IF EXISTS fk_accounts_default_lot;
ALTER TABLE money_kernel.cashbook_accounts
  ADD CONSTRAINT fk_accounts_default_lot
  FOREIGN KEY (default_cashbook_lot_id)
  REFERENCES money_kernel.cashbook_lots (id);

ALTER TABLE money_kernel.pays
  DROP CONSTRAINT IF EXISTS fk_pays_from_pot;
ALTER TABLE money_kernel.pays
  DROP CONSTRAINT IF EXISTS fk_pays_from_lot;
ALTER TABLE money_kernel.pays
  ADD CONSTRAINT fk_pays_from_lot
  FOREIGN KEY (tenant_id, from_lot_id)
  REFERENCES money_kernel.cashbook_lots (tenant_id, id);

ALTER TABLE money_kernel.pays
  DROP CONSTRAINT IF EXISTS fk_pays_to_pot;
ALTER TABLE money_kernel.pays
  DROP CONSTRAINT IF EXISTS fk_pays_to_lot;
ALTER TABLE money_kernel.pays
  ADD CONSTRAINT fk_pays_to_lot
  FOREIGN KEY (tenant_id, to_lot_id)
  REFERENCES money_kernel.cashbook_lots (tenant_id, id);

CREATE OR REPLACE FUNCTION money_kernel.fn_insert_pay_lot_line(
  p_tenant_id    bigint,
  p_pay_id       bigint,
  p_direction    text,
  p_lot_id       bigint,
  p_amount       numeric,
  p_books_rate   numeric,
  p_books_amount numeric
) RETURNS bigint
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_id bigint;
BEGIN
  INSERT INTO money_kernel.pay_lot_lines (
    tenant_id, pay_id, direction, lot_id, amount, books_rate, books_amount
  ) VALUES (
    p_tenant_id, p_pay_id, p_direction, p_lot_id, p_amount, p_books_rate, p_books_amount
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- Create a new lot at point (deposit / transfer credit). Returns lot id.
CREATE OR REPLACE FUNCTION money_kernel.fn_open_cashbook_lot(
  p_tenant_id         bigint,
  p_cashbook_point_id bigint,
  p_currency_code     text,
  p_books_rate        numeric DEFAULT 1,
  p_opened_pay_id     bigint DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_id bigint;
  v_rate numeric(15, 6);
BEGIN
  v_rate := coalesce(nullif(p_books_rate, 0), 1);
  INSERT INTO money_kernel.cashbook_lots (
    tenant_id, cashbook_point_id, currency_code, amount, books_rate, opened_pay_id
  ) VALUES (
    p_tenant_id, p_cashbook_point_id, upper(trim(p_currency_code)), 0, v_rate, p_opened_pay_id
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
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
-- Lot balance apply (replaces pot apply). Requires pay_lot_lines in same txn (DEFERRED trigger).

CREATE OR REPLACE FUNCTION money_kernel.fn_lot_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.amount IS DISTINCT FROM 0 THEN
      RAISE EXCEPTION 'lot_insert_requires_zero_amount';
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.amount IS DISTINCT FROM NEW.amount THEN
    IF current_setting('money.lot_writer', true) IS DISTINCT FROM '1' THEN
      RAISE EXCEPTION
        'cashbook_lots.amount may only be modified by fn_pays_apply';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_lot_guard ON money_kernel.cashbook_lots;
CREATE TRIGGER trg_lot_guard
  BEFORE INSERT OR UPDATE OF amount ON money_kernel.cashbook_lots
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_lot_guard();

CREATE OR REPLACE FUNCTION money_kernel.fn_pays_apply()
RETURNS trigger
LANGUAGE plpgsql
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
    PERFORM set_config('money.lot_writer', '1', true);

    SELECT count(*)::int INTO v_line_cnt
      FROM money_kernel.pay_lot_lines pll
     WHERE pll.tenant_id = NEW.tenant_id AND pll.pay_id = NEW.id;

    IF v_line_cnt > 0 THEN
      FOR line IN
        SELECT pll.direction, pll.lot_id, pll.amount, pll.tenant_id
          FROM money_kernel.pay_lot_lines pll
         WHERE pll.tenant_id = NEW.tenant_id AND pll.pay_id = NEW.id
         ORDER BY pll.direction DESC, pll.lot_id
      LOOP
        IF line.direction = 'debit' THEN
          UPDATE money_kernel.cashbook_lots
             SET amount = amount - line.amount,
                 updated_at = now()
           WHERE id = line.lot_id
             AND tenant_id = line.tenant_id
             AND amount >= line.amount;
          IF NOT FOUND THEN
            RAISE EXCEPTION
              'insufficient_balance: lot % cannot cover debit % for pays %',
              line.lot_id, line.amount, NEW.id;
          END IF;
        ELSE
          v_to_credit := line.amount;
          IF NEW.kind = 'transfer'
             AND NEW.to_lot_id IS NOT NULL
             AND line.lot_id = NEW.to_lot_id THEN
            v_to_credit := round(NEW.amount * NEW.exchange_rate, 4);
          END IF;
          UPDATE money_kernel.cashbook_lots
             SET amount = amount + v_to_credit,
                 updated_at = now()
           WHERE id = line.lot_id
             AND tenant_id = line.tenant_id;
          IF NOT FOUND THEN
            RAISE EXCEPTION 'not_found: lot % for pays credit', line.lot_id;
          END IF;
        END IF;
      END LOOP;
    ELSE
      RAISE EXCEPTION 'pay_lot_lines_required: pays % has no lot lines', NEW.id;
    END IF;

    IF NEW.from_lot_id IS NOT NULL THEN
      SELECT amount INTO v_from_bal
        FROM money_kernel.cashbook_lots
       WHERE id = NEW.from_lot_id;
    END IF;
    IF NEW.to_lot_id IS NOT NULL THEN
      SELECT amount INTO v_to_bal
        FROM money_kernel.cashbook_lots
       WHERE id = NEW.to_lot_id;
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
    PERFORM set_config('money.lot_writer', '1', true);

    FOR line IN
      SELECT pll.direction, pll.lot_id, pll.amount, pll.tenant_id
        FROM money_kernel.pay_lot_lines pll
       WHERE pll.tenant_id = OLD.tenant_id AND pll.pay_id = OLD.id
       ORDER BY pll.direction, pll.lot_id
    LOOP
      IF line.direction = 'debit' THEN
        UPDATE money_kernel.cashbook_lots
           SET amount = amount + line.amount,
               updated_at = now()
         WHERE id = line.lot_id AND tenant_id = line.tenant_id;
      ELSE
        v_to_credit := line.amount;
        IF OLD.kind = 'transfer'
           AND OLD.to_lot_id IS NOT NULL
           AND line.lot_id = OLD.to_lot_id THEN
          v_to_credit := round(OLD.amount * OLD.exchange_rate, 4);
        END IF;
        UPDATE money_kernel.cashbook_lots
           SET amount = amount - v_to_credit,
               updated_at = now()
         WHERE id = line.lot_id
           AND tenant_id = line.tenant_id
           AND amount >= v_to_credit;
        IF NOT FOUND THEN
          RAISE EXCEPTION
            'insufficient_balance: cannot void pays %; lot % missing credit %',
            OLD.id, line.lot_id, v_to_credit;
        END IF;
      END IF;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pays_apply ON money_kernel.pays;
CREATE CONSTRAINT TRIGGER trg_pays_apply
  AFTER INSERT OR UPDATE OF status ON money_kernel.pays
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_pays_apply();

CREATE OR REPLACE FUNCTION money_kernel.fn_validate_default_lot()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  IF NEW.default_cashbook_lot_id IS NOT NULL THEN
    PERFORM 1
      FROM money_kernel.cashbook_lots cl
      JOIN money_kernel.cashbook_points pt ON pt.id = cl.cashbook_point_id
     WHERE cl.id = NEW.default_cashbook_lot_id
       AND pt.cashbook_account_id = NEW.id;
    IF NOT FOUND THEN
      RAISE EXCEPTION
        'default_cashbook_lot_id % does not belong to account %',
        NEW.default_cashbook_lot_id, NEW.id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_default_pot ON money_kernel.cashbook_accounts;
DROP TRIGGER IF EXISTS trg_validate_default_lot ON money_kernel.cashbook_accounts;
CREATE TRIGGER trg_validate_default_lot
  BEFORE INSERT OR UPDATE OF default_cashbook_lot_id
  ON money_kernel.cashbook_accounts
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_validate_default_lot();

CREATE TRIGGER trg_tenant_id_immutable_cashbook_lots
  BEFORE UPDATE OF tenant_id ON money_kernel.cashbook_lots
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_tenant_id_immutable();

-- backfill lines
INSERT INTO money_kernel.pay_lot_lines (
  tenant_id, pay_id, direction, lot_id, amount, books_rate, books_amount
)
SELECT p.tenant_id, p.id, 'debit', p.from_lot_id, p.amount, p.books_rate, p.books_amount
FROM money_kernel.pays p
WHERE p.from_lot_id IS NOT NULL AND p.status = 'posted'
  AND NOT EXISTS (
    SELECT 1 FROM money_kernel.pay_lot_lines pll
    WHERE pll.pay_id = p.id AND pll.direction = 'debit'
  );

INSERT INTO money_kernel.pay_lot_lines (
  tenant_id, pay_id, direction, lot_id, amount, books_rate, books_amount
)
SELECT p.tenant_id, p.id, 'credit', p.to_lot_id,
  CASE WHEN p.kind = 'transfer' THEN round(p.amount * p.exchange_rate, 4) ELSE p.amount END,
  p.books_rate,
  CASE WHEN p.kind = 'transfer' THEN round(p.amount * p.exchange_rate * p.books_rate, 4) ELSE p.books_amount END
FROM money_kernel.pays p
WHERE p.to_lot_id IS NOT NULL AND p.status = 'posted'
  AND NOT EXISTS (
    SELECT 1 FROM money_kernel.pay_lot_lines pll
    WHERE pll.pay_id = p.id AND pll.direction = 'credit'
  );

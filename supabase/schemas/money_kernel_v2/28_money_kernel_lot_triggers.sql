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

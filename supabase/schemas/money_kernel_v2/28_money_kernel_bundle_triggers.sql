-- Lot balance apply (replaces pot apply). Requires pay_bundle_lines in same txn (DEFERRED trigger).

DROP TRIGGER IF EXISTS trg_lot_guard ON money_kernel.cash_bundles;
DROP TRIGGER IF EXISTS trg_pot_guard ON money_kernel.cash_bundles;
DROP FUNCTION IF EXISTS money_kernel.fn_lot_guard();

CREATE OR REPLACE FUNCTION money_kernel.fn_bundle_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.amount IS DISTINCT FROM 0 THEN
      RAISE EXCEPTION 'bundle_insert_requires_zero_amount';
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.amount IS DISTINCT FROM NEW.amount THEN
    IF current_setting('money.bundle_writer', true) IS DISTINCT FROM '1' THEN
      RAISE EXCEPTION
        'cash_bundles.amount may only be modified by fn_pays_apply';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bundle_guard ON money_kernel.cash_bundles;
CREATE TRIGGER trg_bundle_guard
  BEFORE INSERT OR UPDATE OF amount ON money_kernel.cash_bundles
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_bundle_guard();

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

DROP TRIGGER IF EXISTS trg_pays_apply ON money_kernel.pays;
CREATE CONSTRAINT TRIGGER trg_pays_apply
  AFTER INSERT OR UPDATE OF status ON money_kernel.pays
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_pays_apply();

CREATE OR REPLACE FUNCTION money_kernel.fn_validate_default_bundle()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  IF NEW.default_cash_bundle_id IS NOT NULL THEN
    PERFORM 1
      FROM money_kernel.cash_bundles cl
      JOIN money_kernel.cash_locations loc ON loc.id = cl.cash_location_id
     WHERE cl.id = NEW.default_cash_bundle_id
       AND loc.cashbook_id = NEW.id;
    IF NOT FOUND THEN
      RAISE EXCEPTION
        'default_cash_bundle_id % does not belong to account %',
        NEW.default_cash_bundle_id, NEW.id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_default_pot ON money_kernel.cashbooks;
DROP TRIGGER IF EXISTS trg_validate_default_lot ON money_kernel.cashbooks;
DROP FUNCTION IF EXISTS money_kernel.fn_validate_default_lot();
DROP TRIGGER IF EXISTS trg_validate_default_bundle ON money_kernel.cashbooks;
CREATE TRIGGER trg_validate_default_bundle
  BEFORE INSERT OR UPDATE OF default_cash_bundle_id
  ON money_kernel.cashbooks
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_validate_default_bundle();

DROP TRIGGER IF EXISTS trg_tenant_id_immutable_cashbook_lots ON money_kernel.cash_bundles;
DROP TRIGGER IF EXISTS trg_tenant_id_immutable_cash_bundles ON money_kernel.cash_bundles;
CREATE TRIGGER trg_tenant_id_immutable_cash_bundles
  BEFORE UPDATE OF tenant_id ON money_kernel.cash_bundles
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_tenant_id_immutable();

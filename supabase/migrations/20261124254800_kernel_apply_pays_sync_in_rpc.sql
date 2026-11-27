-- Apply posted kernel pays synchronously inside multi-step RPCs (skip deferred trigger mid-txn).

CREATE OR REPLACE FUNCTION money_kernel.apply_posted_pay_bundle(
  p_tenant_id bigint,
  p_pay_id    bigint
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_pay money_kernel.pays;
  line record;
  v_line_cnt int;
  v_to_credit numeric(18, 4);
  v_from_bal numeric(18, 4);
  v_to_bal numeric(18, 4);
BEGIN
  SELECT * INTO v_pay
  FROM money_kernel.pays
  WHERE tenant_id = p_tenant_id AND id = p_pay_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: pays % in tenant %', p_pay_id, p_tenant_id;
  END IF;

  IF v_pay.status <> 'posted' THEN
    RETURN;
  END IF;

  IF v_pay.from_balance_after IS NOT NULL OR v_pay.to_balance_after IS NOT NULL THEN
    RETURN;
  END IF;

  PERFORM money_kernel.fn_ensure_header_pay_bundle_lines(p_tenant_id, p_pay_id);

  SELECT count(*)::int INTO v_line_cnt
  FROM money_kernel.pay_bundle_lines pll
  WHERE pll.tenant_id = p_tenant_id
    AND pll.pay_id = p_pay_id;

  IF v_line_cnt = 0 THEN
    RAISE EXCEPTION
      'pay_bundle_lines_required: pays % kind % from_bundle % to_bundle % has no lot lines after ensure',
      v_pay.id, v_pay.kind, v_pay.from_cash_bundle_id, v_pay.to_cash_bundle_id;
  END IF;

  PERFORM set_config('money.bundle_writer', '1', true);

  FOR line IN
    SELECT pll.direction, pll.cash_bundle_id, pll.amount, pll.tenant_id
    FROM money_kernel.pay_bundle_lines pll
    WHERE pll.tenant_id = p_tenant_id AND pll.pay_id = p_pay_id
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
          'insufficient_balance: bundle % cannot cover debit % for pays %',
          line.cash_bundle_id, line.amount, p_pay_id;
      END IF;
    ELSE
      v_to_credit := line.amount;
      IF v_pay.kind = 'transfer'
         AND v_pay.to_cash_bundle_id IS NOT NULL
         AND line.cash_bundle_id = v_pay.to_cash_bundle_id THEN
        v_to_credit := round(v_pay.amount * v_pay.exchange_rate, 4);
      END IF;
      UPDATE money_kernel.cash_bundles
      SET amount = amount + v_to_credit,
          updated_at = now()
      WHERE id = line.cash_bundle_id
        AND tenant_id = line.tenant_id;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'not_found: bundle % for pays % credit', line.cash_bundle_id, p_pay_id;
      END IF;
    END IF;
  END LOOP;

  IF v_pay.from_cash_bundle_id IS NOT NULL THEN
    SELECT amount INTO v_from_bal
    FROM money_kernel.cash_bundles
    WHERE id = v_pay.from_cash_bundle_id;
  END IF;
  IF v_pay.to_cash_bundle_id IS NOT NULL THEN
    SELECT amount INTO v_to_bal
    FROM money_kernel.cash_bundles
    WHERE id = v_pay.to_cash_bundle_id;
  END IF;

  UPDATE money_kernel.pays
  SET
    from_balance_after = v_from_bal,
    to_balance_after = v_to_bal,
    updated_at = now()
  WHERE id = p_pay_id AND tenant_id = p_tenant_id;
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.flush_deferred_pays()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT p.tenant_id, p.id
    FROM money_kernel.pays p
    WHERE p.status = 'posted'
      AND p.from_balance_after IS NULL
      AND p.to_balance_after IS NULL
    ORDER BY p.id
  LOOP
    PERFORM money_kernel.apply_posted_pay_bundle(r.tenant_id, r.id);
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
    IF NEW.from_balance_after IS NOT NULL OR NEW.to_balance_after IS NOT NULL THEN
      RETURN NEW;
    END IF;

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
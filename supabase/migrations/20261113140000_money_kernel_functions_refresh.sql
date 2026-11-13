-- Refresh money kernel functions after rename cutover (declarative source).
-- Money spine v2 — internal helpers, access control, shared write utilities.

CREATE OR REPLACE FUNCTION public.auth_tenant_id()
RETURNS bigint
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.tenant_id', true), '')::bigint;
$$;

CREATE OR REPLACE FUNCTION money_kernel.membership_has_money_action(
  p_uid       uuid,
  p_tenant_id bigint,
  p_action    text
) RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_module text;
  v_grant  text;
BEGIN
  CASE p_action
    WHEN 'deposit' THEN v_module := 'payments'; v_grant := 'collect_payment';
    WHEN 'withdraw' THEN v_module := 'payments'; v_grant := 'collect_payment';
    WHEN 'transfer' THEN v_module := 'payments'; v_grant := 'allocate_payment';
    WHEN 'pay' THEN v_module := 'payments'; v_grant := 'allocate_payment';
    WHEN 'void' THEN v_module := 'payments'; v_grant := 'void';
    WHEN 'write_off' THEN v_module := 'global_invoice'; v_grant := 'edit';
    WHEN 'fx_override' THEN v_module := 'payments'; v_grant := 'allocate_payment';
    WHEN 'bills' THEN v_module := 'global_invoice'; v_grant := 'edit';
    ELSE RETURN false;
  END CASE;
  RETURN public.membership_has_module_action(p_tenant_id, v_module, v_grant);
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.profile_spend_allowed(
  p_uid       uuid,
  p_tenant_id bigint,
  p_profile_id bigint
) RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.profiles pr
     WHERE pr.id = p_profile_id
       AND pr.tenant_id = p_tenant_id
       AND pr.deleted_at IS NULL
       AND pr.is_active = true
  );
$$;

CREATE OR REPLACE FUNCTION public.assert_kernel_money_access(
  p_tenant_id   bigint,
  p_action      text DEFAULT 'pay',
  p_profile_id  bigint DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF p_tenant_id IS NULL OR p_action IS NULL THEN
    RAISE EXCEPTION 'access_denied: invalid_arguments';
  END IF;

  IF v_uid IS NULL THEN
    IF current_setting('request.jwt.claim.role', true) = 'service_role' THEN
      RETURN;
    END IF;
    RAISE EXCEPTION 'access_denied: not_authenticated';
  END IF;

  IF NOT money_kernel.membership_has_money_action(v_uid, p_tenant_id, p_action) THEN
    RAISE EXCEPTION 'access_denied: tenant % action %', p_tenant_id, p_action;
  END IF;

  IF p_profile_id IS NOT NULL
     AND p_action IN ('withdraw', 'transfer', 'pay')
     AND NOT money_kernel.profile_spend_allowed(v_uid, p_tenant_id, p_profile_id) THEN
    RAISE EXCEPTION 'access_denied: profile %', p_profile_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_assert_idem_match(
  p_existing_hash text,
  p_request_hash  text
) RETURNS void
LANGUAGE plpgsql
IMMUTABLE
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  IF p_existing_hash IS NOT NULL
     AND p_request_hash IS NOT NULL
     AND p_existing_hash IS DISTINCT FROM p_request_hash THEN
    RAISE EXCEPTION 'idempotency_conflict: request_hash mismatch';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_resolve_books_rate(
  p_tenant_id     bigint,
  p_currency_code text,
  p_allow_override boolean DEFAULT false,
  p_override_rate  numeric DEFAULT NULL
) RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_rate numeric(15, 6);
  v_code text := upper(btrim(p_currency_code));
BEGIN
  IF v_code = 'BDT' THEN
    RETURN 1;
  END IF;

  IF p_allow_override AND p_override_rate IS NOT NULL AND p_override_rate > 0 THEN
    IF NOT money_kernel.membership_has_money_action(auth.uid(), p_tenant_id, 'fx_override') THEN
      RAISE EXCEPTION 'access_denied: fx_override required';
    END IF;
    RETURN p_override_rate;
  END IF;

  SELECT r.rate INTO v_rate
    FROM public.books_exchange_rates r
   WHERE r.tenant_id = p_tenant_id
     AND upper(r.quote_currency_code) = v_code
     AND upper(r.base_currency_code) = 'BDT'
   ORDER BY r.rate_date DESC NULLS LAST, r.id DESC
   LIMIT 1;

  IF v_rate IS NULL OR v_rate <= 0 THEN
    RAISE EXCEPTION 'not_found: books rate for %', v_code;
  END IF;
  RETURN v_rate;
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_resolve_transfer_rate(
  p_from_currency text,
  p_to_currency   text,
  p_tenant_id     bigint
) RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_from text := upper(btrim(p_from_currency));
  v_to   text := upper(btrim(p_to_currency));
  v_from_bdt numeric;
  v_to_bdt   numeric;
BEGIN
  IF v_from = v_to THEN
    RETURN 1;
  END IF;
  v_from_bdt := money_kernel.fn_resolve_books_rate(p_tenant_id, v_from);
  v_to_bdt := money_kernel.fn_resolve_books_rate(p_tenant_id, v_to);
  RETURN round(v_from_bdt / v_to_bdt, 6);
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_tenant_payment_date(p_tenant_id bigint)
RETURNS date
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT (now() AT TIME ZONE public._document_number_tenant_timezone(p_tenant_id, 'Asia/Dhaka'))::date;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_post_pays(p_row money_kernel.pays)
RETURNS money_kernel.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_row money_kernel.pays;
BEGIN
  UPDATE money_kernel.pays
     SET status = 'posted',
         updated_at = now()
   WHERE id = p_row.id
     AND tenant_id = p_row.tenant_id
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_kernel_settlement_delete_allowed()
RETURNS void
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  PERFORM set_config('money.allow_kernel_delete', '1', true);
  PERFORM set_config('money.allow_settlement_delete', '1', true);
END;
$$;

-- Bill parties use public.profiles.id; provision kernel cashbook for that profile.
CREATE OR REPLACE FUNCTION money_kernel.ensure_profile_for_public_party(
  p_books_tenant_id bigint,
  p_public_profile_id bigint
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, money_kernel, pg_temp
AS $$
BEGIN
  PERFORM public.money_kernel_assert_profile_in_tenant(p_books_tenant_id, p_public_profile_id);
  PERFORM public.fn_provision_kernel_cashbook_for_profile_row(p_books_tenant_id, p_public_profile_id);
  RETURN p_public_profile_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.money_kernel_assert_profile_in_tenant(
  p_books_tenant_id bigint,
  p_profile_id bigint
)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_profile_id IS NULL THEN
    RAISE EXCEPTION 'not_found: profile required';
  END IF;
  PERFORM 1
  FROM public.profiles pr
  WHERE pr.id = p_profile_id
    AND pr.tenant_id = p_books_tenant_id
    AND pr.deleted_at IS NULL
    AND pr.is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: profile % in tenant %', p_profile_id, p_books_tenant_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_provision_kernel_cashbook_for_profile_row(
  p_books_tenant_id bigint,
  p_profile_id bigint
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_account_id bigint;
  v_point_id   bigint;
  v_lot_id     bigint;
BEGIN
  IF p_books_tenant_id IS NULL OR p_profile_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT ca.id INTO v_account_id
  FROM money_kernel.cashbooks ca
  WHERE ca.tenant_id = p_books_tenant_id
    AND ca.profile_id = p_profile_id
  LIMIT 1;

  IF v_account_id IS NULL THEN
    INSERT INTO money_kernel.cashbooks (tenant_id, profile_id)
    VALUES (p_books_tenant_id, p_profile_id)
    RETURNING id INTO v_account_id;
  END IF;

  SELECT cp.id INTO v_point_id
  FROM money_kernel.cash_locations cp
  WHERE cp.cashbook_id = v_account_id
    AND cp.location_code = 'main'
  LIMIT 1;

  IF v_point_id IS NULL THEN
    INSERT INTO money_kernel.cash_locations
      (tenant_id, cashbook_id, location_code, name)
    VALUES
      (p_books_tenant_id, v_account_id, 'main', 'Main')
    RETURNING id INTO v_point_id;
  END IF;

  SELECT pp.id INTO v_lot_id
  FROM money_kernel.cash_bundles pp
  WHERE pp.cash_location_id = v_point_id
    AND pp.currency_code = 'BDT'
    AND pp.books_rate = 1
  ORDER BY pp.id
  LIMIT 1;

  IF v_lot_id IS NULL THEN
    v_lot_id := money_kernel.fn_open_cash_bundle(
      p_books_tenant_id, v_point_id, 'BDT', 1::numeric(15, 6), NULL
    );
  END IF;

  UPDATE money_kernel.cashbooks
     SET default_cash_bundle_id = coalesce(default_cash_bundle_id, v_lot_id)
   WHERE id = v_account_id;

  RETURN v_account_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_provision_kernel_cashbook_currency(
  p_books_tenant_id bigint,
  p_profile_id    bigint,
  p_currency_code text,
  p_point_code    text DEFAULT 'main'
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_ccy text;
  v_account_id bigint;
  v_point_id   bigint;
  v_lot_id     bigint;
BEGIN
  IF p_books_tenant_id IS NULL OR p_profile_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_ccy := upper(trim(coalesce(p_currency_code, 'BDT')));
  IF v_ccy = '' THEN
    v_ccy := 'BDT';
  END IF;

  v_account_id := public.fn_provision_kernel_cashbook_for_profile_row(p_books_tenant_id, p_profile_id);
  IF v_account_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT cp.id INTO v_point_id
  FROM money_kernel.cash_locations cp
  WHERE cp.cashbook_id = v_account_id
    AND cp.location_code = p_point_code
  LIMIT 1;

  IF v_point_id IS NULL THEN
    INSERT INTO money_kernel.cash_locations
      (tenant_id, cashbook_id, location_code, name)
    VALUES
      (p_books_tenant_id, v_account_id, p_point_code, initcap(p_point_code))
    RETURNING id INTO v_point_id;
  END IF;

  v_lot_id := money_kernel.fn_open_cash_bundle(
    p_books_tenant_id, v_point_id, v_ccy, 1::numeric(15, 6), NULL
  );

  RETURN v_lot_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_provision_kernel_cashbook_for_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, money_kernel, pg_temp
AS $$
BEGIN
  IF NEW.is_active IS DISTINCT FROM true OR NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;
  IF coalesce(NEW.cashbook_enabled, true) THEN
    PERFORM public.fn_provision_kernel_cashbook_for_profile_row(NEW.tenant_id, NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_provision_kernel_cashbook_for_profile ON public.profiles;
CREATE TRIGGER trg_provision_kernel_cashbook_for_profile
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_provision_kernel_cashbook_for_profile();

CREATE OR REPLACE FUNCTION money_kernel.validate_bill_source_plug(
  p_source_entity text,
  p_source_type   text,
  p_source_id     text,
  p_source_key    text
) RETURNS void
LANGUAGE plpgsql
STABLE
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_entity text := nullif(btrim(p_source_entity), '');
  v_type   text := nullif(btrim(p_source_type), '');
  v_id     text := nullif(btrim(p_source_id), '');
  v_key    text := nullif(btrim(p_source_key), '');
BEGIN
  IF v_entity IS NULL AND v_type IS NULL AND v_id IS NULL AND v_key IS NULL THEN
    RETURN;
  END IF;

  IF v_entity IS NULL AND (v_id IS NOT NULL OR v_key IS NOT NULL) THEN
    RAISE EXCEPTION 'invalid_arguments: source_entity required when source_id or source_key is set';
  END IF;

  IF v_entity IS NOT NULL AND v_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: source_id required when source_entity is set';
  END IF;

  IF v_entity IS NOT NULL
     AND v_entity !~ '^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$' THEN
    RAISE EXCEPTION
      'invalid_arguments: source_entity % must be schema.table (e.g. public.global_shipments)',
      v_entity;
  END IF;

  IF v_id IS NOT NULL AND v_id ~ '^\d+$' AND v_id::bigint <= 0 THEN
    RAISE EXCEPTION 'invalid_arguments: source_id must be a positive id';
  END IF;
END;
$$;
-- Helpers attached after 27 tables (included from 27 via comment reference; merged in 27 tail).

CREATE OR REPLACE FUNCTION money_kernel.fn_ensure_header_pay_bundle_lines(
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
-- Lot balance apply (replaces pot apply). Requires pay_bundle_lines in same txn (DEFERRED trigger).

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
-- Money spine v2 write RPCs (from 02-actions.md)

CREATE OR REPLACE FUNCTION public.rpc_deposit(
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
  v_lot_id   bigint;
  v_point_id bigint;
  v_balance numeric(18,4);
  v_books   numeric(18,4);
BEGIN

  v_books_rate := money_kernel.fn_resolve_books_rate(p_tenant_id, COALESCE(p_currency_code, 'BDT'));
  v_exchange_rate := 1;
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'deposit');

  -- Validation
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount: must be > 0';
  END IF;
  IF v_books_rate IS NULL OR v_books_rate <= 0 THEN
    RAISE EXCEPTION 'invalid_rate: books_rate must be > 0';
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
        'pays_id', v_pays.id, 'kind', 'deposit', 'pot_id', v_pays.to_cash_bundle_id,
        'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
        'books_amount', v_pays.books_amount, 'balance_after', v_balance,
        'payment_date', v_pays.payment_date, 'status', v_pays.status,
        'idempotent', true
      );
    END IF;
  END IF;

  -- Destination lot: explicit id, or open a new FX lot on Main at resolved books_rate.
  IF p_pot_id IS NOT NULL THEN
    SELECT pp.id INTO v_lot_id
      FROM money_kernel.cash_bundles pp
      JOIN money_kernel.cash_locations    pt ON pt.id = pp.cash_location_id
      JOIN money_kernel.cashbooks  a  ON a.id  = pt.cashbook_id
     WHERE pp.id = p_pot_id AND pp.currency_code = p_currency_code
       AND a.tenant_id = p_tenant_id AND a.profile_id = p_profile_id;
    IF v_lot_id IS NULL THEN
      RAISE EXCEPTION
        'not_found: lot % valid for profile % in %', p_pot_id, p_profile_id, p_currency_code;
    END IF;
    PERFORM 1 FROM money_kernel.cash_bundles WHERE id = v_lot_id FOR UPDATE;
  ELSE
    SELECT cp.id INTO v_point_id
      FROM money_kernel.cashbooks a
      JOIN money_kernel.cash_locations cp ON cp.cashbook_id = a.id AND cp.location_code = 'main'
     WHERE a.tenant_id = p_tenant_id AND a.a.profile_id = p_profile_id
     LIMIT 1;
    IF v_point_id IS NULL THEN
      PERFORM public.fn_provision_kernel_cashbook_for_profile_row(p_tenant_id, p_profile_id);
      SELECT cp.id INTO v_point_id
        FROM money_kernel.cashbooks a
        JOIN money_kernel.cash_locations cp ON cp.cashbook_id = a.id AND cp.location_code = 'main'
       WHERE a.tenant_id = p_tenant_id AND a.a.profile_id = p_profile_id
       LIMIT 1;
    END IF;
    v_lot_id := money_kernel.fn_open_cash_bundle(
      p_tenant_id,
      v_point_id,
      p_currency_code,
      v_books_rate,
      NULL
    );
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
      tenant_id, kind, from_cash_bundle_id, to_cash_bundle_id,
      amount, currency_code, books_amount, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'withdrawal', v_lot_id, NULL,
      p_amount, p_currency_code, v_books, 1,
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

  v_books_rate := money_kernel.fn_resolve_books_rate(p_tenant_id, 'BDT');
  v_exchange_rate := 1;
  PERFORM public.assert_kernel_money_access(p_tenant_id);

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

CREATE OR REPLACE FUNCTION public.rpc_provision_cashbook_currency(
  p_tenant_id     bigint,
  p_profile_id    bigint,
  p_currency_code text,
  p_point_code    text DEFAULT 'main'
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
BEGIN

  v_books_rate := money_kernel.fn_resolve_books_rate(p_tenant_id, COALESCE(p_currency_code, 'BDT'));
  v_exchange_rate := 1;
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'deposit');

  v_account_id := public.fn_provision_kernel_cashbook_for_profile_row(p_tenant_id, p_profile_id);
  IF v_account_id IS NULL THEN
    RAISE EXCEPTION
      'not_found: cashbook for profile %; profile may not exist or cashbook_enabled=false', p_profile_id;
  END IF;

  v_lot_id := public.fn_provision_kernel_cashbook_currency(
    p_tenant_id, p_profile_id, p_currency_code, p_point_code
  );

  SELECT cp.id INTO v_point_id
    FROM money_kernel.cash_locations cp
   WHERE cp.cashbook_id = v_account_id AND cp.location_code = p_point_code
   LIMIT 1;

  RETURN jsonb_build_object(
    'cashbook_id', v_account_id,
    'cash_location_id', v_point_id,
    'pot_id', v_lot_id,
    'currency_code', p_currency_code
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
-- Money spine v2 read RPCs + views

CREATE OR REPLACE FUNCTION public.rpc_get_bill(
  p_tenant_id bigint,
  p_bill_id   bigint,
  p_include   text[] DEFAULT '{lines}'
    -- any subset of: lines | settlements | events | meta_expanded
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_bill money_kernel.bills;
  v_result     jsonb;
  v_lines      jsonb;
  v_settlements jsonb;
  v_events     jsonb;
  v_meta_exp   jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_bill_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id and bill_id are required';
  END IF;

  SELECT * INTO v_bill FROM money_kernel.bills
    WHERE id = p_bill_id AND tenant_id = p_tenant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bill % in tenant %', p_bill_id, p_tenant_id;
  END IF;

  -- Core bill fields (always present)
  v_result := jsonb_build_object(
    'bill_id',                 v_bill.id,
    'tenant_id',               v_bill.tenant_id,
    'kind',                    v_bill.kind,
    'status',                  v_bill.status,
    'invoice_no',              v_bill.invoice_no,
    'invoice_date',            v_bill.invoice_date,
    'due_date',                v_bill.due_date,
    'from_profile_id',         v_bill.from_profile_id,
    'to_profile_id',           v_bill.to_profile_id,
    'counterparty_profile_id', v_bill.counterparty_profile_id,
    'counterparty_tenant_id',  v_bill.counterparty_tenant_id,
    'currency_code',           v_bill.currency_code,
    'total_amount',            v_bill.total_amount,
    'paid_amount',             v_bill.paid_amount,
    'due_amount',              v_bill.due_amount,
    'written_off_amount',      v_bill.written_off_amount,
    'parent_bill_id',          v_bill.parent_bill_id,
    'source_entity',           v_bill.source_entity,
    'source_type',             v_bill.source_type,
    'source_id',               v_bill.source_id,
    'source_key',              v_bill.source_key,
    'note',                    v_bill.note,
    'meta',                    v_bill.meta,
    'created_by',              v_bill.created_by,
    'created_at',              v_bill.created_at,
    'updated_at',              v_bill.updated_at
  );

  -- Lines
  IF 'lines' = ANY(p_include) THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'id',          bl.id,
      'line_no',     bl.line_no,
      'item_kind',   bl.item_kind,
      'product_id',  bl.product_id,
      'description', bl.description,
      'quantity',    bl.quantity,
      'unit_price',  bl.unit_price,
      'line_total',        bl.line_total,
      'shipment_item_id',  bl.shipment_item_id,
      'global_stock_id',   bl.global_stock_id,
      'shipment_id',       bl.shipment_id,
      'meta',              bl.meta
    ) ORDER BY bl.line_no), '[]'::jsonb)
    INTO v_lines
    FROM money_kernel.bill_lines bl WHERE bl.bill_id = p_bill_id;

    v_result := v_result || jsonb_build_object('lines', v_lines);
  END IF;

  -- Settlements (payments applied)
  IF 'settlements' = ANY(p_include) THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'settlement_id',          bs.id,
      'settlement_kind',        bs.settlement_kind,
      'pays_id',                bs.pays_id,
      'source_bill_id',         bs.source_bill_id,
      'allocated_amount',       bs.allocated_amount,
      'allocated_books_amount', bs.allocated_books_amount,
      'payment_date',           p.payment_date,
      'payment_kind',           p.kind,
      'payment_status',         p.status,
      'payment_amount',         p.amount,
      'payment_currency',       p.currency_code,
      'from_cash_bundle_id',            p.from_cash_bundle_id,
      'to_cash_bundle_id',              p.to_cash_bundle_id,
      'payment_meta',           p.meta,
      'settled_at',             bs.created_at
    ) ORDER BY bs.created_at DESC), '[]'::jsonb)
    INTO v_settlements
    FROM money_kernel.bill_settlements bs
    LEFT JOIN money_kernel.pays p ON p.id = bs.pays_id
    WHERE bs.bill_id = p_bill_id;

    v_result := v_result || jsonb_build_object('settlements', v_settlements);
  END IF;

  -- Events (lifecycle)
  IF 'events' = ANY(p_include) THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'event_id',   be.id,
      'event_type', be.event_type,
      'payload',    be.payload,
      'actor_id',   be.actor_id,
      'created_at', be.created_at
    ) ORDER BY be.created_at DESC, be.id DESC), '[]'::jsonb)
    INTO v_events
    FROM money_kernel.bill_events be WHERE be.bill_id = p_bill_id;

    v_result := v_result || jsonb_build_object('events', v_events);
  END IF;

  -- Meta expanded: raw meta + well-known keys extracted for typed access
  IF 'meta_expanded' = ANY(p_include) THEN
    v_meta_exp := jsonb_build_object(
      'raw', v_bill.meta,
      'well_known', jsonb_build_object(
        'shipment_id',          (v_bill.meta->>'shipment_id')::bigint,
        'ap_kind',              v_bill.meta->>'ap_kind',
        'original_bill_id',     (v_bill.meta->>'original_bill_id')::bigint,
        'retail_billing_mode',  v_bill.meta->>'retail_billing_mode',
        'reason',               v_bill.meta->>'reason'
      )
    );
    v_result := v_result || jsonb_build_object('meta_expanded', v_meta_exp);
  END IF;

  RETURN v_result || jsonb_build_object('echoed_filters', jsonb_build_object(
    'tenant_id', p_tenant_id,
    'bill_id',   p_bill_id,
    'include',   to_jsonb(p_include)
  ));
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_query_bills(
  p_tenant_id          bigint,
  p_kinds              text[]      DEFAULT NULL,
  p_statuses           text[]      DEFAULT NULL,
  p_source_type        text        DEFAULT NULL,
  p_source_id          text        DEFAULT NULL,
  p_source_key         text        DEFAULT NULL,
  p_counterparty_profile_id  bigint  DEFAULT NULL,
  p_counterparty_tenant_id   bigint  DEFAULT NULL,
  p_parent_bill_id     bigint      DEFAULT NULL,
  p_invoice_no         text        DEFAULT NULL,
  p_from_date          date        DEFAULT NULL,
  p_to_date            date        DEFAULT NULL,
  p_due_before         date        DEFAULT NULL,
  p_has_due            boolean     DEFAULT NULL,
  p_changed_since      timestamptz DEFAULT NULL,
  p_include_voided     boolean     DEFAULT false,
  p_include            text[]      DEFAULT '{summary}',
    -- any subset of: summary | lines | settlements | events
  p_group_by           text        DEFAULT NULL,
    -- NULL (rows) | kind | status | counterparty | month  (groups: no cursor; full agg)
  p_order_by           text        DEFAULT 'invoice_date DESC, id DESC',
  p_limit              int         DEFAULT 50,
  p_cursor             jsonb       DEFAULT NULL
    -- {"k": "...", "id": 123}; null = first page
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_order_mode text;
  v_result     jsonb;
  v_rows       jsonb;
  v_groups     jsonb;
  v_filters    jsonb;
  v_has_more   boolean := false;
  v_next       jsonb := NULL;
  v_cursor_id  bigint;
  v_cursor_k   text;
  v_include_lines        boolean := 'lines'       = ANY(p_include);
  v_include_settlements  boolean := 'settlements' = ANY(p_include);
  v_include_events       boolean := 'events'      = ANY(p_include);
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id required';
  END IF;
  IF p_limit < 1 OR p_limit > 500 THEN
    RAISE EXCEPTION 'invalid_arguments: limit must be 1..500';
  END IF;
  IF p_group_by IS NULL
     AND (v_include_lines OR v_include_settlements OR v_include_events)
     AND p_limit > 50 THEN
    RAISE EXCEPTION 'invalid_arguments: heavy includes require limit <= 50';
  END IF;
  IF p_group_by IS NOT NULL AND p_group_by NOT IN ('kind','status','counterparty','month') THEN
    RAISE EXCEPTION
      'invalid_arguments: group_by must be kind/status/counterparty/month, got %', p_group_by;
  END IF;
  IF p_cursor IS NOT NULL AND (p_cursor ? 'id') IS NOT TRUE THEN
    RAISE EXCEPTION 'invalid_arguments: cursor requires id';
  END IF;

  v_order_mode := CASE
    WHEN p_order_by LIKE '%created_at%'   THEN 'created_at'
    WHEN p_order_by LIKE '%updated_at%'   THEN 'updated_at'
    WHEN p_order_by LIKE '%due_date%'     THEN 'due_date'
    WHEN p_order_by LIKE '%total_amount%' THEN 'total_amount'
    WHEN p_order_by LIKE '%due_amount%'   THEN 'due_amount'
    ELSE 'invoice_date'
  END;

  IF p_cursor IS NOT NULL THEN
    v_cursor_id := (p_cursor->>'id')::bigint;
    v_cursor_k  := p_cursor->>'k';
    IF v_cursor_id IS NULL OR v_cursor_k IS NULL THEN
      RAISE EXCEPTION 'invalid_arguments: cursor requires k and id';
    END IF;
  END IF;

  -- Rows mode (cursor keyset)
  IF p_group_by IS NULL THEN
    WITH filtered AS (
      SELECT b.*
      FROM money_kernel.bills b
      WHERE b.tenant_id = p_tenant_id
        AND (p_kinds IS NULL OR b.kind = ANY(p_kinds))
        AND (p_statuses IS NULL OR b.status = ANY(p_statuses))
        AND (p_include_voided OR b.status <> 'voided')
        AND (p_source_type IS NULL OR b.source_type = p_source_type)
        AND (p_source_id IS NULL OR b.source_id = p_source_id)
        AND (p_source_key IS NULL OR b.source_key = p_source_key)
        AND (p_counterparty_profile_id IS NULL OR b.counterparty_profile_id = p_counterparty_profile_id)
        AND (p_counterparty_tenant_id IS NULL OR b.counterparty_tenant_id = p_counterparty_tenant_id)
        AND (p_parent_bill_id IS NULL OR b.parent_bill_id = p_parent_bill_id)
        AND (p_invoice_no IS NULL
             OR b.invoice_no = p_invoice_no
             OR b.invoice_no ILIKE p_invoice_no || '%')
        AND (p_from_date IS NULL OR b.invoice_date >= p_from_date)
        AND (p_to_date IS NULL OR b.invoice_date <= p_to_date)
        AND (p_due_before IS NULL OR (b.due_amount > 0 AND b.due_date <= p_due_before))
        AND (p_has_due IS NULL OR
             (p_has_due = true  AND b.due_amount > 0) OR
             (p_has_due = false AND b.due_amount = 0))
        AND (p_changed_since IS NULL OR b.updated_at > p_changed_since)
        AND (
          p_cursor IS NULL
          OR CASE v_order_mode
               WHEN 'invoice_date' THEN
                 (b.invoice_date, b.id) < (v_cursor_k::date, v_cursor_id)
               WHEN 'created_at' THEN
                 (b.created_at, b.id) < (v_cursor_k::timestamptz, v_cursor_id)
               WHEN 'updated_at' THEN
                 (b.updated_at, b.id) < (v_cursor_k::timestamptz, v_cursor_id)
               WHEN 'due_date' THEN
                 (b.due_date, b.id) < (v_cursor_k::date, v_cursor_id)
               WHEN 'total_amount' THEN
                 (b.total_amount, b.id) < (v_cursor_k::numeric, v_cursor_id)
               WHEN 'due_amount' THEN
                 (b.due_amount, b.id) < (v_cursor_k::numeric, v_cursor_id)
             END
        )
      ORDER BY
        CASE v_order_mode WHEN 'invoice_date'  THEN b.invoice_date  END DESC NULLS LAST,
        CASE v_order_mode WHEN 'created_at'    THEN b.created_at    END DESC NULLS LAST,
        CASE v_order_mode WHEN 'updated_at'    THEN b.updated_at    END DESC NULLS LAST,
        CASE v_order_mode WHEN 'due_date'      THEN b.due_date      END DESC NULLS LAST,
        CASE v_order_mode WHEN 'total_amount'  THEN b.total_amount  END DESC NULLS LAST,
        CASE v_order_mode WHEN 'due_amount'    THEN b.due_amount    END DESC NULLS LAST,
        b.id DESC
      LIMIT p_limit + 1
    ),
    page_rows AS (
      SELECT f.*, row_number() OVER () AS _rn
        FROM filtered f
       LIMIT p_limit
    )
    SELECT
      (SELECT count(*) > p_limit FROM filtered),
      COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'bill_id',                 b.id,
          'tenant_id',               b.tenant_id,
          'kind',                    b.kind,
          'status',                  b.status,
          'invoice_no',              b.invoice_no,
          'invoice_date',            b.invoice_date,
          'due_date',                b.due_date,
          'counterparty_profile_id', b.counterparty_profile_id,
          'counterparty_tenant_id',  b.counterparty_tenant_id,
          'currency_code',           b.currency_code,
          'total_amount',            b.total_amount,
          'paid_amount',             b.paid_amount,
          'due_amount',              b.due_amount,
          'written_off_amount',      b.written_off_amount,
          'parent_bill_id',          b.parent_bill_id,
          'source_entity',           b.source_entity,
          'source_type',             b.source_type,
          'source_id',               b.source_id,
          'source_key',              b.source_key,
          'note',                    b.note,
          'meta',                    b.meta,
          'created_at',              b.created_at,
          'updated_at',              b.updated_at,
          'lines', CASE WHEN v_include_lines THEN COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
              'id', bl.id, 'line_no', bl.line_no, 'item_kind', bl.item_kind,
              'product_id', bl.product_id, 'description', bl.description,
              'quantity', bl.quantity, 'unit_price', bl.unit_price,
              'line_total', bl.line_total,
              'shipment_item_id', bl.shipment_item_id,
              'global_stock_id', bl.global_stock_id,
              'shipment_id', bl.shipment_id,
              'meta', bl.meta
            ) ORDER BY bl.line_no)
            FROM money_kernel.bill_lines bl WHERE bl.bill_id = b.id
          ), '[]'::jsonb) ELSE NULL END,
          'settlements', CASE WHEN v_include_settlements THEN COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
              'settlement_id', bs.id,
              'pays_id', bs.pays_id,
              'allocated_amount', bs.allocated_amount,
              'payment_date', p.payment_date,
              'payment_status', p.status
            ) ORDER BY bs.created_at DESC)
            FROM money_kernel.bill_settlements bs
            LEFT JOIN money_kernel.pays p ON p.id = bs.pays_id
            WHERE bs.bill_id = b.id
          ), '[]'::jsonb) ELSE NULL END,
          'events', CASE WHEN v_include_events THEN COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
              'event_id', be.id, 'event_type', be.event_type,
              'payload', be.payload, 'created_at', be.created_at
            ) ORDER BY be.created_at DESC)
            FROM money_kernel.bill_events be WHERE be.bill_id = b.id
          ), '[]'::jsonb) ELSE NULL END
        ) ORDER BY
          CASE v_order_mode WHEN 'invoice_date' THEN b.invoice_date END DESC NULLS LAST,
          CASE v_order_mode WHEN 'created_at'   THEN b.created_at   END DESC NULLS LAST,
          CASE v_order_mode WHEN 'updated_at'   THEN b.updated_at   END DESC NULLS LAST,
          CASE v_order_mode WHEN 'due_date'     THEN b.due_date     END DESC NULLS LAST,
          CASE v_order_mode WHEN 'total_amount' THEN b.total_amount END DESC NULLS LAST,
          CASE v_order_mode WHEN 'due_amount'   THEN b.due_amount   END DESC NULLS LAST,
          b.id DESC
        )
        FROM page_rows b
      ), '[]'::jsonb),
      (
        SELECT CASE v_order_mode
          WHEN 'invoice_date'  THEN jsonb_build_object('k', b.invoice_date::text,  'id', b.id)
          WHEN 'created_at'    THEN jsonb_build_object('k', b.created_at::text,    'id', b.id)
          WHEN 'updated_at'    THEN jsonb_build_object('k', b.updated_at::text,    'id', b.id)
          WHEN 'due_date'      THEN jsonb_build_object('k', b.due_date::text,      'id', b.id)
          WHEN 'total_amount'  THEN jsonb_build_object('k', b.total_amount::text,  'id', b.id)
          WHEN 'due_amount'    THEN jsonb_build_object('k', b.due_amount::text,    'id', b.id)
        END
        FROM page_rows b
        WHERE b._rn = (SELECT max(_rn) FROM page_rows)
      )
    INTO v_has_more, v_rows, v_next;

    IF NOT v_has_more THEN v_next := NULL; END IF;

    v_result := jsonb_build_object(
      'rows',         v_rows,
      'limit',        p_limit,
      'has_more',     v_has_more,
      'next_cursor',  v_next
    );

  -- Group mode: full aggregation (no cursor / no totals envelope)
  ELSE
    WITH filtered AS (
      SELECT b.*
      FROM money_kernel.bills b
      WHERE b.tenant_id = p_tenant_id
        AND (p_kinds IS NULL OR b.kind = ANY(p_kinds))
        AND (p_statuses IS NULL OR b.status = ANY(p_statuses))
        AND (p_include_voided OR b.status <> 'voided')
        AND (p_source_type IS NULL OR b.source_type = p_source_type)
        AND (p_source_id IS NULL OR b.source_id = p_source_id)
        AND (p_source_key IS NULL OR b.source_key = p_source_key)
        AND (p_counterparty_profile_id IS NULL OR b.counterparty_profile_id = p_counterparty_profile_id)
        AND (p_counterparty_tenant_id IS NULL OR b.counterparty_tenant_id = p_counterparty_tenant_id)
        AND (p_parent_bill_id IS NULL OR b.parent_bill_id = p_parent_bill_id)
        AND (p_invoice_no IS NULL
             OR b.invoice_no = p_invoice_no
             OR b.invoice_no ILIKE p_invoice_no || '%')
        AND (p_from_date IS NULL OR b.invoice_date >= p_from_date)
        AND (p_to_date IS NULL OR b.invoice_date <= p_to_date)
        AND (p_due_before IS NULL OR (b.due_amount > 0 AND b.due_date <= p_due_before))
        AND (p_has_due IS NULL OR
             (p_has_due = true  AND b.due_amount > 0) OR
             (p_has_due = false AND b.due_amount = 0))
        AND (p_changed_since IS NULL OR b.updated_at > p_changed_since)
    ),
    grouped AS (
      SELECT
        CASE p_group_by
          WHEN 'kind'         THEN b.kind
          WHEN 'status'       THEN b.status
          WHEN 'counterparty' THEN COALESCE(b.counterparty_profile_id::text,
                                            b.counterparty_tenant_id::text,
                                            '(none)')
          WHEN 'month'        THEN to_char(b.invoice_date, 'YYYY-MM')
        END AS group_key,
        COUNT(*)                                      AS cnt,
        COALESCE(SUM(b.total_amount),       0)::numeric(18,4) AS sum_total,
        COALESCE(SUM(b.paid_amount),        0)::numeric(18,4) AS sum_paid,
        COALESCE(SUM(b.due_amount),         0)::numeric(18,4) AS sum_due,
        COALESCE(SUM(b.written_off_amount), 0)::numeric(18,4) AS sum_written_off
      FROM filtered b
      GROUP BY 1
    )
    SELECT COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'key',              g.group_key,
        'count',            g.cnt,
        'sum_total_amount', g.sum_total,
        'sum_paid_amount',  g.sum_paid,
        'sum_due_amount',   g.sum_due,
        'sum_written_off_amount', g.sum_written_off
      ) ORDER BY g.group_key ASC NULLS LAST)
      FROM grouped g
    ), '[]'::jsonb)
    INTO v_groups;

    v_result := jsonb_build_object(
      'groups',   v_groups,
      'group_by', p_group_by
    );
  END IF;

  v_filters := jsonb_build_object(
    'tenant_id',            p_tenant_id,
    'kinds',                p_kinds,
    'statuses',             p_statuses,
    'source_type',          p_source_type,
    'source_id',            p_source_id,
    'source_key',           p_source_key,
    'counterparty_profile_id', p_counterparty_profile_id,
    'counterparty_tenant_id',  p_counterparty_tenant_id,
    'parent_bill_id',       p_parent_bill_id,
    'invoice_no',           p_invoice_no,
    'from_date',            p_from_date,
    'to_date',              p_to_date,
    'due_before',           p_due_before,
    'has_due',              p_has_due,
    'changed_since',        p_changed_since,
    'include_voided',       p_include_voided,
    'include',              to_jsonb(p_include),
    'group_by',             p_group_by,
    'order_by',             p_order_by,
    'limit',                p_limit,
    'cursor',               p_cursor
  );

  RETURN v_result || jsonb_build_object('echoed_filters', v_filters);
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_get_pot_balance(
  p_tenant_id    bigint,
  p_pot_id       bigint  DEFAULT NULL,
  p_entity_type  text    DEFAULT NULL,
  p_entity_id    bigint  DEFAULT NULL,
  p_currency     text    DEFAULT 'BDT'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_pot     money_kernel.cash_bundles;
  v_account money_kernel.cashbooks;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id required';
  END IF;

  IF p_pot_id IS NOT NULL THEN
    -- Lookup by pot id
    SELECT pp.* INTO v_pot
      FROM money_kernel.cash_bundles pp
      WHERE pp.id = p_pot_id AND pp.tenant_id = p_tenant_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'not_found: pot % in tenant %', p_pot_id, p_tenant_id;
    END IF;

    -- Resolve entity for the response
    SELECT a.* INTO v_account
      FROM money_kernel.cash_locations pt
      JOIN money_kernel.cashbooks a ON a.id = pt.cashbook_id
     WHERE pt.id = v_pot.cash_location_id;

  ELSIF p_entity_type IS NOT NULL AND p_entity_id IS NOT NULL THEN
    -- Lookup by entity + currency (uses default pot pointer first)
    SELECT pp.* INTO v_pot
      FROM money_kernel.cashbooks a
      LEFT JOIN money_kernel.cash_bundles pp_default
        ON pp_default.id = a.default_cash_bundle_id
      JOIN money_kernel.cash_locations pt ON pt.cashbook_id = a.id
      JOIN money_kernel.cash_bundles pp ON pp.cash_location_id = pt.id
     WHERE a.tenant_id = p_tenant_id
       AND p_entity_type = 'profile'
       AND a.profile_id = p_entity_id
       AND pp.currency_code = p_currency
     ORDER BY (a.default_cash_bundle_id = pp.id) DESC, pp.id ASC
     LIMIT 1;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'not_found: no % pot for entity %/%', p_currency, p_entity_type, p_entity_id;
    END IF;

    SELECT * INTO v_account FROM money_kernel.cashbooks
      WHERE tenant_id = p_tenant_id AND profile_id = p_entity_id;

  ELSE
    RAISE EXCEPTION
      'invalid_arguments: must pass pot_id OR (entity_type AND entity_id)';
  END IF;

  RETURN jsonb_build_object(
    'pot_id',          v_pot.id,
    'tenant_id',       v_pot.tenant_id,
    'cash_location_id', v_pot.cash_location_id,
    'profile_id',      v_account.profile_id,
    'currency_code',   v_pot.currency_code,
    'amount',          v_pot.amount,
    'updated_at',      v_pot.updated_at,
    'echoed_filters',  jsonb_build_object(
      'pot_id',      p_pot_id,
      'entity_type', p_entity_type,
      'entity_id',   p_entity_id,
      'currency',    p_currency
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_get_pot_balances(
  p_tenant_id    bigint,
  p_entity_type  text    DEFAULT 'profile',
  p_entity_ids   bigint[] DEFAULT NULL,
  p_currencies   text[]  DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_rows jsonb;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id required';
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'pot_id',        pp.id,
    'profile_id',    a.profile_id,
    'currency_code', pp.currency_code,
    'amount',        pp.amount,
    'updated_at',    pp.updated_at
  ) ORDER BY a.profile_id, pp.currency_code), '[]'::jsonb)
  INTO v_rows
  FROM money_kernel.cash_bundles pp
  JOIN money_kernel.cash_locations   pt ON pt.id = pp.cash_location_id
  JOIN money_kernel.cashbooks a  ON a.id  = pt.cashbook_id
  WHERE pp.tenant_id = p_tenant_id
    AND (p_entity_type IS NULL OR p_entity_type = 'profile')
    AND (p_entity_ids IS NULL OR a.profile_id = ANY(p_entity_ids))
    AND (p_currencies IS NULL OR pp.currency_code = ANY(p_currencies));

  RETURN jsonb_build_object(
    'rows',           v_rows,
    'count',          jsonb_array_length(v_rows),
    'echoed_filters', jsonb_build_object(
      'tenant_id',   p_tenant_id,
      'entity_type', p_entity_type,
      'entity_ids',  p_entity_ids,
      'currencies',  p_currencies
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_profile_transactions(
  p_tenant_id        bigint,
  p_profile_id       bigint,
  p_from_date        date    DEFAULT NULL,
  p_to_date          date    DEFAULT NULL,
  p_kind             text    DEFAULT NULL,
  p_currency_code    text    DEFAULT NULL,
  p_pot_id           bigint  DEFAULT NULL,
  p_bill_id          bigint  DEFAULT NULL,
  p_include_voided   boolean DEFAULT false,
  p_limit            int     DEFAULT 20,
  p_cursor           jsonb   DEFAULT NULL
    -- {"created_at":"...","pays_id":N,"direction":"in"|"out"}
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_result jsonb;
  v_c_at   timestamptz;
  v_c_pays bigint;
  v_c_dir  text;
BEGIN
  IF p_tenant_id IS NULL OR p_profile_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id and profile_id required';
  END IF;
  IF p_limit < 1 OR p_limit > 500 THEN
    RAISE EXCEPTION 'invalid_arguments: limit must be 1..500';
  END IF;
  IF p_from_date IS NOT NULL AND p_to_date IS NOT NULL AND p_from_date > p_to_date THEN
    RAISE EXCEPTION 'invalid_arguments: from_date must be <= to_date';
  END IF;
  IF p_cursor IS NOT NULL THEN
    v_c_at   := (p_cursor->>'created_at')::timestamptz;
    v_c_pays := (p_cursor->>'pays_id')::bigint;
    v_c_dir  := p_cursor->>'direction';
    IF v_c_at IS NULL OR v_c_pays IS NULL OR v_c_dir IS NULL THEN
      RAISE EXCEPTION 'invalid_arguments: cursor requires created_at, pays_id, direction';
    END IF;
  END IF;

  PERFORM public.money_kernel_assert_profile_in_tenant(p_tenant_id, p_profile_id);

  WITH my_pots AS (
    SELECT pp.id AS pot_id, pp.currency_code, pp.amount AS current_balance
      FROM money_kernel.cash_bundles pp
      JOIN money_kernel.cash_locations    pt ON pt.id = pp.cash_location_id
      JOIN money_kernel.cashbooks  a  ON a.id  = pt.cashbook_id
     WHERE a.tenant_id = p_tenant_id
       AND a.profile_id = p_profile_id
       AND (p_pot_id IS NULL OR pp.id = p_pot_id)
       AND (p_currency_code IS NULL OR pp.currency_code = p_currency_code)
  ),
  legs AS (
    SELECT p.id AS pays_id, p.kind, p.payment_date, p.created_at,
           mp.pot_id, mp.currency_code AS pot_currency, mp.current_balance,
           p.books_amount, p.exchange_rate, p.refs, p.meta, p.status,
           'out'::text AS direction,
           p.amount           AS leg_amount,
           -p.amount          AS signed_amount,
           CASE WHEN p.status = 'posted' THEN -p.amount ELSE 0 END AS signed_for_balance,
           p.to_cash_bundle_id        AS other_pot_id
      FROM money_kernel.pays p
      JOIN my_pots mp ON mp.pot_id = p.from_cash_bundle_id
     WHERE p.tenant_id = p_tenant_id
       AND p.from_cash_bundle_id IS NOT NULL
       AND (p_include_voided OR p.status = 'posted')
       AND (p_from_date IS NULL OR p.payment_date >= p_from_date)
       AND (p_to_date   IS NULL OR p.payment_date <= p_to_date)
       AND (p_kind      IS NULL OR p.kind = p_kind)
       AND (p_bill_id   IS NULL OR EXISTS (
         SELECT 1 FROM money_kernel.bill_settlements bs
          WHERE bs.pays_id = p.id AND bs.bill_id = p_bill_id))

    UNION ALL

    SELECT p.id, p.kind, p.payment_date, p.created_at,
           mp.pot_id, mp.currency_code, mp.current_balance,
           p.books_amount, p.exchange_rate, p.refs, p.meta, p.status,
           'in'::text,
           CASE WHEN p.kind = 'transfer' THEN p.amount * p.exchange_rate ELSE p.amount END,
           CASE WHEN p.kind = 'transfer' THEN p.amount * p.exchange_rate ELSE p.amount END,
           CASE WHEN p.status = 'posted'
                THEN (CASE WHEN p.kind = 'transfer'
                           THEN p.amount * p.exchange_rate ELSE p.amount END)
                ELSE 0 END,
           p.from_cash_bundle_id
      FROM money_kernel.pays p
      JOIN my_pots mp ON mp.pot_id = p.to_cash_bundle_id
     WHERE p.tenant_id = p_tenant_id
       AND p.to_cash_bundle_id IS NOT NULL
       AND (p_include_voided OR p.status = 'posted')
       AND (p_from_date IS NULL OR p.payment_date >= p_from_date)
       AND (p_to_date   IS NULL OR p.payment_date <= p_to_date)
       AND (p_kind      IS NULL OR p.kind = p_kind)
       AND (p_bill_id   IS NULL OR EXISTS (
         SELECT 1 FROM money_kernel.bill_settlements bs
          WHERE bs.pays_id = p.id AND bs.bill_id = p_bill_id))
  ),
  with_balance AS MATERIALIZED (
    SELECT l.*,
           l.current_balance - COALESCE(
             SUM(l.signed_for_balance) OVER (
               PARTITION BY l.pot_id
               ORDER BY l.created_at DESC, l.pays_id DESC, l.direction DESC
               ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
             ), 0
           ) AS balance_after
      FROM legs l
  ),
  filtered AS (
    SELECT *
      FROM with_balance wb
     WHERE p_cursor IS NULL
        OR (wb.created_at, wb.pays_id, wb.direction)
             < (v_c_at, v_c_pays, v_c_dir)
     ORDER BY created_at DESC, pays_id DESC, direction DESC
     LIMIT p_limit + 1
  ),
  page_rows AS (
    SELECT f.*, row_number() OVER () AS _rn
      FROM filtered f
     LIMIT p_limit
  )
  SELECT jsonb_build_object(
    'profile_id',  p_profile_id,
    'limit',       p_limit,
    'has_more',    (SELECT count(*) > p_limit FROM filtered),
    'next_cursor', CASE
      WHEN (SELECT count(*) > p_limit FROM filtered) THEN (
        SELECT jsonb_build_object(
          'created_at', b.created_at,
          'pays_id',    b.pays_id,
          'direction',  b.direction
        )
        FROM page_rows b
        WHERE b._rn = (SELECT max(_rn) FROM page_rows)
      )
      ELSE NULL
    END,
    'balances', jsonb_build_object(
      'by_pot', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'pot_id', pot_id, 'currency', currency_code, 'balance', current_balance
        ) ORDER BY pot_id)
        FROM my_pots
      ), '[]'::jsonb),
      'by_currency', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'currency', currency_code, 'balance', SUM(current_balance)
        ) ORDER BY currency_code)
        FROM my_pots GROUP BY currency_code
      ), '[]'::jsonb)
    ),
    'transactions', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'pays_id',       pd.pays_id,
        'kind',          pd.kind,
        'payment_date',  pd.payment_date,
        'created_at',    pd.created_at,
        'status',        pd.status,
        'direction',     pd.direction,
        'signed_amount', pd.signed_amount,
        'leg_amount',    pd.leg_amount,
        'pot_id',        pd.pot_id,
        'pot_currency',  pd.pot_currency,
        'balance_after', pd.balance_after,
        'books_amount',  pd.books_amount,
        'exchange_rate', pd.exchange_rate,
        'other_side', CASE
          WHEN pd.other_pot_id IS NULL
            THEN jsonb_build_object('kind', 'external')
          ELSE (
            SELECT jsonb_build_object(
              'pot_id',   pp.id,
              'currency', pp.currency_code,
              'kind',     a.entity_type,
              'id',       a.entity_id,
              'name',     COALESCE(pr.name, t.name, a.entity_type)
            )
            FROM money_kernel.cash_bundles pp
            JOIN money_kernel.cash_locations    pt ON pt.id = pp.cash_location_id
            JOIN money_kernel.cashbooks  a  ON a.id  = pt.cashbook_id
            LEFT JOIN public.profiles      pr ON pr.id = a.profile_id AND pr.tenant_id = a.tenant_id
            LEFT JOIN public.tenants       t  ON t.id = a.profile_id AND pr.profile_type = 'tenant'
            WHERE pp.id = pd.other_pot_id
          )
        END,
        'refs', pd.refs,
        'meta', pd.meta
      ) ORDER BY pd.created_at DESC, pd.pays_id DESC, pd.direction DESC)
      FROM page_rows pd
    ), '[]'::jsonb),
    'echoed_filters', jsonb_build_object(
      'tenant_id',      p_tenant_id,
      'profile_id',     p_profile_id,
      'from_date',      p_from_date,
      'to_date',        p_to_date,
      'kind',           p_kind,
      'currency_code',  p_currency_code,
      'pot_id',         p_pot_id,
      'bill_id',        p_bill_id,
      'include_voided', p_include_voided,
      'limit',          p_limit,
      'cursor',         p_cursor
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_list_bill_kinds()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN
  RETURN jsonb_build_object(
    'kinds', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'kind',             r.kind,
        'numbering_prefix', r.numbering_prefix,
        'default_status',   r.default_status,
        'can_be_issued',    r.can_be_issued,
        'can_be_paid',      r.can_be_paid,
        'required_meta',    to_jsonb(r.required_meta),
        'description',      r.description,
        'is_active',        r.is_active
      ) ORDER BY r.kind)
      FROM money_kernel.bill_kind_registry r
      WHERE r.is_active = true
    ), '[]'::jsonb),
    'count', (SELECT COUNT(*) FROM money_kernel.bill_kind_registry WHERE is_active = true)
  );
END;
$$;

-- Deprecated: use public.list_global_currencies(). Kept for desk cutover callers.
CREATE OR REPLACE FUNCTION public.list_money_kernel_currencies()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id',          c.id,
        'code',        c.code,
        'minor_units', c.minor_units,
        'name',        c.name,
        'symbol',      c.symbol,
        'country',     c.country
      )
      ORDER BY c.code
    ),
    '[]'::jsonb
  )
  FROM public.global_currencies c
  WHERE c.is_active = true;
$$;

DROP VIEW IF EXISTS public.v_bills_unified;
CREATE VIEW public.v_bills_unified
  WITH (security_invoker = true)
AS
SELECT
  b.id                                       AS bill_id,
  b.tenant_id,
  b.kind,
  b.status,
  b.invoice_no,
  b.invoice_date,
  b.due_date,
  b.from_profile_id,
  b.to_profile_id,
  b.counterparty_profile_id,
  b.counterparty_tenant_id,
  b.currency_code,
  b.total_amount,
  b.paid_amount,
  b.due_amount,
  b.written_off_amount,
  b.parent_bill_id,
  b.source_entity,
  b.source_type,
  b.source_id,
  b.source_key,
  b.meta,
  b.note,
  b.created_by,
  b.created_at,
  b.updated_at,

  -- Derived helpers (stable semantics — additions allowed, changes not)
  CASE WHEN b.due_amount > 0 THEN true ELSE false END       AS has_due,
  CASE WHEN b.status = 'voided' THEN true ELSE false END    AS is_voided
FROM money_kernel.bills b;

DROP VIEW IF EXISTS public.v_bill_lines_unified;
CREATE VIEW public.v_bill_lines_unified
  WITH (security_invoker = true)
AS
SELECT
  bl.id                         AS line_id,
  bl.bill_id,
  b.tenant_id,
  b.kind                        AS bill_kind,
  b.status                      AS bill_status,
  b.invoice_no,
  b.invoice_date,
  b.due_date,
  b.counterparty_profile_id,
  b.counterparty_tenant_id,
  b.currency_code               AS bill_currency_code,
  b.source_entity,
  b.source_type,
  b.source_id,
  b.source_key,

  bl.line_no,
  bl.item_kind,
  bl.product_id,
  bl.description,
  bl.quantity,
  bl.unit_price,
  bl.line_total,
  bl.shipment_item_id,
  bl.global_stock_id,
  bl.shipment_id,
  bl.meta                       AS line_meta,
  bl.created_at                 AS line_created_at,

  CASE WHEN (bl.meta ? 'assigned_child_tenant_id')
       THEN (bl.meta->>'assigned_child_tenant_id')::bigint
       ELSE NULL END            AS assigned_child_tenant_id,
  CASE WHEN (bl.meta ? 'barcode')
       THEN bl.meta->>'barcode'
       ELSE NULL END            AS barcode,

  b.meta                        AS bill_meta
FROM money_kernel.bill_lines bl
JOIN money_kernel.bills b ON b.id = bl.bill_id;

CREATE OR REPLACE VIEW public.v_bill_events
  WITH (security_invoker = true)
AS
SELECT
  e.id           AS event_id,
  e.tenant_id,
  e.bill_id,
  b.kind         AS bill_kind,
  b.invoice_no,
  b.status       AS bill_status_current,
  e.event_type,
  e.payload,
  e.actor_id,
  e.created_at
FROM money_kernel.bill_events e
JOIN money_kernel.bills b ON b.id = e.bill_id;

DROP VIEW IF EXISTS public.v_pot_balances;

CREATE OR REPLACE VIEW public.v_pot_balances
  WITH (security_invoker = true)
AS
SELECT
  pp.id                AS pot_id,
  pp.tenant_id,
  a.id                 AS cashbook_id,
  a.profile_id,
  pt.id                AS cash_location_id,
  pt.location_code              AS point_code,
  pt.name              AS point_name,
  pp.currency_code,
  pp.amount,
  pp.created_at,
  pp.updated_at,
  (a.default_cash_bundle_id = pp.id) AS is_default_lot,
  COALESCE(pr.name, t.name, 'profile') AS entity_name,
  pr.profile_type,
  pr.phone,
  pr.email,
  COALESCE(cnt.pots_in_account, 0) AS pots_in_account
FROM money_kernel.cash_bundles pp
JOIN money_kernel.cash_locations pt    ON pt.id = pp.cash_location_id
JOIN money_kernel.cashbooks a   ON a.id  = pt.cashbook_id
LEFT JOIN public.profiles pr      ON pr.id = a.profile_id AND pr.tenant_id = a.tenant_id
LEFT JOIN public.tenants  t       ON t.id = pr.subject_id AND pr.profile_type = 'tenant'
LEFT JOIN (
  SELECT pt2.cashbook_id, COUNT(*) AS pots_in_account
  FROM money_kernel.cash_locations pt2
  JOIN money_kernel.cash_bundles pp2 ON pp2.cash_location_id = pt2.id
  GROUP BY pt2.cashbook_id
) cnt ON cnt.cashbook_id = a.id;

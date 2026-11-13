-- Money spine v2 — kernel triggers and helpers
-- Spec: docs/features/bills/spec.md + grep this folder for DDL
-- Requires: 20_money_kernel_schema.sql, 21_money_kernel_tables.sql
--
-- Deployment order (this file):
--   1. derive_bill_status
--   2. T1–T8 (fn_* + trg_*)
--   3. S1–S6
--   4. G1
--   5. D1 (constraint trigger)

-- ---------------------------------------------------------------------------
-- derive_bill_status (helper — before T7)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION money_kernel.derive_bill_status(
  p_total       numeric,
  p_paid        numeric,
  p_due         numeric,
  p_written_off numeric
) RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  IF p_due = 0 THEN
    IF p_paid = 0 AND p_written_off > 0 THEN
      RETURN 'written_off';
    END IF;
    RETURN 'paid';
  END IF;

  IF p_paid > 0 OR p_written_off > 0 THEN
    RETURN 'partial';
  END IF;
  RETURN 'issued';
END;
$$;

-- ---------------------------------------------------------------------------
-- T1 — trg_pays_apply
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION money_kernel.fn_pays_apply()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_to_credit numeric(18, 4);
  v_from_bal  numeric(18, 4);
  v_to_bal    numeric(18, 4);
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'posted' THEN
    PERFORM set_config('money.pot_writer', '1', true);

    IF NEW.from_pot_id IS NOT NULL THEN
      UPDATE money_kernel.cash_bundles
         SET amount     = amount - NEW.amount,
             updated_at = now()
       WHERE id = NEW.from_pot_id
         AND amount >= NEW.amount;
      IF NOT FOUND THEN
        RAISE EXCEPTION
          'insufficient_balance: pot % cannot cover pays % amount %',
          NEW.from_pot_id, NEW.id, NEW.amount;
      END IF;
      SELECT amount INTO v_from_bal
        FROM money_kernel.cash_bundles
       WHERE id = NEW.from_pot_id;
    END IF;

    IF NEW.to_pot_id IS NOT NULL THEN
      v_to_credit := CASE
        WHEN NEW.kind = 'transfer' THEN round(NEW.amount * NEW.exchange_rate, 4)
        ELSE NEW.amount
      END;
      UPDATE money_kernel.cash_bundles
         SET amount     = amount + v_to_credit,
             updated_at = now()
       WHERE id = NEW.to_pot_id;
      SELECT amount INTO v_to_bal
        FROM money_kernel.cash_bundles
       WHERE id = NEW.to_pot_id;
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
    PERFORM set_config('money.pot_writer', '1', true);

    IF OLD.from_pot_id IS NOT NULL THEN
      UPDATE money_kernel.cash_bundles
         SET amount     = amount + OLD.amount,
             updated_at = now()
       WHERE id = OLD.from_pot_id;
    END IF;

    IF OLD.to_pot_id IS NOT NULL THEN
      v_to_credit := CASE
        WHEN OLD.kind = 'transfer' THEN round(OLD.amount * OLD.exchange_rate, 4)
        ELSE OLD.amount
      END;
      UPDATE money_kernel.cash_bundles
         SET amount     = amount - v_to_credit,
             updated_at = now()
       WHERE id = OLD.to_pot_id
         AND amount >= v_to_credit;
      IF NOT FOUND THEN
        RAISE EXCEPTION
          'insufficient_balance: cannot void pays %; to_pot % missing credit %',
          OLD.id, OLD.to_pot_id, v_to_credit;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pays_apply
  AFTER INSERT OR UPDATE OF status ON money_kernel.pays
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_pays_apply();

-- ---------------------------------------------------------------------------
-- T2 — trg_pays_guard_immutable
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION money_kernel.fn_pays_guard_immutable()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  IF OLD.status = 'voided' THEN
    RAISE EXCEPTION 'pays % is voided and cannot be updated', OLD.id;
  END IF;

  IF NEW.status = 'voided' THEN
    IF NEW.amount           <> OLD.amount
       OR NEW.from_cash_bundle_id IS DISTINCT FROM OLD.from_cash_bundle_id
       OR NEW.to_cash_bundle_id   IS DISTINCT FROM OLD.to_cash_bundle_id
       OR NEW.currency_code <> OLD.currency_code
       OR NEW.exchange_rate <> OLD.exchange_rate
       OR NEW.books_amount  <> OLD.books_amount
       OR NEW.books_rate    <> OLD.books_rate
       OR NEW.kind          <> OLD.kind
       OR NEW.tenant_id     <> OLD.tenant_id
       OR NEW.payment_date  <> OLD.payment_date
       OR NEW.created_by    IS DISTINCT FROM OLD.created_by
       OR NEW.refs          IS DISTINCT FROM OLD.refs
       OR NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key
       OR NEW.request_hash  IS DISTINCT FROM OLD.request_hash
       OR NOT (NEW.meta @> OLD.meta) THEN
      RAISE EXCEPTION
        'void pays % may only change status, voided_at, meta (add-only), updated_at', OLD.id;
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.status = 'posted' AND OLD.status = 'posted'
     AND current_setting('money.revert_writer', true) = '1' THEN
    IF NEW.amount                <> OLD.amount
       OR NEW.from_cash_bundle_id IS DISTINCT FROM OLD.from_cash_bundle_id
       OR NEW.to_cash_bundle_id   IS DISTINCT FROM OLD.to_cash_bundle_id
       OR NEW.currency_code       <> OLD.currency_code
       OR NEW.exchange_rate       <> OLD.exchange_rate
       OR NEW.books_amount        <> OLD.books_amount
       OR NEW.books_rate          <> OLD.books_rate
       OR NEW.kind                 <> OLD.kind
       OR NEW.tenant_id            <> OLD.tenant_id
       OR NEW.payment_date         <> OLD.payment_date
       OR NEW.created_by           IS DISTINCT FROM OLD.created_by
       OR NEW.refs                 IS DISTINCT FROM OLD.refs
       OR NEW.idempotency_key      IS DISTINCT FROM OLD.idempotency_key
       OR NEW.request_hash         IS DISTINCT FROM OLD.request_hash
       OR NEW.status               IS DISTINCT FROM OLD.status
       OR NEW.voided_at            IS DISTINCT FROM OLD.voided_at
       OR NEW.voided_by            IS DISTINCT FROM OLD.voided_by
       OR NOT (NEW.meta @> OLD.meta) THEN
      RAISE EXCEPTION
        'revert pays % may only add meta (revert_reason, reverted_at, reversal_pays_id)', OLD.id;
    END IF;
    RETURN NEW;
  END IF;

  -- T1 snapshot write after deferred fn_pays_apply (bundle_writer or legacy pot_writer)
  IF NEW.status = 'posted' AND OLD.status = 'posted'
     AND (
       current_setting('money.pot_writer', true) = '1'
       OR current_setting('money.bundle_writer', true) = '1'
     )
     AND NEW.amount           = OLD.amount
     AND NEW.from_cash_bundle_id IS NOT DISTINCT FROM OLD.from_cash_bundle_id
     AND NEW.to_cash_bundle_id   IS NOT DISTINCT FROM OLD.to_cash_bundle_id
     AND NEW.currency_code    = OLD.currency_code
     AND NEW.exchange_rate    = OLD.exchange_rate
     AND NEW.books_amount     = OLD.books_amount
     AND NEW.books_rate       = OLD.books_rate
     AND NEW.kind             = OLD.kind
     AND NEW.tenant_id        = OLD.tenant_id
     AND NEW.payment_date     = OLD.payment_date
     AND NEW.created_by       IS NOT DISTINCT FROM OLD.created_by
     AND NEW.refs             IS NOT DISTINCT FROM OLD.refs
     AND NEW.idempotency_key  IS NOT DISTINCT FROM OLD.idempotency_key
     AND NEW.request_hash     IS NOT DISTINCT FROM OLD.request_hash
     AND NEW.meta             = OLD.meta
     AND NEW.status           = OLD.status
     AND NEW.voided_at        IS NOT DISTINCT FROM OLD.voided_at
     AND NEW.voided_by        IS NOT DISTINCT FROM OLD.voided_by
     AND (
       NEW.from_balance_after IS DISTINCT FROM OLD.from_balance_after
       OR NEW.to_balance_after IS DISTINCT FROM OLD.to_balance_after
     ) THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION
    'posted pays % is immutable; use rpc_update_pays (void + recreate) for corrections', OLD.id;
END;
$$;

CREATE TRIGGER trg_pays_guard_immutable
  BEFORE UPDATE ON money_kernel.pays
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_pays_guard_immutable();

-- T3 bundle amount guard: see money_kernel_v2/28_money_kernel_bundle_triggers.sql (fn_bundle_guard / trg_bundle_guard).

-- ---------------------------------------------------------------------------
-- T4 — trg_bills_guard_financial_spine
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION money_kernel.fn_bills_guard_financial_spine()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_has_settlements boolean;
BEGIN
  IF OLD.status = 'voided' THEN
    RAISE EXCEPTION 'voided bill % cannot be updated', OLD.id;
  END IF;

  IF OLD.status = 'draft' THEN
    IF NEW.status IS DISTINCT FROM OLD.status
       AND NEW.status NOT IN ('issued', 'voided') THEN
      RAISE EXCEPTION
        'illegal status transition for bill %: draft → %', OLD.id, NEW.status;
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.tenant_id             <> OLD.tenant_id
     OR NEW.invoice_no         <> OLD.invoice_no
     OR NEW.invoice_date       <> OLD.invoice_date
     OR NEW.kind               <> OLD.kind
     OR NEW.parent_bill_id     IS DISTINCT FROM OLD.parent_bill_id
     OR NEW.currency_code      <> OLD.currency_code
     OR NEW.from_profile_id    IS DISTINCT FROM OLD.from_profile_id
     OR NEW.to_profile_id      IS DISTINCT FROM OLD.to_profile_id
     OR NEW.counterparty_profile_id IS DISTINCT FROM OLD.counterparty_profile_id
     OR NEW.counterparty_tenant_id  IS DISTINCT FROM OLD.counterparty_tenant_id
     OR NEW.source_entity      IS DISTINCT FROM OLD.source_entity
     OR NEW.source_type        IS DISTINCT FROM OLD.source_type
     OR NEW.source_id          IS DISTINCT FROM OLD.source_id
     OR NEW.source_key         IS DISTINCT FROM OLD.source_key THEN
    RAISE EXCEPTION
      'issued bill % — structural columns are immutable (void and recreate if needed)', OLD.id;
  END IF;

  IF NEW.total_amount IS DISTINCT FROM OLD.total_amount
     OR NEW.due_date IS DISTINCT FROM OLD.due_date THEN
    SELECT EXISTS (
      SELECT 1 FROM money_kernel.bill_settlements
       WHERE bill_id = OLD.id OR source_bill_id = OLD.id
    ) INTO v_has_settlements;
  ELSE
    v_has_settlements := false;
  END IF;

  IF v_has_settlements THEN
    IF NEW.total_amount <> OLD.total_amount
       OR NEW.due_date IS DISTINCT FROM OLD.due_date THEN
      RAISE EXCEPTION
        'bill % has settlements — total_amount and due_date cannot change', OLD.id;
    END IF;
  END IF;

  IF NEW.status <> OLD.status THEN
    IF NOT (
      (OLD.status = 'issued' AND NEW.status IN ('partial', 'paid', 'written_off', 'voided')) OR
      (OLD.status = 'partial' AND NEW.status IN ('issued', 'paid', 'written_off', 'voided')) OR
      (OLD.status = 'paid' AND NEW.status IN ('partial', 'issued', 'voided')) OR
      (OLD.status = 'written_off' AND NEW.status = 'voided')
    ) THEN
      RAISE EXCEPTION
        'illegal status transition for bill %: % → %', OLD.id, OLD.status, NEW.status;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_bills_guard_financial_spine
  BEFORE UPDATE ON money_kernel.bills
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_bills_guard_financial_spine();

-- ---------------------------------------------------------------------------
-- T5 — trg_bill_events_no_update
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION money_kernel.fn_bill_events_immutable()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION
    'bill_events is append-only; cannot UPDATE or DELETE row id=%', OLD.id;
END;
$$;

CREATE TRIGGER trg_bill_events_no_update
  BEFORE UPDATE OR DELETE ON money_kernel.bill_events
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_bill_events_immutable();

-- ---------------------------------------------------------------------------
-- T6 — trg_bill_events_from_bills (+ money_outbox mirror)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION money_kernel.fn_bill_events_from_bills()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_event_type text;
  v_payload    jsonb;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_event_type := 'created';
    v_payload := jsonb_build_object(
      'kind',                     NEW.kind,
      'invoice_no',               NEW.invoice_no,
      'status',                   NEW.status,
      'total_amount',             NEW.total_amount,
      'currency_code',            NEW.currency_code,
      'source_entity',            NEW.source_entity,
      'source_type',              NEW.source_type,
      'source_id',                NEW.source_id,
      'source_key',               NEW.source_key,
      'parent_bill_id',           NEW.parent_bill_id,
      'counterparty_profile_id',  NEW.counterparty_profile_id
    );
    INSERT INTO money_kernel.bill_events
      (tenant_id, bill_id, event_type, payload, actor_id)
    VALUES
      (NEW.tenant_id, NEW.id, v_event_type, v_payload, auth.uid());
    INSERT INTO money_kernel.money_outbox
      (tenant_id, event_type, payload, bill_id)
    VALUES
      (NEW.tenant_id, v_event_type, v_payload, NEW.id);
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.status = 'voided' AND OLD.status IS DISTINCT FROM 'voided' THEN
      v_event_type := 'voided';
      v_payload := jsonb_build_object(
        'from_status',        OLD.status,
        'to_status',          'voided',
        'due_before',         OLD.due_amount,
        'written_off_before', OLD.written_off_amount
      );
      INSERT INTO money_kernel.bill_events
        (tenant_id, bill_id, event_type, payload, actor_id)
      VALUES (NEW.tenant_id, NEW.id, v_event_type, v_payload, auth.uid());
      INSERT INTO money_kernel.money_outbox
        (tenant_id, event_type, payload, bill_id)
      VALUES (NEW.tenant_id, v_event_type, v_payload, NEW.id);
      RETURN NEW;
    END IF;

    IF NEW.paid_amount IS DISTINCT FROM OLD.paid_amount THEN
      v_event_type := CASE
        WHEN NEW.paid_amount > OLD.paid_amount THEN 'payment_applied'
        ELSE 'payment_reversed'
      END;
      v_payload := jsonb_build_object(
        'delta',        NEW.paid_amount - OLD.paid_amount,
        'paid_before',  OLD.paid_amount,
        'paid_after',   NEW.paid_amount,
        'due_after',    NEW.due_amount,
        'status_after', NEW.status
      );
      INSERT INTO money_kernel.bill_events
        (tenant_id, bill_id, event_type, payload, actor_id)
      VALUES (NEW.tenant_id, NEW.id, v_event_type, v_payload, auth.uid());
      INSERT INTO money_kernel.money_outbox
        (tenant_id, event_type, payload, bill_id)
      VALUES (NEW.tenant_id, v_event_type, v_payload, NEW.id);
      RETURN NEW;
    END IF;

    IF NEW.written_off_amount IS DISTINCT FROM OLD.written_off_amount THEN
      v_event_type := 'written_off';
      v_payload := jsonb_build_object(
        'delta',             NEW.written_off_amount - OLD.written_off_amount,
        'written_off_total', NEW.written_off_amount,
        'due_after',         NEW.due_amount,
        'status_after',      NEW.status
      );
      INSERT INTO money_kernel.bill_events
        (tenant_id, bill_id, event_type, payload, actor_id)
      VALUES (NEW.tenant_id, NEW.id, v_event_type, v_payload, auth.uid());
      INSERT INTO money_kernel.money_outbox
        (tenant_id, event_type, payload, bill_id)
      VALUES (NEW.tenant_id, v_event_type, v_payload, NEW.id);
      RETURN NEW;
    END IF;

    IF NEW.status <> OLD.status AND NEW.status = 'issued' THEN
      v_event_type := 'issued';
      v_payload := jsonb_build_object(
        'from_status', OLD.status,
        'to_status',   NEW.status
      );
      INSERT INTO money_kernel.bill_events
        (tenant_id, bill_id, event_type, payload, actor_id)
      VALUES (NEW.tenant_id, NEW.id, v_event_type, v_payload, auth.uid());
      INSERT INTO money_kernel.money_outbox
        (tenant_id, event_type, payload, bill_id)
      VALUES (NEW.tenant_id, v_event_type, v_payload, NEW.id);
      RETURN NEW;
    END IF;

    RETURN NEW;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_bill_events_from_bills
  AFTER INSERT OR UPDATE ON money_kernel.bills
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_bill_events_from_bills();

-- ---------------------------------------------------------------------------
-- T7 — trg_bill_settle_apply
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION money_kernel.fn_bill_settle_apply()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_row   money_kernel.bill_settlements;
  v_delta numeric(18, 4);
BEGIN
  v_row := COALESCE(NEW, OLD);
  v_delta := CASE WHEN TG_OP = 'INSERT' THEN NEW.allocated_amount ELSE -OLD.allocated_amount END;

  UPDATE money_kernel.bills
     SET paid_amount = paid_amount + v_delta,
         due_amount  = due_amount  - v_delta,
         status      = CASE
                         WHEN status = 'voided' THEN status
                         ELSE money_kernel.derive_bill_status(
                                total_amount,
                                paid_amount + v_delta,
                                due_amount - v_delta,
                                written_off_amount)
                       END,
         updated_at  = now()
   WHERE id = v_row.bill_id
     AND (due_amount - v_delta) >= 0
     AND (paid_amount + v_delta) >= 0;
  IF NOT FOUND THEN
    RAISE EXCEPTION
      'invalid_amount: settlement delta % would break paid/due on bill %',
      v_delta, v_row.bill_id;
  END IF;

  IF v_row.settlement_kind = 'document' AND v_row.source_bill_id IS NOT NULL THEN
    UPDATE money_kernel.bills
       SET paid_amount = paid_amount + v_delta,
           due_amount  = due_amount  - v_delta,
           status      = CASE
                           WHEN status = 'voided' THEN status
                           ELSE money_kernel.derive_bill_status(
                                  total_amount,
                                  paid_amount + v_delta,
                                  due_amount - v_delta,
                                  written_off_amount)
                         END,
           updated_at  = now()
     WHERE id = v_row.source_bill_id
       AND (due_amount - v_delta) >= -0.01
       AND (paid_amount + v_delta) >= -0.01;
    IF NOT FOUND THEN
      RAISE EXCEPTION
        'invalid_amount: settlement delta % would break paid/due on source bill %',
        v_delta, v_row.source_bill_id;
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_bill_settle_apply
  AFTER INSERT OR DELETE ON money_kernel.bill_settlements
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_bill_settle_apply();

-- ---------------------------------------------------------------------------
-- T8 — trg_bill_lines_guard
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION money_kernel.fn_bill_lines_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_bill_id bigint;
  v_status  text;
BEGIN
  v_bill_id := COALESCE(NEW.bill_id, OLD.bill_id);

  SELECT b.status INTO v_status
    FROM money_kernel.bills b
   WHERE b.id = v_bill_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bill % for bill_lines', v_bill_id;
  END IF;

  IF v_status <> 'draft' THEN
    RAISE EXCEPTION
      'bill_lines immutable when bill % status is % (must be draft)', v_bill_id, v_status;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_bill_lines_guard
  BEFORE INSERT OR UPDATE OR DELETE ON money_kernel.bill_lines
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_bill_lines_guard();

-- ---------------------------------------------------------------------------
-- S1 — trg_bill_settlements_immutable
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION money_kernel.fn_bill_settlements_immutable()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION
    'bill_settlements row % is immutable; void via rpc_void_pays / rpc_void_document_settlement', OLD.id;
END;
$$;

CREATE TRIGGER trg_bill_settlements_immutable
  BEFORE UPDATE ON money_kernel.bill_settlements
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_bill_settlements_immutable();

-- ---------------------------------------------------------------------------
-- S2 — trg_validate_profile_link
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION money_kernel.fn_validate_profile_link()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  IF NEW.profile_id IS NULL THEN
    RAISE EXCEPTION 'cashbooks.profile_id is required';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_profile_link
  BEFORE INSERT OR UPDATE ON money_kernel.cashbooks
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_validate_profile_link();

-- ---------------------------------------------------------------------------
-- S3 — trg_validate_default_pot
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION money_kernel.fn_validate_default_pot()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  IF NEW.default_cashbook_point_pot_id IS NOT NULL THEN
    PERFORM 1
      FROM money_kernel.cash_bundles pp
      JOIN money_kernel.cash_locations pt ON pt.id = pp.cash_location_id
     WHERE pp.id = NEW.default_cashbook_point_pot_id
       AND pt.cashbook_id = NEW.id;
    IF NOT FOUND THEN
      RAISE EXCEPTION
        'default_cashbook_point_pot_id % does not belong to account %',
        NEW.default_cashbook_point_pot_id, NEW.id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_default_pot
  BEFORE INSERT OR UPDATE OF default_cashbook_point_pot_id
  ON money_kernel.cashbooks
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_validate_default_pot();

-- S4 profile cashbook: provision on public.profiles (public.trg_provision_kernel_cashbook_for_profile).

-- ---------------------------------------------------------------------------
-- S5 — trg_bill_settlements_pay_guard
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION money_kernel.fn_bill_settlements_pay_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_pay    money_kernel.pays;
  v_source money_kernel.bills;
  v_target money_kernel.bills;
BEGIN
  IF NEW.settlement_kind = 'pay' THEN
    IF NEW.pays_id IS NULL THEN
      RAISE EXCEPTION 'invalid_settlement: pay kind requires pays_id';
    END IF;

    SELECT * INTO v_pay
      FROM money_kernel.pays
     WHERE id = NEW.pays_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'not_found: pays %', NEW.pays_id;
    END IF;

    IF v_pay.status <> 'posted'
       OR v_pay.kind <> 'payment'
       OR v_pay.tenant_id <> NEW.tenant_id THEN
      RAISE EXCEPTION
        'invalid_pays: pay settlement requires posted payment pays in same tenant (I31)';
    END IF;

    RETURN NEW;
  END IF;

  IF NEW.settlement_kind = 'document' THEN
    IF NEW.source_bill_id IS NULL THEN
      RAISE EXCEPTION 'invalid_settlement: document kind requires source_bill_id';
    END IF;

    SELECT * INTO v_source
      FROM money_kernel.bills
     WHERE id = NEW.source_bill_id;

    SELECT * INTO v_target
      FROM money_kernel.bills
     WHERE id = NEW.bill_id;

    IF v_source.id IS NULL OR v_target.id IS NULL THEN
      RAISE EXCEPTION 'not_found: source or target bill for document settlement';
    END IF;

    IF v_source.kind <> 'credit_note' THEN
      RAISE EXCEPTION
        'invalid_arguments: document settlement source must be credit_note, got %',
        v_source.kind;
    END IF;

    IF v_target.from_profile_id IS DISTINCT FROM v_source.to_profile_id
       OR v_target.to_profile_id IS DISTINCT FROM v_source.from_profile_id THEN
      RAISE EXCEPTION
        'invalid_arguments: document apply requires target.from=source.to and target.to=source.from (I29)';
    END IF;

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_bill_settlements_pay_guard
  BEFORE INSERT ON money_kernel.bill_settlements
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_bill_settlements_pay_guard();

-- ---------------------------------------------------------------------------
-- S6 — trg_tenant_id_immutable (operational tables with tenant_id)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION money_kernel.fn_tenant_id_immutable()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  IF NEW.tenant_id IS DISTINCT FROM OLD.tenant_id THEN
    RAISE EXCEPTION
      'tenant_id is immutable on money_kernel.%', TG_TABLE_NAME;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_tenant_id_immutable_cashbooks
  BEFORE UPDATE OF tenant_id ON money_kernel.cashbooks
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_tenant_id_immutable();

CREATE TRIGGER trg_tenant_id_immutable_cash_locations
  BEFORE UPDATE OF tenant_id ON money_kernel.cash_locations
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_tenant_id_immutable();

CREATE TRIGGER trg_tenant_id_immutable_cash_bundles
  BEFORE UPDATE OF tenant_id ON money_kernel.cash_bundles
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_tenant_id_immutable();

CREATE TRIGGER trg_tenant_id_immutable_pays
  BEFORE UPDATE OF tenant_id ON money_kernel.pays
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_tenant_id_immutable();

CREATE TRIGGER trg_tenant_id_immutable_invoice_no_counters
  BEFORE UPDATE OF tenant_id ON money_kernel.invoice_no_counters
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_tenant_id_immutable();

CREATE TRIGGER trg_tenant_id_immutable_bills
  BEFORE UPDATE OF tenant_id ON money_kernel.bills
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_tenant_id_immutable();

CREATE TRIGGER trg_tenant_id_immutable_bill_lines
  BEFORE UPDATE OF tenant_id ON money_kernel.bill_lines
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_tenant_id_immutable();

CREATE TRIGGER trg_tenant_id_immutable_bill_settlements
  BEFORE UPDATE OF tenant_id ON money_kernel.bill_settlements
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_tenant_id_immutable();

CREATE TRIGGER trg_tenant_id_immutable_bill_events
  BEFORE UPDATE OF tenant_id ON money_kernel.bill_events
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_tenant_id_immutable();

CREATE TRIGGER trg_tenant_id_immutable_money_outbox
  BEFORE UPDATE OF tenant_id ON money_kernel.money_outbox
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_tenant_id_immutable();

-- ---------------------------------------------------------------------------
-- G1 — trg_deny_dml_pays_bills (DELETE + TRUNCATE)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION money_kernel.fn_deny_kernel_dml()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  IF current_setting('money.allow_kernel_delete', true) IS DISTINCT FROM '1' THEN
    IF TG_OP = 'TRUNCATE' THEN
      RAISE EXCEPTION
        'direct TRUNCATE on money_kernel.% is forbidden', TG_TABLE_NAME;
    END IF;
    RAISE EXCEPTION
      'direct DELETE on money_kernel.% is forbidden; use RPC void paths', TG_TABLE_NAME;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_deny_dml_pays_delete
  BEFORE DELETE ON money_kernel.pays
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_deny_kernel_dml();

CREATE TRIGGER trg_deny_dml_pays_truncate
  BEFORE TRUNCATE ON money_kernel.pays
  FOR EACH STATEMENT
  EXECUTE FUNCTION money_kernel.fn_deny_kernel_dml();

CREATE TRIGGER trg_deny_dml_bills_delete
  BEFORE DELETE ON money_kernel.bills
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_deny_kernel_dml();

CREATE TRIGGER trg_deny_dml_bills_truncate
  BEFORE TRUNCATE ON money_kernel.bills
  FOR EACH STATEMENT
  EXECUTE FUNCTION money_kernel.fn_deny_kernel_dml();

CREATE TRIGGER trg_deny_dml_bill_settlements_delete
  BEFORE DELETE ON money_kernel.bill_settlements
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_deny_kernel_dml();

CREATE TRIGGER trg_deny_dml_bill_settlements_truncate
  BEFORE TRUNCATE ON money_kernel.bill_settlements
  FOR EACH STATEMENT
  EXECUTE FUNCTION money_kernel.fn_deny_kernel_dml();

-- ---------------------------------------------------------------------------
-- D1 — trg_check_pays_overalloc (deferred constraint trigger)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION money_kernel.fn_check_pays_overalloc()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_alloc numeric(18, 4);
  v_books numeric(18, 4);
BEGIN
  IF NEW.settlement_kind <> 'pay' OR NEW.pays_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(SUM(allocated_books_amount), 0)
    INTO v_alloc
    FROM money_kernel.bill_settlements
   WHERE pays_id = NEW.pays_id
     AND settlement_kind = 'pay';

  SELECT books_amount
    INTO v_books
    FROM money_kernel.pays
   WHERE id = NEW.pays_id;

  IF v_alloc > v_books + 0.01 THEN
    RAISE EXCEPTION
      'over-allocated pays %: books-allocated % > books-amount %',
      NEW.pays_id, v_alloc, v_books;
  END IF;

  RETURN NEW;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_check_pays_overalloc
  AFTER INSERT OR UPDATE ON money_kernel.bill_settlements
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_check_pays_overalloc();

-- fn_pays_apply sets money.bundle_writer; snapshot UPDATE must pass pays immutability guard.

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

-- Remove pre-cutover lot/pot guards on cash_bundles (cashbook_lots rename left trg_lot_guard active).

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

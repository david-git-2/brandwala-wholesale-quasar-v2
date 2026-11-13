-- Rename cutover left trg_validate_default_lot on cashbooks; NEW still referenced default_cashbook_lot_id.

DROP TRIGGER IF EXISTS trg_validate_default_lot ON money_kernel.cashbooks;

DO $drop$
BEGIN
  IF to_regclass('money_kernel.cashbook_accounts') IS NOT NULL THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_validate_default_lot ON money_kernel.cashbook_accounts';
  END IF;
END;
$drop$;

DROP FUNCTION IF EXISTS money_kernel.fn_validate_default_lot();

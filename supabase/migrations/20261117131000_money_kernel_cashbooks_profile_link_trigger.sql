-- Prod/local: align cashbooks profile link trigger with profile_id spine (idempotent).

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

DO $$
BEGIN
  IF to_regclass('money_kernel.cashbook_accounts') IS NOT NULL THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_validate_profile_link ON money_kernel.cashbook_accounts';
  END IF;
END $$;

DROP TRIGGER IF EXISTS trg_validate_profile_link ON money_kernel.cashbooks;
CREATE TRIGGER trg_validate_profile_link
  BEFORE INSERT OR UPDATE ON money_kernel.cashbooks
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_validate_profile_link();
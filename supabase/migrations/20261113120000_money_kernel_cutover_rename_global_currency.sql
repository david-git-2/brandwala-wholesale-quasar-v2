-- Money kernel cutover: global_currencies spine, rename lots→bundles, drop money_kernel.currencies.

-- profiles.cashbook_enabled
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS cashbook_enabled boolean NOT NULL DEFAULT true;

UPDATE public.profiles p
   SET cashbook_enabled = false
 WHERE p.profile_type IN ('vendor', 'cargo', 'company');

UPDATE public.profiles p
   SET cashbook_enabled = true
 WHERE p.profile_type IN ('tenant', 'customer', 'courier', 'investor');

-- Table renames (idempotent)
DO $cut$
BEGIN
  IF to_regclass('money_kernel.cashbook_accounts') IS NOT NULL
     AND to_regclass('money_kernel.cashbooks') IS NULL THEN
    ALTER TABLE money_kernel.cashbook_accounts RENAME TO cashbooks;
  END IF;
  IF to_regclass('money_kernel.cashbook_points') IS NOT NULL
     AND to_regclass('money_kernel.cash_locations') IS NULL THEN
    ALTER TABLE money_kernel.cashbook_points RENAME TO cash_locations;
  END IF;
  IF to_regclass('money_kernel.cashbook_lots') IS NOT NULL
     AND to_regclass('money_kernel.cash_bundles') IS NULL THEN
    ALTER TABLE money_kernel.cashbook_lots RENAME TO cash_bundles;
  END IF;
  IF to_regclass('money_kernel.pay_lot_lines') IS NOT NULL
     AND to_regclass('money_kernel.pay_bundle_lines') IS NULL THEN
    ALTER TABLE money_kernel.pay_lot_lines RENAME TO pay_bundle_lines;
  END IF;
END;
$cut$;

-- Column renames on cashbooks / locations / bundles / lines / pays
DO $cols$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'money_kernel' AND table_name = 'cashbooks'
      AND column_name = 'cashbook_account_id'
  ) THEN NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'money_kernel' AND table_name = 'cashbooks'
      AND column_name = 'default_cashbook_lot_id'
  ) THEN
    ALTER TABLE money_kernel.cashbooks
      RENAME COLUMN default_cashbook_lot_id TO default_cash_bundle_id;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'money_kernel' AND table_name = 'cash_locations'
      AND column_name = 'cashbook_account_id'
  ) THEN
    ALTER TABLE money_kernel.cash_locations
      RENAME COLUMN cashbook_account_id TO cashbook_id;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'money_kernel' AND table_name = 'cash_locations'
      AND column_name = 'code'
  ) THEN
    ALTER TABLE money_kernel.cash_locations RENAME COLUMN code TO location_code;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'money_kernel' AND table_name = 'cash_bundles'
      AND column_name = 'cashbook_point_id'
  ) THEN
    ALTER TABLE money_kernel.cash_bundles
      RENAME COLUMN cashbook_point_id TO cash_location_id;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'money_kernel' AND table_name = 'pay_bundle_lines'
      AND column_name = 'lot_id'
  ) THEN
    ALTER TABLE money_kernel.pay_bundle_lines RENAME COLUMN lot_id TO cash_bundle_id;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'money_kernel' AND table_name = 'pays'
      AND column_name = 'from_lot_id'
  ) THEN
    ALTER TABLE money_kernel.pays RENAME COLUMN from_lot_id TO from_cash_bundle_id;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'money_kernel' AND table_name = 'pays'
      AND column_name = 'to_lot_id'
  ) THEN
    ALTER TABLE money_kernel.pays RENAME COLUMN to_lot_id TO to_cash_bundle_id;
  END IF;
END;
$cols$;

-- cashbooks: profile_id spine; drop legacy entity columns when present
ALTER TABLE money_kernel.cashbooks
  ADD COLUMN IF NOT EXISTS profile_id bigint;

UPDATE money_kernel.cashbooks cb
   SET profile_id = coalesce(cb.profile_id, cb.entity_id)
 WHERE cb.profile_id IS NULL
   AND EXISTS (
     SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'money_kernel' AND table_name = 'cashbooks' AND column_name = 'entity_type'
   )
   AND cb.entity_type = 'profile';

UPDATE money_kernel.cashbooks cb
   SET profile_id = pr.id
  FROM public.profiles pr
 WHERE cb.profile_id IS NULL
   AND EXISTS (
     SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'money_kernel' AND table_name = 'cashbooks' AND column_name = 'entity_type'
   )
   AND cb.entity_type = 'tenant'
   AND pr.tenant_id = cb.tenant_id
   AND pr.profile_type = 'tenant'
   AND pr.subject_id = cb.tenant_id;

ALTER TABLE money_kernel.cash_bundles
  ADD COLUMN IF NOT EXISTS currency_id bigint REFERENCES public.global_currencies (id),
  ADD COLUMN IF NOT EXISTS drawer_group text NOT NULL DEFAULT '';

UPDATE money_kernel.cash_bundles b
   SET currency_id = gc.id
  FROM public.global_currencies gc
 WHERE b.currency_id IS NULL
   AND gc.code = b.currency_code;

ALTER TABLE money_kernel.bills
  ADD COLUMN IF NOT EXISTS currency_id bigint REFERENCES public.global_currencies (id);

UPDATE money_kernel.bills b
   SET currency_id = gc.id
  FROM public.global_currencies gc
 WHERE b.currency_id IS NULL
   AND gc.code = b.currency_code;

ALTER TABLE money_kernel.pays
  ADD COLUMN IF NOT EXISTS currency_id bigint REFERENCES public.global_currencies (id),
  ADD COLUMN IF NOT EXISTS from_profile_id bigint,
  ADD COLUMN IF NOT EXISTS to_profile_id bigint;

UPDATE money_kernel.pays p
   SET currency_id = gc.id
  FROM public.global_currencies gc
 WHERE p.currency_id IS NULL
   AND gc.code = p.currency_code;

-- Drop FKs to money_kernel.currencies then table
ALTER TABLE money_kernel.cash_bundles
  DROP CONSTRAINT IF EXISTS cashbook_lots_currency_code_fkey;
ALTER TABLE money_kernel.cash_bundles
  DROP CONSTRAINT IF EXISTS cash_bundles_currency_code_fkey;
ALTER TABLE money_kernel.pays
  DROP CONSTRAINT IF EXISTS pays_currency_code_fkey;
ALTER TABLE money_kernel.bills
  DROP CONSTRAINT IF EXISTS bills_currency_code_fkey;

ALTER TABLE money_kernel.cash_bundles
  ADD CONSTRAINT cash_bundles_currency_code_fkey
  FOREIGN KEY (currency_code) REFERENCES public.global_currencies (code);
ALTER TABLE money_kernel.pays
  ADD CONSTRAINT pays_currency_code_fkey
  FOREIGN KEY (currency_code) REFERENCES public.global_currencies (code);
ALTER TABLE money_kernel.bills
  ADD CONSTRAINT bills_currency_code_fkey
  FOREIGN KEY (currency_code) REFERENCES public.global_currencies (code);

DROP TABLE IF EXISTS money_kernel.currencies;

-- Money cutover phase 1: global_currencies.minor_units; money-active BDT/USD/GBP only.

ALTER TABLE public.global_currencies
  ADD COLUMN IF NOT EXISTS minor_units smallint NOT NULL DEFAULT 2;

COMMENT ON COLUMN public.global_currencies.minor_units IS 'Decimal places for amount entry; money desk uses BDT/USD/GBP (2).';

UPDATE public.global_currencies SET minor_units = 2 WHERE minor_units IS NULL;

INSERT INTO public.global_currencies (name, country, code, symbol, minor_units, is_active, is_system)
VALUES
  ('Bangladesh Taka', 'Bangladesh', 'BDT', '৳', 2, true, true),
  ('US Dollar', 'United States', 'USD', '$', 2, true, true),
  ('British Pound Sterling', 'United Kingdom', 'GBP', '£', 2, true, true)
ON CONFLICT (code) DO UPDATE SET
  minor_units = EXCLUDED.minor_units,
  is_active   = true,
  is_system   = true,
  updated_at  = now();

UPDATE public.global_currencies
   SET is_active = false,
       updated_at = now()
 WHERE code NOT IN ('BDT', 'USD', 'GBP');

DROP FUNCTION IF EXISTS public.list_global_currencies();

CREATE OR REPLACE FUNCTION public.list_global_currencies()
  RETURNS TABLE (
    id          bigint,
    name        text,
    country     text,
    code        text,
    symbol      text,
    minor_units smallint
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO public
AS $function$
  SELECT gc.id, gc.name, gc.country, gc.code, gc.symbol, gc.minor_units
    FROM public.global_currencies gc
   WHERE gc.is_active = true
   ORDER BY gc.code ASC;
$function$;

GRANT EXECUTE ON FUNCTION public.list_global_currencies() TO anon;
GRANT EXECUTE ON FUNCTION public.list_global_currencies() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_global_currencies() TO service_role;

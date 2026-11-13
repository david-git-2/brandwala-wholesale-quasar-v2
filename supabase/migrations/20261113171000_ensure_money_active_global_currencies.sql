-- Ensure money-active currencies exist (BDT, USD, GBP) for bundles and list_global_currencies.
-- System rows are protected by trg_global_currencies_protect_system_rows; migration runs as DB owner.

INSERT INTO public.global_currencies (name, country, code, symbol, minor_units, is_active, is_system)
VALUES
  ('Bangladesh Taka', 'Bangladesh', 'BDT', '৳', 2, true, true),
  ('US Dollar', 'United States', 'USD', '$', 2, true, true),
  ('British Pound Sterling', 'United Kingdom', 'GBP', '£', 2, true, true)
ON CONFLICT (code) DO NOTHING;

ALTER TABLE public.global_currencies DISABLE TRIGGER trg_global_currencies_protect_system_rows;

UPDATE public.global_currencies
   SET is_active = true,
       minor_units = 2,
       updated_at = now()
 WHERE code IN ('BDT', 'USD', 'GBP');

ALTER TABLE public.global_currencies ENABLE TRIGGER trg_global_currencies_protect_system_rows;

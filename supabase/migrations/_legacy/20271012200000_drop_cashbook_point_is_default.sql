DROP INDEX IF EXISTS public.cashbook_points_one_default_per_account_uidx;

ALTER TABLE public.cashbook_points
  DROP COLUMN IF EXISTS is_default;

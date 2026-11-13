-- Kernel currencies: BDT, GBP, USD only (+ RPC for UI dropdown).

INSERT INTO money_kernel.currencies (code, minor_units, name) VALUES
  ('BDT', 2, 'Bangladesh Taka'),
  ('GBP', 2, 'British Pound Sterling'),
  ('USD', 2, 'US Dollar')
ON CONFLICT (code) DO UPDATE SET
  minor_units = EXCLUDED.minor_units,
  name        = EXCLUDED.name;

DELETE FROM money_kernel.currencies
 WHERE code NOT IN ('BDT', 'GBP', 'USD');

CREATE OR REPLACE FUNCTION public.list_money_kernel_currencies()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'code',        c.code,
        'minor_units', c.minor_units,
        'name',        c.name
      )
      ORDER BY c.code
    ),
    '[]'::jsonb
  )
  FROM money_kernel.currencies c;
$$;

GRANT EXECUTE ON FUNCTION public.list_money_kernel_currencies() TO authenticated, service_role;

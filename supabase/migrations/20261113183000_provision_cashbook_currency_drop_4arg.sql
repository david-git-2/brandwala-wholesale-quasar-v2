-- SQLSTATE 42725: 4-arg and 5-arg overloads both match (bigint, bigint, text) calls.

DROP FUNCTION IF EXISTS public.fn_provision_kernel_cashbook_currency(bigint, bigint, text);
DROP FUNCTION IF EXISTS public.fn_provision_kernel_cashbook_currency(bigint, bigint, text, text);

CREATE OR REPLACE FUNCTION public.fn_provision_kernel_cashbook_currency(
  p_books_tenant_id bigint,
  p_profile_id      bigint,
  p_currency_code   text,
  p_point_code      text DEFAULT 'main',
  p_books_rate      numeric DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_ccy text;
  v_rate numeric(15, 6);
  v_account_id bigint;
  v_point_id   bigint;
  v_lot_id     bigint;
BEGIN
  IF p_books_tenant_id IS NULL OR p_profile_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_ccy := upper(trim(coalesce(p_currency_code, 'BDT')));
  IF v_ccy = '' THEN
    v_ccy := 'BDT';
  END IF;

  IF v_ccy = 'BDT' THEN
    v_rate := 1;
  ELSIF p_books_rate IS NOT NULL AND p_books_rate > 0 THEN
    v_rate := p_books_rate;
  ELSE
    v_rate := money_kernel.fn_resolve_books_rate(p_books_tenant_id, v_ccy);
  END IF;

  v_account_id := public.fn_provision_kernel_cashbook_for_profile_row(p_books_tenant_id, p_profile_id);
  IF v_account_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT cp.id INTO v_point_id
  FROM money_kernel.cash_locations cp
  WHERE cp.cashbook_id = v_account_id
    AND cp.location_code = p_point_code
  LIMIT 1;

  IF v_point_id IS NULL THEN
    INSERT INTO money_kernel.cash_locations
      (tenant_id, cashbook_id, location_code, name)
    VALUES
      (p_books_tenant_id, v_account_id, p_point_code, initcap(p_point_code))
    RETURNING id INTO v_point_id;
  END IF;

  v_lot_id := money_kernel.fn_open_cash_bundle(
    p_books_tenant_id, v_point_id, v_ccy, v_rate, NULL
  );

  RETURN v_lot_id;
END;
$$;

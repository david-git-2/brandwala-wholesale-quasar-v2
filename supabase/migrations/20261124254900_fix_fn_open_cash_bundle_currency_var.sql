-- PL/pgSQL resolves unqualified names in INSERT...SELECT against the insert target first.
-- p_currency_code was misread as a cash_bundles column (42703).

CREATE OR REPLACE FUNCTION money_kernel.fn_open_cash_bundle(
  p_tenant_id         bigint,
  p_cash_location_id bigint,
  p_currency_code     text,
  p_books_rate        numeric DEFAULT 1,
  p_opened_pay_id     bigint DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, pg_temp
AS $$
#variable_conflict use_variable
DECLARE
  v_id   bigint;
  v_rate numeric(15, 6);
  v_ccy  text;
BEGIN
  v_rate := coalesce(nullif(p_books_rate, 0), 1);
  v_ccy  := upper(trim(coalesce(p_currency_code, '')));
  IF v_ccy = '' THEN
    v_ccy := 'BDT';
  END IF;

  INSERT INTO money_kernel.cash_bundles (
    tenant_id, cash_location_id, currency_id, currency_code, drawer_group,
    amount, books_rate, opened_pay_id
  )
  SELECT
    p_tenant_id, p_cash_location_id, gc.id, v_ccy, '',
    0, v_rate, p_opened_pay_id
    FROM public.global_currencies gc
   WHERE gc.code = v_ccy
     AND gc.is_active = true
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'currency_not_found: % is not an active global currency', v_ccy;
  END IF;

  RETURN v_id;
END;
$$;
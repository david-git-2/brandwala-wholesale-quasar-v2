-- Bill detail pay legs: list existing bundles only (no FX provision on read).

CREATE OR REPLACE FUNCTION public._desk_profile_cashbook_leg_json(
  p_books_tenant_id bigint,
  p_bill_profile_id bigint,
  p_currency_code text
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, money_kernel, pg_temp
AS $$
DECLARE
  v_account_id bigint;
  v_default_pot bigint;
  v_ccy_pot bigint;
  v_ccy text;
  v_points jsonb;
  v_pots jsonb;
BEGIN
  IF p_bill_profile_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_ccy := upper(trim(coalesce(p_currency_code, 'BDT')));
  IF v_ccy = '' THEN
    v_ccy := 'BDT';
  END IF;

  BEGIN
    PERFORM public.money_kernel_assert_profile_in_tenant(p_books_tenant_id, p_bill_profile_id);
  EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
  END;

  PERFORM public.fn_provision_kernel_cashbook_for_profile_row(p_books_tenant_id, p_bill_profile_id);

  SELECT ca.id, ca.default_cash_bundle_id
  INTO v_account_id, v_default_pot
  FROM money_kernel.cashbooks ca
  WHERE ca.tenant_id = p_books_tenant_id
    AND ca.profile_id = p_bill_profile_id
  LIMIT 1;

  IF v_account_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT pp.id INTO v_ccy_pot
  FROM money_kernel.cash_bundles pp
  JOIN money_kernel.cash_locations pt ON pt.id = pp.cash_location_id
  WHERE pt.cashbook_id = v_account_id
    AND upper(trim(pp.currency_code)) = v_ccy
    AND pp.closed_at IS NULL
  ORDER BY pt.location_code, pp.id
  LIMIT 1;

  v_default_pot := coalesce(v_ccy_pot, v_default_pot);

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', cp.id,
      'code', cp.location_code,
      'name', cp.name,
      'is_active', true
    )
    ORDER BY cp.name, cp.id
  ), '[]'::jsonb)
  INTO v_points
  FROM money_kernel.cash_locations cp
  WHERE cp.cashbook_id = v_account_id;

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', pp.id,
      'cash_location_id', pp.cash_location_id,
      'cashbook_point_id', pp.cash_location_id,
      'currency_code', upper(trim(pp.currency_code)),
      'amount', pp.amount,
      'books_rate', pp.books_rate,
      'drawer_group', pp.drawer_group,
      'point_code', pt.location_code,
      'point_name', pt.name
    )
    ORDER BY pt.name, pp.currency_code, pp.id
  ), '[]'::jsonb)
  INTO v_pots
  FROM money_kernel.cash_bundles pp
  JOIN money_kernel.cash_locations pt ON pt.id = pp.cash_location_id
  WHERE pt.cashbook_id = v_account_id
    AND pp.closed_at IS NULL;

  RETURN jsonb_build_object(
    'profile_id', p_bill_profile_id,
    'cashbook_id', v_account_id,
    'default_pot_id', v_default_pot,
    'points', v_points,
    'pots', v_pots
  );
END;
$$;

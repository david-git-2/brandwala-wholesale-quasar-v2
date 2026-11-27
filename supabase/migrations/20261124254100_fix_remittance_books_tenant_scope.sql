-- Drop retired parent-tenant auth path; fix courier_bdt provision recursion on already-applied DBs.

CREATE OR REPLACE FUNCTION public.fn_provision_kernel_cashbook_for_profile_row(
  p_books_tenant_id bigint,
  p_profile_id bigint
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_account_id bigint;
  v_point_id   bigint;
  v_courier_point_id bigint;
  v_lot_id     bigint;
  v_has_entity_cols boolean;
BEGIN
  IF p_books_tenant_id IS NULL OR p_profile_id IS NULL THEN
    RETURN NULL;
  END IF;
  IF NOT public.profile_auto_provisions_cashbook(p_profile_id) THEN
    RETURN NULL;
  END IF;

  SELECT ca.id INTO v_account_id
  FROM money_kernel.cashbooks ca
  WHERE ca.tenant_id = p_books_tenant_id
    AND ca.profile_id = p_profile_id
  LIMIT 1;

  v_has_entity_cols := EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'money_kernel'
      AND table_name = 'cashbooks'
      AND column_name = 'entity_type'
  );

  IF v_account_id IS NULL THEN
    IF v_has_entity_cols THEN
      INSERT INTO money_kernel.cashbooks (tenant_id, profile_id, entity_type, entity_id)
      VALUES (p_books_tenant_id, p_profile_id, 'profile', p_profile_id)
      RETURNING id INTO v_account_id;
    ELSE
      INSERT INTO money_kernel.cashbooks (tenant_id, profile_id)
      VALUES (p_books_tenant_id, p_profile_id)
      RETURNING id INTO v_account_id;
    END IF;
  END IF;

  SELECT cp.id INTO v_point_id
  FROM money_kernel.cash_locations cp
  WHERE cp.cashbook_id = v_account_id
    AND cp.location_code = 'main'
  LIMIT 1;

  IF v_point_id IS NULL THEN
    INSERT INTO money_kernel.cash_locations
      (tenant_id, cashbook_id, location_code, name)
    VALUES
      (p_books_tenant_id, v_account_id, 'main', 'Main')
    RETURNING id INTO v_point_id;
  END IF;

  SELECT pp.id INTO v_lot_id
  FROM money_kernel.cash_bundles pp
  WHERE pp.cash_location_id = v_point_id
    AND pp.currency_code = 'BDT'
    AND pp.books_rate = 1
    AND pp.closed_at IS NULL
  ORDER BY pp.id
  LIMIT 1;

  IF v_lot_id IS NULL THEN
    v_lot_id := money_kernel.fn_open_cash_bundle(
      p_books_tenant_id, v_point_id, 'BDT', 1::numeric(15, 6), NULL
    );
  END IF;

  UPDATE money_kernel.cashbooks
     SET default_cash_bundle_id = coalesce(default_cash_bundle_id, v_lot_id)
   WHERE id = v_account_id;

  IF EXISTS (
    SELECT 1
    FROM public.profiles pr
    WHERE pr.id = p_profile_id
      AND pr.profile_type = 'tenant'::public.profile_party_type
  ) THEN
    SELECT cp.id INTO v_courier_point_id
    FROM money_kernel.cash_locations cp
    WHERE cp.cashbook_id = v_account_id
      AND cp.location_code = 'courier_bdt'
    LIMIT 1;

    IF v_courier_point_id IS NULL THEN
      INSERT INTO money_kernel.cash_locations
        (tenant_id, cashbook_id, location_code, name)
      VALUES
        (p_books_tenant_id, v_account_id, 'courier_bdt', 'Courier BDT')
      RETURNING id INTO v_courier_point_id;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM money_kernel.cash_bundles pp
      WHERE pp.cash_location_id = v_courier_point_id
        AND pp.currency_code = 'BDT'
        AND pp.books_rate = 1
        AND pp.closed_at IS NULL
    ) THEN
      PERFORM money_kernel.fn_open_cash_bundle(
        p_books_tenant_id, v_courier_point_id, 'BDT', 1::numeric(15, 6), NULL
      );
    END IF;
  END IF;

  RETURN v_account_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.ensure_tenant_courier_bdt_bundle(
  p_books_tenant_id bigint,
  p_tenant_profile_id bigint
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_bundle_id bigint;
BEGIN
  IF p_books_tenant_id IS NULL OR p_tenant_profile_id IS NULL THEN
    RETURN NULL;
  END IF;

  PERFORM public.fn_provision_kernel_cashbook_for_profile_row(p_books_tenant_id, p_tenant_profile_id);

  SELECT pp.id INTO v_bundle_id
  FROM money_kernel.cashbooks ca
  JOIN money_kernel.cash_locations cp ON cp.cashbook_id = ca.id AND cp.location_code = 'courier_bdt'
  JOIN money_kernel.cash_bundles pp ON pp.cash_location_id = cp.id
  WHERE ca.tenant_id = p_books_tenant_id
    AND ca.profile_id = p_tenant_profile_id
    AND pp.currency_code = 'BDT'
    AND pp.closed_at IS NULL
  ORDER BY pp.id
  LIMIT 1;

  RETURN v_bundle_id;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_tenant_courier_bdt_bundle(bigint, bigint) FROM PUBLIC, authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_tenant_courier_bdt_bundle(bigint, bigint) TO service_role;
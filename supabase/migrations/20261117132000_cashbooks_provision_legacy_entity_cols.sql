-- Idempotent: cashbook provision on DBs that still have money_kernel.cashbooks.entity_* columns.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'money_kernel'
      AND table_name = 'cashbooks'
      AND column_name = 'entity_type'
  ) THEN
    ALTER TABLE money_kernel.cashbooks ALTER COLUMN entity_type DROP NOT NULL;
  END IF;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'money_kernel'
      AND table_name = 'cashbooks'
      AND column_name = 'entity_id'
  ) THEN
    ALTER TABLE money_kernel.cashbooks ALTER COLUMN entity_id DROP NOT NULL;
  END IF;
END $$;

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

  RETURN v_account_id;
END;
$$;
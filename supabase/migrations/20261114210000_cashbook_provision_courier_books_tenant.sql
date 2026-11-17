-- Cashbook auto-provision: courier + books tenant on profile trigger; backfill Main/BDT

CREATE OR REPLACE FUNCTION public.profile_auto_provisions_cashbook(p_profile_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles pr
    WHERE pr.id = p_profile_id
      AND pr.is_active = true
      AND pr.deleted_at IS NULL
      AND pr.cashbook_enabled = true
      AND pr.profile_type IN (
        'tenant'::public.profile_party_type,
        'customer'::public.profile_party_type,
        'courier'::public.profile_party_type,
        'investor'::public.profile_party_type
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.trg_provision_kernel_cashbook_for_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, money_kernel, pg_temp
AS $$
BEGIN
  PERFORM public.fn_provision_profile_cashbook_defaults(
    public.resolve_books_tenant_id(NEW.tenant_id),
    NEW.id
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_provision_kernel_cashbook_for_profile ON public.profiles;
CREATE TRIGGER trg_provision_kernel_cashbook_for_profile
  AFTER INSERT OR UPDATE OF cashbook_enabled, is_active, deleted_at ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_provision_kernel_cashbook_for_profile();

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'money_kernel' AND table_name = 'cashbooks' AND column_name = 'entity_type'
  ) THEN
    ALTER TABLE money_kernel.cashbooks ALTER COLUMN entity_type DROP NOT NULL;
  END IF;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'money_kernel' AND table_name = 'cashbooks' AND column_name = 'entity_id'
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

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT
      pr.id,
      public.resolve_books_tenant_id(pr.tenant_id) AS books_tenant_id
    FROM public.profiles pr
    WHERE public.profile_auto_provisions_cashbook(pr.id)
  LOOP
    IF r.books_tenant_id IS NULL THEN
      CONTINUE;
    END IF;
    BEGIN
      PERFORM public.fn_provision_profile_cashbook_defaults(r.books_tenant_id, r.id);
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'cashbook provision skipped profile %: %', r.id, SQLERRM;
    END;
  END LOOP;
END $$;
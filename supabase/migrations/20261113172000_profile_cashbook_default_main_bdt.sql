-- Default main location + BDT bundle for tenant/customer/investor cashbook profiles
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
        'investor'::public.profile_party_type
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.fn_provision_profile_cashbook_defaults(
  p_books_tenant_id bigint,
  p_profile_id bigint
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, money_kernel, pg_temp
AS $$
DECLARE
  v_account_id bigint;
BEGIN
  IF p_books_tenant_id IS NULL OR p_profile_id IS NULL THEN
    RETURN NULL;
  END IF;
  IF NOT public.profile_auto_provisions_cashbook(p_profile_id) THEN
    RETURN NULL;
  END IF;

  v_account_id :=
    public.fn_provision_kernel_cashbook_for_profile_row(p_books_tenant_id, p_profile_id);
  PERFORM public.ensure_cashbook_account_for_profile(p_profile_id, 'BDT');
  RETURN v_account_id;
END;
$$;

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

  IF v_account_id IS NULL THEN
    INSERT INTO money_kernel.cashbooks (tenant_id, profile_id)
    VALUES (p_books_tenant_id, p_profile_id)
    RETURNING id INTO v_account_id;
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

CREATE OR REPLACE FUNCTION public.trg_provision_kernel_cashbook_for_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, money_kernel, pg_temp
AS $$
BEGIN
  PERFORM public.fn_provision_profile_cashbook_defaults(NEW.tenant_id, NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_provision_kernel_cashbook_for_profile ON public.profiles;
CREATE TRIGGER trg_provision_kernel_cashbook_for_profile
  AFTER INSERT OR UPDATE OF cashbook_enabled, is_active, deleted_at ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_provision_kernel_cashbook_for_profile();
CREATE OR REPLACE FUNCTION public.ensure_cashbook_account_for_profile(
  p_profile_id bigint,
  p_currency_code text DEFAULT 'BDT'::text
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_axes record;
  v_account_id bigint;
  v_point_id bigint;
  v_pot_id bigint;
  v_ccy text := upper(trim(coalesce(p_currency_code, 'BDT')));
BEGIN
  IF p_profile_id IS NULL THEN
    RAISE EXCEPTION 'profile_id is required';
  END IF;

  SELECT * INTO v_axes FROM public._kernel_cashbook_axes_for_profile(p_profile_id);

  SELECT ca.id INTO v_account_id
  FROM public.cashbook_accounts ca
  WHERE ca.profile_id = p_profile_id
    AND ca.tenant_id = v_axes.books_tenant_id
    AND ca.currency_code = v_ccy
  LIMIT 1;

  IF v_account_id IS NULL THEN
    SELECT ca.id INTO v_account_id
    FROM public.cashbook_accounts ca
    WHERE ca.tenant_id = v_axes.books_tenant_id
      AND ca.entity_type = v_axes.entity_type
      AND ca.entity_id = v_axes.entity_id
      AND ca.currency_code = v_ccy
    LIMIT 1;

    IF v_account_id IS NOT NULL THEN
      UPDATE public.cashbook_accounts ca
      SET profile_id = p_profile_id, account_class = v_axes.account_class, updated_at = now()
      WHERE ca.id = v_account_id
        AND ca.profile_id IS NULL;
    END IF;
  END IF;

  IF v_account_id IS NULL THEN
    INSERT INTO public.cashbook_accounts (
      tenant_id,
      entity_type,
      entity_id,
      currency_code,
      available_balance,
      pending_balance,
      locked_balance,
      account_class,
      profile_id
    )
    VALUES (
      v_axes.books_tenant_id,
      v_axes.entity_type,
      v_axes.entity_id,
      v_ccy,
      0.0000,
      0.0000,
      0.0000,
      v_axes.account_class,
      p_profile_id
    )
  ON CONFLICT (tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET
    profile_id = coalesce(public.cashbook_accounts.profile_id, excluded.profile_id),
    account_class = excluded.account_class,
    updated_at = now()
  RETURNING id INTO v_account_id;
  END IF;

  SELECT cp.id INTO v_point_id
  FROM public.cashbook_points cp
  WHERE cp.cashbook_account_id = v_account_id
    AND cp.code = 'main'
  LIMIT 1;

  IF v_point_id IS NULL THEN
    INSERT INTO public.cashbook_points (
      tenant_id,
      cashbook_account_id,
      code,
      name,
      is_active
    )
    VALUES (
      v_axes.books_tenant_id,
      v_account_id,
      'main',
      'Main',
      true
    )
    RETURNING id INTO v_point_id;
  END IF;

  v_pot_id := public._kernel_ensure_cashbook_point_pot(v_axes.books_tenant_id, v_point_id, v_ccy);

  UPDATE public.cashbook_accounts ca
  SET
    default_cashbook_point_id = coalesce(ca.default_cashbook_point_id, v_point_id),
    default_cashbook_point_pot_id = coalesce(ca.default_cashbook_point_pot_id, v_pot_id)
  WHERE ca.id = v_account_id;

  RETURN v_account_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_cashbook_account_for_profile(bigint, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._kernel_cashbook_axes_for_profile(bigint) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.upsert_profile_for_party(
  p_tenant_id bigint,
  p_profile_type public.profile_party_type,
  p_subject_id bigint,
  p_name text,
  p_email text DEFAULT NULL::text,
  p_phone text DEFAULT NULL::text,
  p_phone_country_code text DEFAULT '+880'::text,
  p_address text DEFAULT NULL::text,
  p_is_phone_unique boolean DEFAULT true,
  p_accent_color text DEFAULT NULL::text,
  p_is_active boolean DEFAULT true,
  p_deleted_at timestamp with time zone DEFAULT NULL::timestamp with time zone
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_profile_id bigint;
  v_phone_unique boolean;
  v_cashbook_enabled boolean;
BEGIN
  IF p_tenant_id IS NULL OR p_subject_id IS NULL THEN
    RETURN NULL;
  END IF;

  IF nullif(btrim(coalesce(p_name, '')), '') IS NULL THEN
    RAISE EXCEPTION 'profile name is required';
  END IF;

  v_phone_unique := coalesce(p_is_phone_unique, true);
  IF p_phone IS NULL OR btrim(p_phone) = '' THEN
    v_phone_unique := false;
  END IF;

  v_cashbook_enabled := p_profile_type IN (
    'tenant'::public.profile_party_type,
    'customer'::public.profile_party_type,
    'investor'::public.profile_party_type,
    'courier'::public.profile_party_type
  );

  INSERT INTO public.profiles (
    tenant_id,
    profile_type,
    subject_id,
    name,
    email,
    phone,
    phone_country_code,
    address,
    is_phone_unique,
    accent_color,
    is_active,
    deleted_at,
    cashbook_enabled
  )
  VALUES (
    p_tenant_id,
    p_profile_type,
    p_subject_id,
    btrim(p_name),
    nullif(btrim(coalesce(p_email, '')), ''),
    nullif(btrim(coalesce(p_phone, '')), ''),
    coalesce(nullif(btrim(coalesce(p_phone_country_code, '')), ''), '+880'),
    nullif(btrim(coalesce(p_address, '')), ''),
    v_phone_unique,
    nullif(btrim(coalesce(p_accent_color, '')), ''),
    coalesce(p_is_active, true),
    p_deleted_at,
    v_cashbook_enabled
  )
  ON CONFLICT (tenant_id, profile_type, subject_id) DO UPDATE SET
    name = excluded.name,
    email = excluded.email,
    phone = excluded.phone,
    phone_country_code = excluded.phone_country_code,
    address = excluded.address,
    is_phone_unique = excluded.is_phone_unique,
    accent_color = coalesce(excluded.accent_color, profiles.accent_color),
    is_active = excluded.is_active,
    deleted_at = excluded.deleted_at,
    updated_at = now()
  RETURNING id INTO v_profile_id;

  PERFORM public.fn_provision_profile_cashbook_defaults(p_tenant_id, v_profile_id);

  RETURN v_profile_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_profile_for_party(
  bigint,
  public.profile_party_type,
  bigint,
  text,
  text,
  text,
  text,
  text,
  boolean,
  text,
  boolean,
  timestamp with time zone
) TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.profile_auto_provisions_cashbook(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_provision_profile_cashbook_defaults(bigint, bigint) TO authenticated, service_role;

UPDATE public.cashbook_points cp
SET
  code = 'main',
  name = 'Main'
WHERE cp.code = 'office'
  AND NOT EXISTS (
    SELECT 1
    FROM public.cashbook_points cp2
    WHERE cp2.cashbook_account_id = cp.cashbook_account_id
      AND cp2.code = 'main'
      AND cp2.id <> cp.id
  );

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT pr.id, pr.tenant_id
    FROM public.profiles pr
    WHERE public.profile_auto_provisions_cashbook(pr.id)
  LOOP
    PERFORM public.fn_provision_profile_cashbook_defaults(r.tenant_id, r.id);
  END LOOP;
END $$;

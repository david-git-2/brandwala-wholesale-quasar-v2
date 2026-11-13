-- Cashbook accounts keyed by profiles.id; default main point + BDT pot per account.

ALTER TABLE public.cashbook_accounts
  ADD COLUMN IF NOT EXISTS profile_id bigint,
  ADD COLUMN IF NOT EXISTS default_cashbook_point_id bigint,
  ADD COLUMN IF NOT EXISTS default_cashbook_point_pot_id bigint;

CREATE UNIQUE INDEX IF NOT EXISTS cashbook_accounts_profile_currency_uidx
  ON public.cashbook_accounts (tenant_id, profile_id, currency_code)
  WHERE profile_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public._kernel_cashbook_axes_for_profile(p_profile_id bigint)
RETURNS TABLE (
  books_tenant_id bigint,
  entity_type text,
  entity_id bigint,
  account_class public.cashbook_account_class
)
LANGUAGE plpgsql
STABLE
SET search_path TO public
AS $$
DECLARE
  v_pr public.profiles%rowtype;
BEGIN
  SELECT * INTO v_pr FROM public.profiles pr WHERE pr.id = p_profile_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'profile % not found', p_profile_id;
  END IF;

  books_tenant_id := v_pr.tenant_id;

  IF v_pr.profile_type = 'tenant'::public.profile_party_type THEN
    entity_type := 'tenant';
    entity_id := v_pr.subject_id;
    account_class := 'tenant_asset'::public.cashbook_account_class;
  ELSIF v_pr.profile_type = 'customer'::public.profile_party_type THEN
    entity_type := 'customer';
    entity_id := v_pr.id;
    account_class := 'profile_custody'::public.cashbook_account_class;
  ELSIF v_pr.profile_type = 'vendor'::public.profile_party_type THEN
    entity_type := 'vendor';
    entity_id := v_pr.subject_id;
    account_class := 'profile_custody'::public.cashbook_account_class;
  ELSIF v_pr.profile_type = 'cargo'::public.profile_party_type THEN
    entity_type := 'cargo_company';
    entity_id := v_pr.subject_id;
    account_class := 'profile_custody'::public.cashbook_account_class;
  ELSIF v_pr.profile_type = 'courier'::public.profile_party_type THEN
    entity_type := 'courier';
    entity_id := v_pr.subject_id;
    account_class := 'profile_custody'::public.cashbook_account_class;
  ELSIF v_pr.profile_type = 'investor'::public.profile_party_type THEN
    entity_type := 'investor';
    entity_id := v_pr.subject_id;
    account_class := 'profile_custody'::public.cashbook_account_class;
  ELSE
    entity_type := 'customer';
    entity_id := v_pr.id;
    account_class := 'profile_custody'::public.cashbook_account_class;
  END IF;

  RETURN NEXT;
END;
$$;

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

CREATE OR REPLACE FUNCTION public._desk_sync_point_currencies_from_kernel(
  p_profile_id bigint,
  p_location_code text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, money_kernel, pg_temp
AS $$
DECLARE
  v_axes record;
  v_books_tenant_id bigint;
  v_account_id bigint;
  v_point_id bigint;
  v_location_id bigint;
  v_desired text[];
  v_ccy text;
  v_pot record;
BEGIN
  IF p_profile_id IS NULL OR nullif(btrim(coalesce(p_location_code, '')), '') IS NULL THEN
    RETURN;
  END IF;

  SELECT * INTO v_axes FROM public._kernel_cashbook_axes_for_profile(p_profile_id);
  v_books_tenant_id := v_axes.books_tenant_id;

  SELECT cl.id INTO v_location_id
  FROM money_kernel.cashbooks cb
  JOIN money_kernel.cash_locations cl ON cl.cashbook_id = cb.id
  WHERE cb.tenant_id = v_books_tenant_id
    AND cb.profile_id = p_profile_id
    AND cl.location_code = p_location_code
  LIMIT 1;

  IF v_location_id IS NULL THEN
    RETURN;
  END IF;

  SELECT array_agg(DISTINCT upper(btrim(pp.currency_code)) ORDER BY 1)
  INTO v_desired
  FROM money_kernel.cash_bundles pp
  WHERE pp.cash_location_id = v_location_id
    AND pp.closed_at IS NULL;

  IF v_desired IS NULL THEN
    v_desired := ARRAY[]::text[];
  END IF;

  FOREACH v_ccy IN ARRAY v_desired
  LOOP
    v_account_id := public.ensure_cashbook_account_for_profile(p_profile_id, v_ccy);
    SELECT cp.id INTO v_point_id
    FROM public.cashbook_points cp
    WHERE cp.cashbook_account_id = v_account_id
      AND cp.code = p_location_code
    LIMIT 1;
    IF v_point_id IS NULL THEN
      CONTINUE;
    END IF;
    PERFORM public._kernel_ensure_cashbook_point_pot(v_books_tenant_id, v_point_id, v_ccy);
  END LOOP;

  FOR v_pot IN
    SELECT cpp.id, cpp.currency_code, cpp.amount
    FROM public.cashbook_point_pots cpp
    JOIN public.cashbook_points cp ON cp.id = cpp.cashbook_point_id
    JOIN public.cashbook_accounts ca ON ca.id = cp.cashbook_account_id
    WHERE ca.profile_id = p_profile_id
      AND ca.tenant_id = v_books_tenant_id
      AND cp.code = p_location_code
  LOOP
    IF NOT upper(btrim(v_pot.currency_code)) = ANY (v_desired) THEN
      IF coalesce(v_pot.amount, 0) > 0 THEN
        RAISE EXCEPTION
          'Cannot remove % desk pot while balance remains', v_pot.currency_code;
      END IF;
      DELETE FROM public.cashbook_point_pots WHERE id = v_pot.id;
    END IF;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public._desk_sync_point_currencies_from_kernel(bigint, text) TO authenticated, service_role;

-- Cashbook accounts keyed by profiles.id; default office point + BDT pot per account.

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
    AND cp.code = 'office'
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
      'office',
      'Office',
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

-- Drop kind, custodian_membership_id, sort_order from cashbook_points.

ALTER TABLE public.cashbook_points
  DROP CONSTRAINT IF EXISTS cashbook_points_custodian_membership_id_fkey;

DROP INDEX IF EXISTS public.cashbook_points_account_active_idx;

ALTER TABLE public.cashbook_points
  DROP COLUMN IF EXISTS kind,
  DROP COLUMN IF EXISTS custodian_membership_id,
  DROP COLUMN IF EXISTS sort_order;

CREATE INDEX cashbook_points_account_active_idx
  ON public.cashbook_points (cashbook_account_id)
  WHERE is_active = true;

DROP TYPE IF EXISTS public.cashbook_point_kind;

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

-- Kernel bill profile ids -> public.profiles before ensure_cashbook_account_for_profile.

CREATE OR REPLACE FUNCTION public._desk_resolve_public_profile_id_for_cashbook(
  p_books_tenant_id bigint,
  p_profile_id bigint
)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, money_kernel, pg_temp
AS $$
DECLARE
  v_public_id bigint;
BEGIN
  IF p_books_tenant_id IS NULL OR p_profile_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT pr.id INTO v_public_id
  FROM public.profiles pr
  WHERE pr.id = p_profile_id
    AND pr.tenant_id = p_books_tenant_id
    AND pr.deleted_at IS NULL
  LIMIT 1;
  IF v_public_id IS NOT NULL THEN
    RETURN v_public_id;
  END IF;

  SELECT nullif(btrim(mk.meta->>'public_profile_id'), '')::bigint
  INTO v_public_id
  FROM money_kernel.profiles mk
  WHERE mk.tenant_id = p_books_tenant_id
    AND mk.id = p_profile_id
    AND mk.deleted_at IS NULL
  LIMIT 1;
  IF v_public_id IS NOT NULL THEN
    RETURN v_public_id;
  END IF;

  SELECT pr.id INTO v_public_id
  FROM money_kernel.profiles mk
  JOIN public.profiles pr
    ON pr.tenant_id = p_books_tenant_id
   AND pr.deleted_at IS NULL
   AND pr.profile_type::text = mk.profile_type
   AND pr.subject_id = nullif(btrim(mk.meta->>'subject_id'), '')::bigint
  WHERE mk.tenant_id = p_books_tenant_id
    AND mk.id = p_profile_id
    AND mk.deleted_at IS NULL
  LIMIT 1;

  RETURN v_public_id;
END;
$$;

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
  v_ccy text;
  v_public_profile_id bigint;
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

  v_public_profile_id := public._desk_resolve_public_profile_id_for_cashbook(
    p_books_tenant_id,
    p_bill_profile_id
  );
  IF v_public_profile_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_account_id := public.ensure_cashbook_account_for_profile(v_public_profile_id, v_ccy);

  SELECT ca.default_cashbook_point_pot_id
  INTO v_default_pot
  FROM public.cashbook_accounts ca
  WHERE ca.id = v_account_id;

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', cp.id,
      'code', cp.code,
      'name', cp.name,
      'is_active', cp.is_active
    )
    ORDER BY cp.name, cp.id
  ), '[]'::jsonb)
  INTO v_points
  FROM public.cashbook_points cp
  WHERE cp.cashbook_account_id = v_account_id
    AND cp.is_active = true;

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', pp.id,
      'cashbook_point_id', pp.cashbook_point_id,
      'currency_code', upper(trim(pp.currency_code)),
      'amount', pp.amount,
      'point_code', pt.code,
      'point_name', pt.name
    )
    ORDER BY pt.name, pp.currency_code, pp.id
  ), '[]'::jsonb)
  INTO v_pots
  FROM public.cashbook_point_pots pp
  JOIN public.cashbook_points pt ON pt.id = pp.cashbook_point_id
  WHERE pt.cashbook_account_id = v_account_id
    AND pt.is_active = true;

  RETURN jsonb_build_object(
    'profile_id', p_bill_profile_id,
    'public_profile_id', v_public_profile_id,
    'cashbook_account_id', v_account_id,
    'default_pot_id', v_default_pot,
    'points', v_points,
    'pots', v_pots
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._desk_bill_pay_cashbook_legs_json(
  p_tenant_id bigint,
  p_invoice_type text,
  p_from_profile_id bigint,
  p_to_profile_id bigint,
  p_currency_code text
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, money_kernel, pg_temp
AS $$
DECLARE
  v_books_id bigint;
  v_ccy text;
  v_is_ap boolean;
  v_payer_profile_id bigint;
  v_payee_profile_id bigint;
BEGIN
  v_books_id := public.resolve_books_tenant_id(p_tenant_id);
  v_ccy := upper(trim(coalesce(p_currency_code, 'BDT')));
  IF v_ccy = '' THEN
    v_ccy := 'BDT';
  END IF;

  v_is_ap := lower(trim(coalesce(p_invoice_type, ''))) = 'ap';
  v_payer_profile_id := CASE WHEN v_is_ap THEN p_to_profile_id ELSE p_from_profile_id END;
  v_payee_profile_id := CASE WHEN v_is_ap THEN p_from_profile_id ELSE p_to_profile_id END;

  RETURN jsonb_build_object(
    'currency_code', v_ccy,
    'from_leg', public._desk_profile_cashbook_leg_json(v_books_id, v_payer_profile_id, v_ccy),
    'to_leg', public._desk_profile_cashbook_leg_json(v_books_id, v_payee_profile_id, v_ccy)
  );
END;
$$;

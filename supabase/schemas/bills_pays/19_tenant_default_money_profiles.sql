-- Tenant default income/expense sink profiles + pay from/to resolution.

-- Reserved company subject_ids (unique per tenant_id + profile_type).
-- Do not use for real parties.

CREATE OR REPLACE FUNCTION public._kernel_tenant_mirror_profile_id(p_books_tenant_id bigint)
RETURNS bigint
LANGUAGE sql
STABLE
SET search_path TO public
AS $$
  SELECT pr.id
  FROM public.profiles pr
  WHERE pr.tenant_id = p_books_tenant_id
    AND pr.profile_type = 'tenant'::public.profile_party_type
    AND pr.subject_id = p_books_tenant_id
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.ensure_tenant_default_money_profiles(p_books_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_income_id bigint;
  v_expense_id bigint;
  v_pref jsonb;
begin
  if p_books_tenant_id is null then
    raise exception 'books_tenant_id is required';
  end if;

  if not exists (select 1 from public.tenants t where t.id = p_books_tenant_id) then
    raise exception 'tenant % not found', p_books_tenant_id;
  end if;

  v_income_id := public.upsert_profile_for_party(
    p_books_tenant_id,
    'company'::public.profile_party_type,
    -900001,
    'Default income',
    null, null, '+880', null, false, null, true, null
  );

  v_expense_id := public.upsert_profile_for_party(
    p_books_tenant_id,
    'company'::public.profile_party_type,
    -900002,
    'Default expense',
    null, null, '+880', null, false, null, true, null
  );

  update public.tenants t
  set
    preference = coalesce(t.preference, '{}'::jsonb)
      || jsonb_build_object(
        'default_income_profile_id', v_income_id,
        'default_expense_profile_id', v_expense_id
      ),
    updated_at = now()
  where t.id = p_books_tenant_id;

  return jsonb_build_object(
    'default_income_profile_id', v_income_id,
    'default_expense_profile_id', v_expense_id
  );
end;
$$;

CREATE OR REPLACE FUNCTION public.get_tenant_default_income_profile_id(p_books_tenant_id bigint)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_id bigint;
begin
  select nullif(t.preference->>'default_income_profile_id', '')::bigint
  into v_id
  from public.tenants t
  where t.id = p_books_tenant_id;

  if v_id is not null then
    return v_id;
  end if;

  v_id := nullif(public.ensure_tenant_default_money_profiles(p_books_tenant_id)->>'default_income_profile_id', '')::bigint;
  return v_id;
end;
$$;

CREATE OR REPLACE FUNCTION public.get_tenant_default_expense_profile_id(p_books_tenant_id bigint)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_id bigint;
begin
  select nullif(t.preference->>'default_expense_profile_id', '')::bigint
  into v_id
  from public.tenants t
  where t.id = p_books_tenant_id;

  if v_id is not null then
    return v_id;
  end if;

  v_id := nullif(public.ensure_tenant_default_money_profiles(p_books_tenant_id)->>'default_expense_profile_id', '')::bigint;
  return v_id;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_resolve_pay_profile_endpoints(
  p_books_id bigint,
  p_source text,
  p_counterparty_profile_id bigint,
  p_from_profile_id bigint DEFAULT NULL,
  p_to_profile_id bigint DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_note text DEFAULT NULL
)
RETURNS TABLE (
  from_profile_id bigint,
  to_profile_id bigint,
  description text,
  legacy_profile_id bigint
)
LANGUAGE plpgsql
STABLE
SET search_path TO public
AS $$
declare
  v_source text := lower(trim(coalesce(p_source, '')));
  v_tenant_profile bigint;
  v_income bigint;
  v_expense bigint;
  v_from bigint;
  v_to bigint;
  v_desc text;
begin
  perform public.ensure_tenant_default_money_profiles(p_books_id);

  v_tenant_profile := public._kernel_tenant_mirror_profile_id(p_books_id);
  v_income := public.get_tenant_default_income_profile_id(p_books_id);
  v_expense := public.get_tenant_default_expense_profile_id(p_books_id);

  v_desc := coalesce(
    nullif(btrim(coalesce(p_description, '')), ''),
    nullif(btrim(coalesce(p_note, '')), ''),
    ''
  );

  if v_source = 'ap_payout' then
    v_from := coalesce(p_from_profile_id, v_tenant_profile, v_expense);
    v_to := coalesce(p_to_profile_id, p_counterparty_profile_id, v_expense);
  elsif v_source = ANY (ARRAY['customer_cash', 'bank', 'store_credit', 'courier_remittance', 'deposit']) then
    v_from := coalesce(p_from_profile_id, p_counterparty_profile_id, v_income);
    v_to := coalesce(p_to_profile_id, v_tenant_profile, v_income);
  else
    v_from := coalesce(p_from_profile_id, p_counterparty_profile_id, v_income);
    v_to := coalesce(p_to_profile_id, v_tenant_profile, v_expense);
  end if;

  if v_from is null or v_to is null then
    raise exception 'from_profile_id and to_profile_id are required';
  end if;

  return query
  select
    v_from,
    v_to,
    v_desc,
    coalesce(p_counterparty_profile_id, case when v_source = 'ap_payout' then v_to else v_from end);
end;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_tenant_default_money_profiles(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_tenant_default_income_profile_id(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_tenant_default_expense_profile_id(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._kernel_tenant_mirror_profile_id(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._kernel_resolve_pay_profile_endpoints(
  bigint, text, bigint, bigint, bigint, text, text
) TO authenticated, service_role;

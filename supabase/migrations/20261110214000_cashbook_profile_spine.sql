-- Cashbook accounts keyed by profile_id; default office point + BDT pot per profile cashbook.
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
      kind,
      is_active,
      sort_order
    )
    VALUES (
      v_axes.books_tenant_id,
      v_account_id,
      'office',
      'Office',
      'other'::public.cashbook_point_kind,
      true,
      0
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

CREATE OR REPLACE FUNCTION public._kernel_cashbook_money_profile_id(
  p_books_id bigint,
  p_entity_type text,
  p_entity_id bigint
) RETURNS bigint
LANGUAGE sql
STABLE
SET search_path TO public
AS $$
  SELECT CASE p_entity_type
    WHEN 'tenant' THEN (
      SELECT pr.id FROM public.profiles pr
      WHERE pr.tenant_id = p_books_id
        AND pr.profile_type = 'tenant'::public.profile_party_type
        AND pr.subject_id = p_books_id
      LIMIT 1
    )
    WHEN 'customer' THEN p_entity_id
    WHEN 'vendor' THEN (
      SELECT pr.id FROM public.profiles pr
      WHERE pr.tenant_id = p_books_id
        AND pr.profile_type = 'vendor'::public.profile_party_type
        AND pr.subject_id = p_entity_id
      LIMIT 1
    )
    WHEN 'cargo_company' THEN (
      SELECT pr.id FROM public.profiles pr
      WHERE pr.tenant_id = p_books_id
        AND pr.profile_type = 'cargo'::public.profile_party_type
        AND pr.subject_id = p_entity_id
      LIMIT 1
    )
    WHEN 'investor' THEN (
      SELECT pr.id FROM public.profiles pr
      WHERE pr.tenant_id = p_books_id
        AND pr.profile_type = 'investor'::public.profile_party_type
        AND pr.subject_id = p_entity_id
      LIMIT 1
    )
  ELSE p_entity_id
  END;
$$;

CREATE OR REPLACE FUNCTION public."get_cashbook_account_balances"("p_tenant_id" bigint, "p_entity_type" text, "p_entity_id" bigint, "p_currency_code" text DEFAULT 'BDT'::text) RETURNS jsonb
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_result jsonb;
  v_books_id bigint;
  v_entity_id bigint;
  v_profile_id bigint;
BEGIN
  v_books_id := public.resolve_books_tenant_id(p_tenant_id);
  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_books_id;
  END IF;

  v_profile_id := public._kernel_cashbook_money_profile_id(v_books_id, p_entity_type, p_entity_id);

  SELECT jsonb_build_object(
    'tenant_id', v_books_id,
    'profile_id', w.profile_id,
    'entity_type', p_entity_type,
    'entity_id', v_entity_id,
    'currency_code', coalesce(w.currency_code, p_currency_code),
    'available_balance', coalesce(w.available_balance, 0.0000),
    'pending_balance', coalesce(w.pending_balance, 0.0000),
    'locked_balance', coalesce(w.locked_balance, 0.0000),
    'default_cashbook_point_id', w.default_cashbook_point_id,
    'default_cashbook_point_pot_id', w.default_cashbook_point_pot_id,
    'total_balance', (
      coalesce(w.available_balance, 0.0000)
      + coalesce(w.pending_balance, 0.0000)
      + coalesce(w.locked_balance, 0.0000)
    ),
    'account_class', coalesce(w.account_class::text, case when p_entity_type = 'tenant' then 'tenant_asset' else 'profile_custody' end)
  )
  INTO v_result
  FROM (SELECT 1) dummy
  LEFT JOIN public.cashbook_accounts w
    ON w.tenant_id = v_books_id
   AND w.currency_code = coalesce(p_currency_code, 'BDT')
   AND (
     (v_profile_id IS NOT NULL AND w.profile_id = v_profile_id)
     OR (
       w.profile_id IS NULL
       AND w.entity_type = p_entity_type
       AND w.entity_id = v_entity_id
     )
   );

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public."get_cashbook_detail_for_staff"("p_tenant_id" bigint, "p_entity_type" text, "p_entity_id" bigint, "p_currency_code" text DEFAULT 'BDT'::text) RETURNS jsonb
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_operating_id bigint;
  v_name text;
  v_code text;
  v_caption text;
  v_source_uuid uuid;
  v_entity_id bigint;
  v_account jsonb;
BEGIN
  v_books_id := public.resolve_books_tenant_id(p_tenant_id);
  v_operating_id := p_tenant_id;
  v_entity_id := p_entity_id;

  IF NOT (
    public.cashbook_staff_can_view(p_tenant_id)
    OR public.membership_has_module_action(v_books_id, 'payments', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'view')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_books_id;
    SELECT t.name INTO v_name FROM public.tenants t WHERE t.id = v_books_id;
    IF v_name IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'entity not found');
    END IF;
    v_caption := 'Company cash pool';

  ELSIF p_entity_type = 'customer' THEN
    SELECT
      CASE WHEN cg.name IS NOT NULL THEN cg.name || ' · ' || pr.name ELSE pr.name END,
      nullif(trim(concat_ws(' • ', pr.phone, pr.email)), '')
    INTO v_name, v_caption
    FROM public.profiles pr
    LEFT JOIN public.customer_groups cg ON cg.id = pr.customer_group_id
    WHERE pr.id = p_entity_id
      AND (pr.operating_tenant_id = v_books_id OR pr.operating_tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id));
    IF v_name IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'entity not found');
    END IF;

  ELSIF p_entity_type = 'vendor' THEN
    SELECT v.name, v.code, nullif(trim(concat_ws(' • ', v.phone, v.email)), '')
    INTO v_name, v_code, v_caption
    FROM public.vendors v WHERE v.id = p_entity_id AND v.tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'cargo_company' THEN
    SELECT c.name, c.code, nullif(trim(concat_ws(' • ', c.phone, c.email)), '')
    INTO v_name, v_code, v_caption
    FROM public.cargo_companies c WHERE c.id = p_entity_id AND c.tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'courier' THEN
    SELECT cs.name, upper(cs.code), coalesce(nullif(trim(cs.notes), ''), 'Courier service'), cs.id
    INTO v_name, v_code, v_caption, v_source_uuid
    FROM public.courier_services cs
    WHERE cs.wallet_entity_id = p_entity_id AND cs.is_active = true
      AND (cs.tenant_id IS NULL OR cs.tenant_id = v_books_id
           OR cs.tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id));
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'investor' THEN
    SELECT i.name, nullif(trim(concat_ws(' • ', i.phone, i.email)), '')
    INTO v_name, v_caption
    FROM public.investors i WHERE i.id = p_entity_id AND i.tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'invalid entity_type');
  END IF;

  v_account := public.get_cashbook_account_balances(v_books_id, p_entity_type, v_entity_id, p_currency_code);

  RETURN jsonb_build_object(
    'success', true,
    'books_tenant_id', v_books_id,
    'operating_tenant_id', v_operating_id,
    'entity', jsonb_build_object(
      'entity_type', p_entity_type,
      'entity_id', v_entity_id,
      'name', v_name,
      'code', v_code,
      'caption', v_caption,
      'source_uuid', v_source_uuid
    ),
    'account', jsonb_build_object(
      'currency_code', coalesce(v_account->>'currency_code', p_currency_code),
      'available_balance', coalesce((v_account->>'available_balance')::numeric, 0),
      'pending_balance', coalesce((v_account->>'pending_balance')::numeric, 0),
      'locked_balance', coalesce((v_account->>'locked_balance')::numeric, 0),
      'total_balance', coalesce((v_account->>'total_balance')::numeric, 0),
      'account_class', coalesce(v_account->>'account_class', case when p_entity_type = 'tenant' then 'tenant_asset' else 'profile_custody' end)
    ),
    'permissions', jsonb_build_object(
      'can_record_manual', public.cashbook_staff_can_edit(p_tenant_id),
      'can_reverse', public.cashbook_staff_can_edit(p_tenant_id)
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public."record_ledger_transaction"("p_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_entity_type" text, "p_entity_id" bigint, "p_type" text, "p_amount" numeric, "p_currency_code" text DEFAULT 'BDT'::text, "p_exchange_rate" numeric DEFAULT 1.000000, "p_source_type" text DEFAULT 'adjustment'::text, "p_source_id" text DEFAULT NULL::text, "p_metadata" jsonb DEFAULT '{}'::jsonb, "p_target_bucket" text DEFAULT 'available'::text, "p_allow_overdraft" boolean DEFAULT false, "p_cashbook_point_id" bigint DEFAULT NULL::bigint) RETURNS jsonb
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_account_id bigint;
  v_avail numeric(18,4);
  v_pend numeric(18,4);
  v_lock numeric(18,4);
  v_base_amount numeric(18,4);
  v_new_balance numeric(18,4);
  v_ledger_entry jsonb;
  v_ledger_id uuid;
  v_entity_id bigint;
  v_point_ok boolean;
  v_pot_id bigint;
  v_pot_amt numeric(12, 2);
  v_profile_id bigint;
  v_account_class public.cashbook_account_class;
BEGIN
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transaction amount must be greater than zero.';
  END IF;

  IF p_type NOT IN ('credit', 'debit') THEN
    RAISE EXCEPTION 'Transaction type must be credit or debit.';
  END IF;

  IF p_target_bucket NOT IN ('available', 'pending', 'locked') THEN
    RAISE EXCEPTION 'Target bucket must be available, pending, or locked.';
  END IF;

  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' AND v_entity_id IS DISTINCT FROM p_tenant_id THEN
    v_entity_id := p_tenant_id;
  END IF;

  v_profile_id := public._kernel_cashbook_money_profile_id(p_tenant_id, p_entity_type, p_entity_id);
  v_account_class := CASE
    WHEN p_entity_type = 'tenant' THEN 'tenant_asset'::public.cashbook_account_class
    ELSE 'profile_custody'::public.cashbook_account_class
  END;

  IF v_profile_id IS NOT NULL THEN
    PERFORM public.ensure_cashbook_account_for_profile(v_profile_id, coalesce(p_currency_code, 'BDT'));
  END IF;

  INSERT INTO public.cashbook_accounts (
    tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance, account_class, profile_id
  )
  VALUES (
    p_tenant_id, p_entity_type, v_entity_id,
    coalesce(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000,
    v_account_class,
    v_profile_id
  )
  ON CONFLICT (tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET
    profile_id = coalesce(public.cashbook_accounts.profile_id, excluded.profile_id),
    updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  IF v_profile_id IS NOT NULL AND v_account_id IS NOT NULL THEN
    UPDATE public.cashbook_accounts ca
    SET profile_id = coalesce(ca.profile_id, v_profile_id)
    WHERE ca.id = v_account_id
      AND ca.profile_id IS NULL;
  END IF;

  IF p_cashbook_point_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.cashbook_points cp
      WHERE cp.id = p_cashbook_point_id
        AND cp.tenant_id = p_tenant_id
        AND cp.cashbook_account_id = v_account_id
        AND cp.is_active = true
    ) INTO v_point_ok;
    IF NOT coalesce(v_point_ok, false) THEN
      RAISE EXCEPTION 'Invalid cashbook point for this account.';
    END IF;

    v_pot_id := public._kernel_ensure_cashbook_point_pot(
      p_tenant_id,
      p_cashbook_point_id,
      coalesce(p_currency_code, 'BDT')
    );
    PERFORM 1
    FROM public.cashbook_point_pots cpp
    WHERE cpp.id = v_pot_id
    FOR UPDATE;

    IF p_type = 'debit' THEN
      SELECT cpp.amount
      INTO v_pot_amt
      FROM public.cashbook_point_pots cpp
      WHERE cpp.id = v_pot_id;

      IF coalesce(v_pot_amt, 0) < p_amount THEN
        IF NOT coalesce(p_allow_overdraft, false) THEN
          RAISE EXCEPTION 'Insufficient cash in till (available: %, requested: %).',
            coalesce(v_pot_amt, 0), p_amount;
        END IF;
        v_pot_id := NULL;
      END IF;
    END IF;
  END IF;

  SELECT available_balance, pending_balance, locked_balance
  INTO v_avail, v_pend, v_lock
  FROM public.cashbook_accounts
  WHERE id = v_account_id
  FOR UPDATE;

  IF p_target_bucket = 'available' THEN
    IF p_type = 'credit' THEN
      v_avail := v_avail + p_amount;
    ELSE
      IF v_avail < p_amount AND NOT coalesce(p_allow_overdraft, false) THEN
        RAISE EXCEPTION 'Insufficient available balance (available: %, requested debit: %).',
          v_avail, p_amount;
      END IF;
      v_avail := v_avail - p_amount;
    END IF;
    v_new_balance := v_avail;
  ELSIF p_target_bucket = 'pending' THEN
    IF p_type = 'credit' THEN
      v_pend := v_pend + p_amount;
    ELSE
      v_pend := v_pend - p_amount;
    END IF;
    v_new_balance := v_pend;
  ELSIF p_target_bucket = 'locked' THEN
    IF p_type = 'credit' THEN
      v_lock := v_lock + p_amount;
    ELSE
      v_lock := v_lock - p_amount;
    END IF;
    v_new_balance := v_lock;
  END IF;

  UPDATE public.cashbook_accounts
  SET
    available_balance = v_avail,
    pending_balance = v_pend,
    locked_balance = v_lock,
    tenant_id = p_tenant_id,
    updated_at = now()
  WHERE id = v_account_id;

  v_base_amount := p_amount * coalesce(p_exchange_rate, 1.000000);

  INSERT INTO public.cashbook_entries (
    tenant_id,
    operating_tenant_id,
    entity_type,
    entity_id,
    type,
    amount,
    currency_code,
    exchange_rate,
    base_amount,
    balance_after,
    source_type,
    source_id,
    metadata,
    cashbook_point_id,
    cashbook_point_pot_id
  )
  VALUES (
    p_tenant_id,
    p_operating_tenant_id,
    p_entity_type,
    v_entity_id,
    p_type,
    p_amount,
    coalesce(p_currency_code, 'BDT'),
    coalesce(p_exchange_rate, 1.000000),
    v_base_amount,
    v_new_balance,
    coalesce(p_source_type, 'adjustment'),
    p_source_id,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object('target_bucket', p_target_bucket),
    p_cashbook_point_id,
    v_pot_id
  )
  RETURNING id INTO v_ledger_id;

  SELECT jsonb_build_object(
    'id', id,
    'tenant_id', tenant_id,
    'operating_tenant_id', operating_tenant_id,
    'entity_type', entity_type,
    'entity_id', entity_id,
    'type', type,
    'amount', amount,
    'currency_code', currency_code,
    'exchange_rate', exchange_rate,
    'base_amount', base_amount,
    'balance_after', balance_after,
    'source_type', source_type,
    'source_id', source_id,
    'metadata', metadata,
    'cashbook_point_id', cashbook_point_id,
    'created_at', created_at
  ) INTO v_ledger_entry
  FROM public.cashbook_entries
  WHERE id = v_ledger_id;

  RETURN v_ledger_entry;
END;
$$;


UPDATE public.cashbook_accounts ca
SET profile_id = sub.profile_id
FROM (
  SELECT
    ca2.id,
    public._kernel_cashbook_money_profile_id(
      ca2.tenant_id,
      ca2.entity_type,
      CASE
        WHEN ca2.entity_type = 'tenant' THEN ca2.tenant_id
        ELSE ca2.entity_id
      END
    ) AS profile_id
  FROM public.cashbook_accounts ca2
  WHERE ca2.profile_id IS NULL
) sub
WHERE ca.id = sub.id
  AND sub.profile_id IS NOT NULL;

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT DISTINCT ca.profile_id AS id
    FROM public.cashbook_accounts ca
    WHERE ca.profile_id IS NOT NULL
  LOOP
    PERFORM public.ensure_cashbook_account_for_profile(r.id);
  END LOOP;

  FOR r IN
    SELECT pr.id
    FROM public.profiles pr
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.cashbook_accounts ca
      WHERE ca.profile_id = pr.id
        AND ca.currency_code = 'BDT'
    )
  LOOP
    PERFORM public.ensure_cashbook_account_for_profile(r.id);
  END LOOP;
END $$;

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
declare
  v_profile_id bigint;
  v_phone_unique boolean;
begin
  if p_tenant_id is null or p_subject_id is null then
    return null;
  end if;

  if nullif(btrim(coalesce(p_name, '')), '') is null then
    raise exception 'profile name is required';
  end if;

  v_phone_unique := coalesce(p_is_phone_unique, true);
  if p_phone is null or btrim(p_phone) = '' then
    v_phone_unique := false;
  end if;

  insert into public.profiles (
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
    deleted_at
  )
  values (
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
    p_deleted_at
  )
  on conflict (tenant_id, profile_type, subject_id) do update set
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
  returning id into v_profile_id;

  perform public.ensure_cashbook_account_for_profile(v_profile_id);

  return v_profile_id;
end;
$$;


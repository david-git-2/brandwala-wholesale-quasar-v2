-- Money spine v2 — internal helpers, access control, shared write utilities.

CREATE OR REPLACE FUNCTION public.auth_tenant_id()
RETURNS bigint
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.tenant_id', true), '')::bigint;
$$;

CREATE OR REPLACE FUNCTION money_kernel.membership_has_money_action(
  p_uid       uuid,
  p_tenant_id bigint,
  p_action    text
) RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_module text;
  v_grant  text;
BEGIN
  CASE p_action
    WHEN 'deposit' THEN v_module := 'payments'; v_grant := 'collect_payment';
    WHEN 'withdraw' THEN v_module := 'payments'; v_grant := 'collect_payment';
    WHEN 'transfer' THEN v_module := 'payments'; v_grant := 'allocate_payment';
    WHEN 'pay' THEN v_module := 'payments'; v_grant := 'allocate_payment';
    WHEN 'void' THEN v_module := 'payments'; v_grant := 'void';
    WHEN 'write_off' THEN v_module := 'global_invoice'; v_grant := 'edit';
    WHEN 'fx_override' THEN v_module := 'payments'; v_grant := 'allocate_payment';
    WHEN 'bills' THEN v_module := 'global_invoice'; v_grant := 'edit';
    ELSE RETURN false;
  END CASE;
  RETURN public.membership_has_module_action(p_tenant_id, v_module, v_grant);
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.profile_spend_allowed(
  p_uid       uuid,
  p_tenant_id bigint,
  p_profile_id bigint
) RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.profiles pr
     WHERE pr.id = p_profile_id
       AND pr.tenant_id = p_tenant_id
       AND pr.deleted_at IS NULL
       AND pr.is_active = true
  );
$$;

CREATE OR REPLACE FUNCTION public.assert_kernel_money_access(
  p_tenant_id   bigint,
  p_action      text DEFAULT 'pay',
  p_profile_id  bigint DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF p_tenant_id IS NULL OR p_action IS NULL THEN
    RAISE EXCEPTION 'access_denied: invalid_arguments';
  END IF;

  IF v_uid IS NULL THEN
    IF current_setting('request.jwt.claim.role', true) = 'service_role' THEN
      RETURN;
    END IF;
    RAISE EXCEPTION 'access_denied: not_authenticated';
  END IF;

  IF NOT money_kernel.membership_has_money_action(v_uid, p_tenant_id, p_action) THEN
    RAISE EXCEPTION 'access_denied: tenant % action %', p_tenant_id, p_action;
  END IF;

  IF p_profile_id IS NOT NULL
     AND p_action IN ('withdraw', 'transfer', 'pay')
     AND NOT money_kernel.profile_spend_allowed(v_uid, p_tenant_id, p_profile_id) THEN
    RAISE EXCEPTION 'access_denied: profile %', p_profile_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_assert_idem_match(
  p_existing_hash text,
  p_request_hash  text
) RETURNS void
LANGUAGE plpgsql
IMMUTABLE
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  IF p_existing_hash IS NOT NULL
     AND p_request_hash IS NOT NULL
     AND p_existing_hash IS DISTINCT FROM p_request_hash THEN
    RAISE EXCEPTION 'idempotency_conflict: request_hash mismatch';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_resolve_books_rate(
  p_tenant_id     bigint,
  p_currency_code text,
  p_allow_override boolean DEFAULT false,
  p_override_rate  numeric DEFAULT NULL
) RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_rate numeric(15, 6);
  v_code text := upper(btrim(p_currency_code));
BEGIN
  IF v_code = 'BDT' THEN
    RETURN 1;
  END IF;

  IF p_allow_override AND p_override_rate IS NOT NULL AND p_override_rate > 0 THEN
    IF NOT money_kernel.membership_has_money_action(auth.uid(), p_tenant_id, 'fx_override') THEN
      RAISE EXCEPTION 'access_denied: fx_override required';
    END IF;
    RETURN p_override_rate;
  END IF;

  SELECT r.rate INTO v_rate
    FROM public.books_exchange_rates r
   WHERE r.tenant_id = p_tenant_id
     AND upper(r.quote_currency_code) = v_code
     AND upper(r.base_currency_code) = 'BDT'
   ORDER BY r.rate_date DESC NULLS LAST, r.id DESC
   LIMIT 1;

  IF v_rate IS NULL OR v_rate <= 0 THEN
    RAISE EXCEPTION 'not_found: books rate for %', v_code;
  END IF;
  RETURN v_rate;
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_resolve_transfer_rate(
  p_from_currency text,
  p_to_currency   text,
  p_tenant_id     bigint
) RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_from text := upper(btrim(p_from_currency));
  v_to   text := upper(btrim(p_to_currency));
  v_from_bdt numeric;
  v_to_bdt   numeric;
BEGIN
  IF v_from = v_to THEN
    RETURN 1;
  END IF;
  v_from_bdt := money_kernel.fn_resolve_books_rate(p_tenant_id, v_from);
  v_to_bdt := money_kernel.fn_resolve_books_rate(p_tenant_id, v_to);
  RETURN round(v_from_bdt / v_to_bdt, 6);
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_tenant_payment_date(p_tenant_id bigint)
RETURNS date
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT (now() AT TIME ZONE public._document_number_tenant_timezone(p_tenant_id, 'Asia/Dhaka'))::date;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_post_pays(p_row money_kernel.pays)
RETURNS money_kernel.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_row money_kernel.pays;
BEGIN
  UPDATE money_kernel.pays
     SET status = 'posted',
         updated_at = now()
   WHERE id = p_row.id
     AND tenant_id = p_row.tenant_id
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_kernel_settlement_delete_allowed()
RETURNS void
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  PERFORM set_config('money.allow_kernel_delete', '1', true);
  PERFORM set_config('money.allow_settlement_delete', '1', true);
END;
$$;

-- Bill parties use public.profiles.id; provision kernel cashbook for that profile.
CREATE OR REPLACE FUNCTION money_kernel.ensure_profile_for_public_party(
  p_books_tenant_id bigint,
  p_public_profile_id bigint
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, money_kernel, pg_temp
AS $$
BEGIN
  PERFORM public.money_kernel_assert_profile_in_tenant(p_books_tenant_id, p_public_profile_id);
  PERFORM public.fn_provision_kernel_cashbook_for_profile_row(p_books_tenant_id, p_public_profile_id);
  RETURN p_public_profile_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.money_kernel_assert_profile_in_tenant(
  p_books_tenant_id bigint,
  p_profile_id bigint
)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_profile_id IS NULL THEN
    RAISE EXCEPTION 'not_found: profile required';
  END IF;
  PERFORM 1
  FROM public.profiles pr
  WHERE pr.id = p_profile_id
    AND pr.tenant_id = p_books_tenant_id
    AND pr.deleted_at IS NULL
    AND pr.is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: profile % in tenant %', p_profile_id, p_books_tenant_id;
  END IF;
END;
$$;

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

DROP FUNCTION IF EXISTS public.fn_provision_kernel_cashbook_currency(bigint, bigint, text);
DROP FUNCTION IF EXISTS public.fn_provision_kernel_cashbook_currency(bigint, bigint, text, text);

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

CREATE OR REPLACE FUNCTION money_kernel.validate_bill_source_plug(
  p_source_entity text,
  p_source_type   text,
  p_source_id     text,
  p_source_key    text
) RETURNS void
LANGUAGE plpgsql
STABLE
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_entity text := nullif(btrim(p_source_entity), '');
  v_type   text := nullif(btrim(p_source_type), '');
  v_id     text := nullif(btrim(p_source_id), '');
  v_key    text := nullif(btrim(p_source_key), '');
BEGIN
  IF v_entity IS NULL AND v_type IS NULL AND v_id IS NULL AND v_key IS NULL THEN
    RETURN;
  END IF;

  IF v_entity IS NULL AND (v_id IS NOT NULL OR v_key IS NOT NULL) THEN
    RAISE EXCEPTION 'invalid_arguments: source_entity required when source_id or source_key is set';
  END IF;

  IF v_entity IS NOT NULL AND v_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: source_id required when source_entity is set';
  END IF;

  IF v_entity IS NOT NULL
     AND v_entity !~ '^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$' THEN
    RAISE EXCEPTION
      'invalid_arguments: source_entity % must be schema.table (e.g. public.global_shipments)',
      v_entity;
  END IF;

  IF v_id IS NOT NULL AND v_id ~ '^\d+$' AND v_id::bigint <= 0 THEN
    RAISE EXCEPTION 'invalid_arguments: source_id must be a positive id';
  END IF;
END;
$$;

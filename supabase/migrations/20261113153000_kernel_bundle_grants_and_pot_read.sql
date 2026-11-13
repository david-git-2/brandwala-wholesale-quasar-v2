-- Grants on cash_bundles (table created after 26_grants); definer pot reads; desk provision access.

GRANT SELECT ON money_kernel.cash_bundles TO authenticated, service_role;
GRANT SELECT ON money_kernel.pay_bundle_lines TO authenticated, service_role;

DROP POLICY IF EXISTS mk_cash_bundles_select ON money_kernel.cash_bundles;
CREATE POLICY mk_cash_bundles_select ON money_kernel.cash_bundles
  FOR SELECT TO authenticated
  USING (tenant_id = (SELECT public.auth_tenant_id()));

DROP POLICY IF EXISTS mk_pay_bundle_lines_select ON money_kernel.pay_bundle_lines;
CREATE POLICY mk_pay_bundle_lines_select ON money_kernel.pay_bundle_lines
  FOR SELECT TO authenticated
  USING (tenant_id = (SELECT public.auth_tenant_id()));

CREATE OR REPLACE FUNCTION money_kernel.assert_kernel_money_read(
  p_tenant_id bigint
) RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'access_denied: invalid_arguments';
  END IF;
  IF v_uid IS NULL THEN
    IF current_setting('request.jwt.claim.role', true) = 'service_role' THEN
      RETURN;
    END IF;
    RAISE EXCEPTION 'access_denied: not_authenticated';
  END IF;
  IF money_kernel.membership_has_money_action(v_uid, p_tenant_id, 'pay')
     OR money_kernel.membership_has_money_action(v_uid, p_tenant_id, 'deposit')
     OR public.membership_has_module_action(p_tenant_id, 'global_invoice', 'view')
     OR public.membership_has_module_action(p_tenant_id, 'payments', 'view') THEN
    RETURN;
  END IF;
  RAISE EXCEPTION 'access_denied: tenant %', p_tenant_id;
END;
$$;

GRANT EXECUTE ON FUNCTION money_kernel.assert_kernel_money_read(bigint) TO authenticated, service_role;

-- rpc_get_pot_balance / rpc_get_pot_balances: body patched via schema sync; minimal migration replaces headers + add guard.
-- Full bodies live in schemas/money_kernel_v2/25_money_kernel_rpcs_read.sql after next declarative sync.
-- Apply critical access fix on provision RPC now:

CREATE OR REPLACE FUNCTION public.rpc_provision_cashbook_currency(
  p_tenant_id     bigint,
  p_profile_id    bigint,
  p_currency_code text,
  p_point_code    text DEFAULT 'main'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
  v_account_id bigint;
  v_point_id   bigint;
  v_lot_id     bigint;
BEGIN

  v_books_rate := money_kernel.fn_resolve_books_rate(p_tenant_id, COALESCE(p_currency_code, 'BDT'));
  v_exchange_rate := 1;
  PERFORM money_kernel.assert_kernel_money_read(p_tenant_id);

  v_account_id := public.fn_provision_kernel_cashbook_for_profile_row(p_tenant_id, p_profile_id);
  IF v_account_id IS NULL THEN
    RAISE EXCEPTION
      'not_found: cashbook for profile %; profile may not exist or cashbook_enabled=false', p_profile_id;
  END IF;

  v_lot_id := public.fn_provision_kernel_cashbook_currency(
    p_tenant_id, p_profile_id, p_currency_code, p_point_code
  );

  SELECT cp.id INTO v_point_id
    FROM money_kernel.cash_locations cp
   WHERE cp.cashbook_id = v_account_id AND cp.location_code = p_point_code
   LIMIT 1;

  RETURN jsonb_build_object(
    'cashbook_id', v_account_id,
    'cash_location_id', v_point_id,
    'pot_id', v_lot_id,
    'currency_code', p_currency_code
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_get_pot_balance(
  p_tenant_id    bigint,
  p_pot_id       bigint  DEFAULT NULL,
  p_entity_type  text    DEFAULT NULL,
  p_entity_id    bigint  DEFAULT NULL,
  p_currency     text    DEFAULT 'BDT'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_pot     money_kernel.cash_bundles;
  v_account money_kernel.cashbooks;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id required';
  END IF;

  PERFORM money_kernel.assert_kernel_money_read(p_tenant_id);

  IF p_pot_id IS NOT NULL THEN
    SELECT pp.* INTO v_pot
      FROM money_kernel.cash_bundles pp
      WHERE pp.id = p_pot_id AND pp.tenant_id = p_tenant_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'not_found: pot % in tenant %', p_pot_id, p_tenant_id;
    END IF;

    SELECT a.* INTO v_account
      FROM money_kernel.cash_locations pt
      JOIN money_kernel.cashbooks a ON a.id = pt.cashbook_id
     WHERE pt.id = v_pot.cash_location_id;

  ELSIF p_entity_type IS NOT NULL AND p_entity_id IS NOT NULL THEN
    SELECT pp.* INTO v_pot
      FROM money_kernel.cashbooks a
      LEFT JOIN money_kernel.cash_bundles pp_default
        ON pp_default.id = a.default_cash_bundle_id
      JOIN money_kernel.cash_locations pt ON pt.cashbook_id = a.id
      JOIN money_kernel.cash_bundles pp ON pp.cash_location_id = pt.id
     WHERE a.tenant_id = p_tenant_id
       AND p_entity_type = 'profile'
       AND a.profile_id = p_entity_id
       AND pp.currency_code = p_currency
     ORDER BY (a.default_cash_bundle_id = pp.id) DESC, pp.id ASC
     LIMIT 1;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'not_found: no % pot for entity %/%', p_currency, p_entity_type, p_entity_id;
    END IF;

    SELECT * INTO v_account FROM money_kernel.cashbooks
      WHERE tenant_id = p_tenant_id AND profile_id = p_entity_id;

  ELSE
    RAISE EXCEPTION
      'invalid_arguments: must pass pot_id OR (entity_type AND entity_id)';
  END IF;

  RETURN jsonb_build_object(
    'pot_id',          v_pot.id,
    'tenant_id',       v_pot.tenant_id,
    'cash_location_id', v_pot.cash_location_id,
    'profile_id',      v_account.profile_id,
    'currency_code',   v_pot.currency_code,
    'amount',          v_pot.amount,
    'updated_at',      v_pot.updated_at,
    'echoed_filters',  jsonb_build_object(
      'pot_id',      p_pot_id,
      'entity_type', p_entity_type,
      'entity_id',   p_entity_id,
      'currency',    p_currency
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_get_pot_balances(
  p_tenant_id    bigint,
  p_entity_type  text    DEFAULT 'profile',
  p_entity_ids   bigint[] DEFAULT NULL,
  p_currencies   text[]  DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_rows jsonb;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id required';
  END IF;

  PERFORM money_kernel.assert_kernel_money_read(p_tenant_id);

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'pot_id',        pp.id,
    'profile_id',    a.profile_id,
    'currency_code', pp.currency_code,
    'amount',        pp.amount,
    'updated_at',    pp.updated_at
  ) ORDER BY a.profile_id, pp.currency_code), '[]'::jsonb)
  INTO v_rows
  FROM money_kernel.cash_bundles pp
  JOIN money_kernel.cash_locations   pt ON pt.id = pp.cash_location_id
  JOIN money_kernel.cashbooks a  ON a.id  = pt.cashbook_id
  WHERE pp.tenant_id = p_tenant_id
    AND (p_entity_type IS NULL OR p_entity_type = 'profile')
    AND (p_entity_ids IS NULL OR a.profile_id = ANY(p_entity_ids))
    AND (p_currencies IS NULL OR pp.currency_code = ANY(p_currencies));

  RETURN jsonb_build_object(
    'rows',           v_rows,
    'count',          jsonb_array_length(v_rows),
    'echoed_filters', jsonb_build_object(
      'tenant_id',   p_tenant_id,
      'entity_type', p_entity_type,
      'entity_ids',  p_entity_ids,
      'currencies',  p_currencies
    )
  );
END;
$$;

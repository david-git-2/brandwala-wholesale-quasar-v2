-- Cash bundle soft-close (closed_at) + close/list RPCs

ALTER TABLE money_kernel.cash_bundles
  ADD COLUMN IF NOT EXISTS closed_at timestamptz;

CREATE INDEX IF NOT EXISTS ix_bundles_open_location
  ON money_kernel.cash_bundles (cash_location_id, currency_code)
  WHERE closed_at IS NULL;

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
  v_ccy_pot bigint;
  v_ccy text;
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

  BEGIN
    PERFORM public.money_kernel_assert_profile_in_tenant(p_books_tenant_id, p_bill_profile_id);
  EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
  END;

  PERFORM public.fn_provision_kernel_cashbook_for_profile_row(p_books_tenant_id, p_bill_profile_id);
  PERFORM public.fn_provision_kernel_cashbook_currency(p_books_tenant_id, p_bill_profile_id, v_ccy);

  SELECT ca.id, ca.default_cash_bundle_id
  INTO v_account_id, v_default_pot
  FROM money_kernel.cashbooks ca
  WHERE ca.tenant_id = p_books_tenant_id
    AND ca.profile_id = p_bill_profile_id
  LIMIT 1;

  IF v_account_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT pp.id INTO v_ccy_pot
  FROM money_kernel.cash_bundles pp
  JOIN money_kernel.cash_locations pt ON pt.id = pp.cash_location_id
  WHERE pt.cashbook_id = v_account_id
    AND upper(trim(pp.currency_code)) = v_ccy
    AND pp.closed_at IS NULL
  ORDER BY pt.location_code, pp.id
  LIMIT 1;

  v_default_pot := coalesce(v_ccy_pot, v_default_pot);

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', cp.id,
      'code', cp.location_code,
      'name', cp.name,
      'is_active', true
    )
    ORDER BY cp.name, cp.id
  ), '[]'::jsonb)
  INTO v_points
  FROM money_kernel.cash_locations cp
  WHERE cp.cashbook_id = v_account_id;

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', pp.id,
      'cash_location_id', pp.cash_location_id,
      'cashbook_point_id', pp.cash_location_id,
      'currency_code', upper(trim(pp.currency_code)),
      'amount', pp.amount,
      'books_rate', pp.books_rate,
      'drawer_group', pp.drawer_group,
      'point_code', pt.location_code,
      'point_name', pt.name
    )
    ORDER BY pt.name, pp.currency_code, pp.id
  ), '[]'::jsonb)
  INTO v_pots
  FROM money_kernel.cash_bundles pp
  JOIN money_kernel.cash_locations pt ON pt.id = pp.cash_location_id
  WHERE pt.cashbook_id = v_account_id
    AND pp.closed_at IS NULL;

  RETURN jsonb_build_object(
    'profile_id', p_bill_profile_id,
    'cashbook_id', v_account_id,
    'default_pot_id', v_default_pot,
    'points', v_points,
    'pots', v_pots
  );
END;
$$;
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
    AND pp.closed_at IS NULL
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

CREATE OR REPLACE FUNCTION public.rpc_list_profile_cashbook_bundles(
  p_tenant_id bigint,
  p_profile_id bigint
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_bundles jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_profile_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id and profile_id required';
  END IF;

  PERFORM public.money_kernel_assert_profile_in_tenant(p_tenant_id, p_profile_id);
  PERFORM money_kernel.assert_kernel_money_read(p_tenant_id);

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'bundle_id', pp.id,
      'cash_location_id', pp.cash_location_id,
      'location_code', pt.location_code,
      'location_name', pt.name,
      'desk_point_id', cp.id,
      'currency_code', upper(btrim(pp.currency_code)),
      'amount', pp.amount,
      'books_rate', pp.books_rate
    )
    ORDER BY pt.name, pp.currency_code, pp.books_rate, pp.id
  ), '[]'::jsonb)
  INTO v_bundles
  FROM money_kernel.cash_bundles pp
  JOIN money_kernel.cash_locations pt ON pt.id = pp.cash_location_id
  JOIN money_kernel.cashbooks ca ON ca.id = pt.cashbook_id
  LEFT JOIN public.cashbook_accounts acc
    ON acc.profile_id = ca.profile_id
   AND acc.tenant_id = ca.tenant_id
   AND upper(btrim(acc.currency_code)) = upper(btrim(pp.currency_code))
  LEFT JOIN public.cashbook_points cp
    ON cp.cashbook_account_id = acc.id
   AND cp.code = pt.location_code
  WHERE ca.tenant_id = p_tenant_id
    AND ca.profile_id = p_profile_id
    AND pp.closed_at IS NULL;

  RETURN jsonb_build_object(
    'profile_id', p_profile_id,
    'bundles', v_bundles
  );
END;
$$;
CREATE OR REPLACE FUNCTION public.rpc_close_cash_bundle(
  p_tenant_id       bigint,
  p_profile_id      bigint,
  p_bundle_id       bigint,
  p_meta            jsonb DEFAULT '{}'::jsonb,
  p_idempotency_key text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_bundle money_kernel.cash_bundles;
  v_location money_kernel.cash_locations;
  v_cashbook money_kernel.cashbooks;
  v_balance numeric(18, 4);
  v_new_default bigint;
  v_withdraw jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_profile_id IS NULL OR p_bundle_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id, profile_id, and bundle_id required';
  END IF;

  PERFORM public.assert_kernel_money_access(p_tenant_id, 'withdraw');
  PERFORM public.money_kernel_assert_profile_in_tenant(p_tenant_id, p_profile_id);

  SELECT * INTO v_bundle
  FROM money_kernel.cash_bundles
  WHERE id = p_bundle_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bundle % in tenant %', p_bundle_id, p_tenant_id;
  END IF;

  IF v_bundle.closed_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'bundle_id', p_bundle_id,
      'closed_at', v_bundle.closed_at,
      'idempotent', true
    );
  END IF;

  SELECT * INTO v_location
  FROM money_kernel.cash_locations
  WHERE id = v_bundle.cash_location_id;

  SELECT * INTO v_cashbook
  FROM money_kernel.cashbooks
  WHERE id = v_location.cashbook_id;

  IF v_cashbook.profile_id IS DISTINCT FROM p_profile_id THEN
    RAISE EXCEPTION 'not_found: bundle % for profile %', p_bundle_id, p_profile_id;
  END IF;

  v_balance := coalesce(v_bundle.amount, 0);
  IF v_balance > 0 THEN
    v_withdraw := public.rpc_withdraw(
      p_tenant_id,
      p_profile_id,
      v_balance,
      v_bundle.currency_code,
      p_bundle_id,
      coalesce(p_meta, '{}'::jsonb) || jsonb_build_object('close_cash_bundle', true),
      p_idempotency_key
    );
    SELECT amount INTO v_balance
    FROM money_kernel.cash_bundles
    WHERE id = p_bundle_id;
  END IF;

  IF coalesce(v_balance, 0) > 0 THEN
    RAISE EXCEPTION 'insufficient_balance: bundle % still holds % after withdraw attempt',
      p_bundle_id, v_balance;
  END IF;

  UPDATE money_kernel.cash_bundles
  SET closed_at = now(), updated_at = now()
  WHERE id = p_bundle_id;

  IF v_cashbook.default_cash_bundle_id = p_bundle_id THEN
    SELECT pp.id INTO v_new_default
    FROM money_kernel.cash_bundles pp
    JOIN money_kernel.cash_locations pt ON pt.id = pp.cash_location_id
    WHERE pt.cashbook_id = v_cashbook.id
      AND pp.closed_at IS NULL
    ORDER BY (upper(btrim(pp.currency_code)) = upper(btrim(v_bundle.currency_code))) DESC,
             pp.id ASC
    LIMIT 1;

    UPDATE money_kernel.cashbooks
    SET default_cash_bundle_id = v_new_default, updated_at = now()
    WHERE id = v_cashbook.id;
  END IF;

  PERFORM public._desk_sync_point_currencies_from_kernel(
    p_profile_id,
    v_location.location_code
  );

  RETURN jsonb_build_object(
    'bundle_id', p_bundle_id,
    'closed_at', (SELECT closed_at FROM money_kernel.cash_bundles WHERE id = p_bundle_id),
    'withdraw', v_withdraw,
    'idempotent', false
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public._desk_sync_point_currencies_from_kernel(bigint, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_close_cash_bundle(bigint, bigint, bigint, jsonb, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_list_profile_cashbook_bundles(bigint, bigint) TO authenticated, service_role;

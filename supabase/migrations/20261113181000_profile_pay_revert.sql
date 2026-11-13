-- Profile kernel pay revert
CREATE OR REPLACE FUNCTION money_kernel.fn_pays_guard_immutable()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  IF OLD.status = 'voided' THEN
    RAISE EXCEPTION 'pays % is voided and cannot be updated', OLD.id;
  END IF;

  IF NEW.status = 'voided' THEN
    IF NEW.amount           <> OLD.amount
       OR NEW.from_cash_bundle_id IS DISTINCT FROM OLD.from_cash_bundle_id
       OR NEW.to_cash_bundle_id   IS DISTINCT FROM OLD.to_cash_bundle_id
       OR NEW.currency_code <> OLD.currency_code
       OR NEW.exchange_rate <> OLD.exchange_rate
       OR NEW.books_amount  <> OLD.books_amount
       OR NEW.books_rate    <> OLD.books_rate
       OR NEW.kind          <> OLD.kind
       OR NEW.tenant_id     <> OLD.tenant_id
       OR NEW.payment_date  <> OLD.payment_date
       OR NEW.created_by    IS DISTINCT FROM OLD.created_by
       OR NEW.refs          IS DISTINCT FROM OLD.refs
       OR NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key
       OR NEW.request_hash  IS DISTINCT FROM OLD.request_hash
       OR NOT (NEW.meta @> OLD.meta) THEN
      RAISE EXCEPTION
        'void pays % may only change status, voided_at, meta (add-only), updated_at', OLD.id;
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.status = 'posted' AND OLD.status = 'posted'
     AND current_setting('money.revert_writer', true) = '1' THEN
    IF NEW.amount                <> OLD.amount
       OR NEW.from_cash_bundle_id IS DISTINCT FROM OLD.from_cash_bundle_id
       OR NEW.to_cash_bundle_id   IS DISTINCT FROM OLD.to_cash_bundle_id
       OR NEW.currency_code       <> OLD.currency_code
       OR NEW.exchange_rate       <> OLD.exchange_rate
       OR NEW.books_amount        <> OLD.books_amount
       OR NEW.books_rate          <> OLD.books_rate
       OR NEW.kind                 <> OLD.kind
       OR NEW.tenant_id            <> OLD.tenant_id
       OR NEW.payment_date         <> OLD.payment_date
       OR NEW.created_by           IS DISTINCT FROM OLD.created_by
       OR NEW.refs                 IS DISTINCT FROM OLD.refs
       OR NEW.idempotency_key      IS DISTINCT FROM OLD.idempotency_key
       OR NEW.request_hash         IS DISTINCT FROM OLD.request_hash
       OR NEW.status               IS DISTINCT FROM OLD.status
       OR NEW.voided_at            IS DISTINCT FROM OLD.voided_at
       OR NEW.voided_by            IS DISTINCT FROM OLD.voided_by
       OR NOT (NEW.meta @> OLD.meta) THEN
      RAISE EXCEPTION
        'revert pays % may only add meta (revert_reason, reverted_at, reversal_pays_id)', OLD.id;
    END IF;
    RETURN NEW;
  END IF;

  -- T1 snapshot write after INSERT (posted → posted, pot_writer set)
  IF NEW.status = 'posted' AND OLD.status = 'posted'
     AND current_setting('money.pot_writer', true) = '1'
     AND NEW.amount           = OLD.amount
     AND NEW.from_cash_bundle_id IS NOT DISTINCT FROM OLD.from_cash_bundle_id
     AND NEW.to_cash_bundle_id   IS NOT DISTINCT FROM OLD.to_cash_bundle_id
     AND NEW.currency_code    = OLD.currency_code
     AND NEW.exchange_rate    = OLD.exchange_rate
     AND NEW.books_amount     = OLD.books_amount
     AND NEW.books_rate       = OLD.books_rate
     AND NEW.kind             = OLD.kind
     AND NEW.tenant_id        = OLD.tenant_id
     AND NEW.payment_date     = OLD.payment_date
     AND NEW.created_by       IS NOT DISTINCT FROM OLD.created_by
     AND NEW.refs             IS NOT DISTINCT FROM OLD.refs
     AND NEW.idempotency_key  IS NOT DISTINCT FROM OLD.idempotency_key
     AND NEW.request_hash     IS NOT DISTINCT FROM OLD.request_hash
     AND NEW.meta             = OLD.meta
     AND NEW.status           = OLD.status
     AND NEW.voided_at        IS NOT DISTINCT FROM OLD.voided_at
     AND NEW.voided_by        IS NOT DISTINCT FROM OLD.voided_by
     AND (
       NEW.from_balance_after IS DISTINCT FROM OLD.from_balance_after
       OR NEW.to_balance_after IS DISTINCT FROM OLD.to_balance_after
     ) THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION
    'posted pays % is immutable; use rpc_update_pays (void + recreate) for corrections', OLD.id;
END;
$$;
CREATE OR REPLACE FUNCTION public.rpc_revert_pays(
  p_tenant_id       bigint,
  p_pays_id         bigint,
  p_reason          text,
  p_idempotency_key text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_reason          text;
  v_orig            money_kernel.pays;
  v_rev             money_kernel.pays;
  v_rev_kind        text;
  v_from_bundle     bigint;
  v_to_bundle       bigint;
  v_from_bal        numeric(18,4);
  v_lot_ids         bigint[];
  v_books_rate      numeric(15,6);
BEGIN
  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  IF v_reason IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: reason is required';
  END IF;

  PERFORM public.assert_kernel_money_access(p_tenant_id, 'void');

  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_rev FROM money_kernel.pays
     WHERE tenant_id = p_tenant_id
       AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF FOUND THEN
      IF (v_rev.refs->>'reverses_pays_id')::bigint = p_pays_id THEN
        RETURN jsonb_build_object(
          'original_pays_id', p_pays_id,
          'reversal_pays_id', v_rev.id,
          'kind', v_rev.kind,
          'idempotent', true
        );
      END IF;
      RAISE EXCEPTION 'idempotency_conflict: key % already used by pays %',
        p_idempotency_key, v_rev.id;
    END IF;
  END IF;

  SELECT * INTO v_orig FROM money_kernel.pays
   WHERE id = p_pays_id AND tenant_id = p_tenant_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: pays % in tenant %', p_pays_id, p_tenant_id;
  END IF;

  IF v_orig.status <> 'posted' THEN
    RAISE EXCEPTION 'invalid_state: pays % is not posted', p_pays_id;
  END IF;

  IF v_orig.meta ? 'reverted_at' THEN
    RAISE EXCEPTION 'invalid_state: pays % already reverted', p_pays_id;
  END IF;

  IF v_orig.refs ? 'reverses_pays_id' THEN
    RAISE EXCEPTION 'invalid_arguments: cannot revert a reversal pays %', p_pays_id;
  END IF;

  IF v_orig.kind NOT IN ('deposit', 'withdrawal', 'transfer') THEN
    RAISE EXCEPTION 'invalid_arguments: kind % cannot be reverted here', v_orig.kind;
  END IF;

  IF v_orig.kind = 'deposit' THEN
    v_rev_kind := 'withdrawal';
    v_from_bundle := v_orig.to_cash_bundle_id;
    v_to_bundle := NULL;
    IF v_from_bundle IS NULL THEN
      RAISE EXCEPTION 'invalid_state: deposit % has no to_cash_bundle_id', p_pays_id;
    END IF;
  ELSIF v_orig.kind = 'withdrawal' THEN
    v_rev_kind := 'deposit';
    v_from_bundle := NULL;
    v_to_bundle := v_orig.from_cash_bundle_id;
    IF v_to_bundle IS NULL THEN
      RAISE EXCEPTION 'invalid_state: withdrawal % has no from_cash_bundle_id', p_pays_id;
    END IF;
  ELSE
    v_rev_kind := 'transfer';
    v_from_bundle := v_orig.to_cash_bundle_id;
    v_to_bundle := v_orig.from_cash_bundle_id;
    IF v_from_bundle IS NULL OR v_to_bundle IS NULL OR v_from_bundle = v_to_bundle THEN
      RAISE EXCEPTION 'invalid_state: transfer % missing distinct bundles', p_pays_id;
    END IF;
  END IF;

  v_lot_ids := ARRAY(
    SELECT x FROM unnest(ARRAY[v_from_bundle, v_to_bundle]) AS x WHERE x IS NOT NULL
  );
  IF cardinality(v_lot_ids) > 0 THEN
    PERFORM 1 FROM money_kernel.cash_bundles
     WHERE id = ANY(v_lot_ids) ORDER BY id FOR UPDATE;
  END IF;

  IF v_rev_kind IN ('withdrawal', 'transfer') AND v_from_bundle IS NOT NULL THEN
    SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = v_from_bundle;
    IF v_from_bal < v_orig.amount THEN
      RAISE EXCEPTION
        'insufficient_balance: bundle % has % but reversal needs %',
        v_from_bundle, v_from_bal, v_orig.amount;
    END IF;
  END IF;

  IF v_rev_kind = 'transfer' AND v_from_bundle IS NOT NULL THEN
    SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = v_from_bundle;
    IF v_from_bal < v_orig.amount THEN
      RAISE EXCEPTION
        'insufficient_balance: cannot revert transfer %; bundle % has % needs %',
        p_pays_id, v_from_bundle, v_from_bal, v_orig.amount;
    END IF;
  END IF;

  v_books_rate := v_orig.books_rate;

  INSERT INTO money_kernel.pays (
    tenant_id, kind,
    from_profile_id, to_profile_id,
    from_cash_bundle_id, to_cash_bundle_id,
    amount, currency_code, books_amount, books_rate, exchange_rate,
    payment_date, status, idempotency_key, refs, meta, created_by
  ) VALUES (
    p_tenant_id, v_rev_kind,
    v_orig.to_profile_id, v_orig.from_profile_id,
    v_from_bundle, v_to_bundle,
    v_orig.amount, v_orig.currency_code, v_orig.books_amount, v_books_rate,
    v_orig.exchange_rate,
    CURRENT_DATE, 'posted', p_idempotency_key,
    jsonb_build_object('reverses_pays_id', v_orig.id),
    jsonb_build_object('reversal', true, 'revert_reason', v_reason),
    auth.uid()
  ) RETURNING * INTO v_rev;

  PERFORM money_kernel.fn_ensure_header_pay_bundle_lines(p_tenant_id, v_rev.id);

  PERFORM set_config('money.revert_writer', '1', true);
  UPDATE money_kernel.pays
     SET meta = COALESCE(meta, '{}'::jsonb) || jsonb_build_object(
           'revert_reason', v_reason,
           'reverted_at', to_jsonb(now()),
           'reversal_pays_id', v_rev.id
         ),
         updated_at = now()
   WHERE id = v_orig.id;

  RETURN jsonb_build_object(
    'original_pays_id', v_orig.id,
    'reversal_pays_id', v_rev.id,
    'reversal_kind', v_rev.kind,
    'idempotent', false
  );
END;
$$;
CREATE OR REPLACE FUNCTION public._kernel_bundle_owner_profile_id(p_bundle_id bigint)
RETURNS bigint
LANGUAGE sql
STABLE
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT a.profile_id
    FROM money_kernel.cash_bundles cb
    JOIN money_kernel.cash_locations cl ON cl.id = cb.cash_location_id
    JOIN money_kernel.cashbooks a ON a.id = cl.cashbook_id
   WHERE cb.id = p_bundle_id
   LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public._kernel_profile_pay_row_json(
  py money_kernel.pays,
  p_viewed_profile_id bigint
) RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path = money_kernel, public, pg_temp
AS $$
  WITH prof AS (
    SELECT
      coalesce(
        py.from_profile_id,
        public._kernel_bundle_owner_profile_id(py.from_cash_bundle_id)
      ) AS from_pid,
      coalesce(
        py.to_profile_id,
        public._kernel_bundle_owner_profile_id(py.to_cash_bundle_id)
      ) AS to_pid
  )
  SELECT jsonb_build_object(
    'id', py.id,
    'spine', 'kernel',
    'kernel_kind', py.kind,
    'payment_date', py.payment_date,
    'amount', py.amount,
    'unallocated_amount', 0,
    'source', 'kernel_' || py.kind,
    'direction', CASE
      WHEN py.kind = 'deposit' THEN 'in'
      WHEN py.kind = 'withdrawal' THEN 'out'
      WHEN p_viewed_profile_id IS NOT NULL AND prof.from_pid = p_viewed_profile_id THEN 'out'
      ELSE 'in'
    END,
    'method', null,
    'reference', null,
    'note', coalesce(py.meta->>'note', py.meta->>'revert_reason'),
    'voided_at', null,
    'from_profile_id', prof.from_pid,
    'to_profile_id', prof.to_pid,
    'from_profile_name', (SELECT pr.name FROM public.profiles pr WHERE pr.id = prof.from_pid),
    'to_profile_name', (SELECT pr.name FROM public.profiles pr WHERE pr.id = prof.to_pid),
    'description', CASE py.kind
      WHEN 'deposit' THEN 'Deposit'
      WHEN 'withdrawal' THEN 'Withdrawal'
      WHEN 'transfer' THEN 'Transfer'
      ELSE py.kind
    END,
    'profile_id', p_viewed_profile_id,
    'profile_name', (SELECT pr.name FROM public.profiles pr WHERE pr.id = p_viewed_profile_id),
    'settlement_currency_code', coalesce(py.currency_code, 'BDT'),
    'foreign_amount', null,
    'exchange_rate', coalesce(py.exchange_rate, 1),
    'reverted_at', py.meta->>'reverted_at',
    'revert_reason', py.meta->>'revert_reason',
    'is_reversal', (py.refs ? 'reverses_pays_id'),
    'reverses_pays_id', nullif(py.refs->>'reverses_pays_id', '')::bigint,
    'perspective', 'party'
  )
  FROM prof;
$$;
CREATE OR REPLACE FUNCTION public.list_profile_activity_for_staff(
  p_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_kind text DEFAULT 'payments',
  p_limit integer DEFAULT 50,
  p_cursor text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_ledger_entity_id bigint;
  v_lim integer;
  v_items jsonb := '[]'::jsonb;
  v_next_cursor text;
  v_cursor_pay_id bigint;
  v_cursor_bill_id bigint;
  v_cursor_created timestamptz;
  v_cursor_entry_id uuid;
  v_money_profile_id bigint;
BEGIN
  IF p_kind NOT IN ('payments', 'custody', 'bills') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid kind');
  END IF;

  IF p_entity_type NOT IN ('tenant', 'customer', 'vendor', 'courier', 'cargo_company', 'investor') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid entity_type');
  END IF;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);
  v_money_profile_id := public._kernel_cashbook_money_profile_id(v_books_id, p_entity_type, p_entity_id);

  IF NOT (
    public.cashbook_staff_can_view(p_tenant_id)
    OR public.membership_has_module_action(v_books_id, 'payments', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'view')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  v_lim := greatest(least(coalesce(p_limit, 50), 200), 1);
  v_ledger_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_ledger_entity_id := v_books_id;
  END IF;

  IF p_kind = 'payments' THEN
    v_cursor_pay_id := NULLIF(btrim(coalesce(p_cursor, '')), '')::bigint;

    IF v_money_profile_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM money_kernel.cashbooks a
      WHERE a.tenant_id = v_books_id AND a.profile_id = v_money_profile_id
    ) THEN
      SELECT coalesce(jsonb_agg(row_data ORDER BY sort_payment_date DESC, sort_id DESC), '[]'::jsonb)
      INTO v_items
      FROM (
        SELECT
          public._kernel_profile_pay_row_json(py, v_money_profile_id) AS row_data,
          py.payment_date AS sort_payment_date,
          py.id AS sort_id
        FROM money_kernel.pays py
        WHERE py.tenant_id = v_books_id
          AND py.kind IN ('deposit', 'withdrawal', 'transfer')
          AND py.status = 'posted'
          AND (
            py.from_cash_bundle_id IN (
              SELECT cb.id
                FROM money_kernel.cash_bundles cb
                JOIN money_kernel.cash_locations cl ON cl.id = cb.cash_location_id
                JOIN money_kernel.cashbooks a ON a.id = cl.cashbook_id
               WHERE a.tenant_id = v_books_id
                 AND a.profile_id = v_money_profile_id
            )
            OR py.to_cash_bundle_id IN (
              SELECT cb.id
                FROM money_kernel.cash_bundles cb
                JOIN money_kernel.cash_locations cl ON cl.id = cb.cash_location_id
                JOIN money_kernel.cashbooks a ON a.id = cl.cashbook_id
               WHERE a.tenant_id = v_books_id
                 AND a.profile_id = v_money_profile_id
            )
          )
          AND (v_cursor_pay_id IS NULL OR py.id < v_cursor_pay_id)
        ORDER BY py.payment_date DESC, py.id DESC
        LIMIT v_lim + 1
      ) pay_rows;

    ELSIF p_entity_type = 'tenant' THEN
      SELECT coalesce(jsonb_agg(row_data ORDER BY sort_payment_date DESC, sort_id DESC), '[]'::jsonb)
      INTO v_items
      FROM (
        SELECT
          public._kernel_pay_row_json(
            py,
            public._kernel_pay_direction_tenant(py.source),
            coalesce((SELECT pr.name FROM public.profiles pr WHERE pr.id = py.profile_id), ''),
            'tenant'
          ) AS row_data,
          py.payment_date AS sort_payment_date,
          py.id AS sort_id
        FROM public.pays py
        WHERE py.tenant_id = v_books_id
          AND py.voided_at IS NULL
          AND (v_cursor_pay_id IS NULL OR py.id < v_cursor_pay_id)
        ORDER BY py.payment_date DESC, py.id DESC
        LIMIT v_lim + 1
      ) pay_rows;

    ELSE
      SELECT coalesce(jsonb_agg(row_data ORDER BY sort_payment_date DESC, sort_id DESC), '[]'::jsonb)
      INTO v_items
      FROM (
        SELECT
          public._kernel_pay_row_json(
            py,
            public._kernel_pay_direction_party(py.source, p_entity_type),
            NULL,
            'party'
          ) AS row_data,
          py.payment_date AS sort_payment_date,
          py.id AS sort_id
        FROM public.pays py
        WHERE py.tenant_id = v_books_id
          AND (
            py.from_profile_id = coalesce(v_money_profile_id, p_entity_id)
            OR py.to_profile_id = coalesce(v_money_profile_id, p_entity_id)
            OR (
              py.from_profile_id IS NULL
              AND py.to_profile_id IS NULL
              AND py.profile_id = coalesce(v_money_profile_id, p_entity_id)
            )
          )
          AND py.voided_at IS NULL
          AND (v_cursor_pay_id IS NULL OR py.id < v_cursor_pay_id)
        ORDER BY py.payment_date DESC, py.id DESC
        LIMIT v_lim + 1
      ) pay_rows;
    END IF;

    IF jsonb_array_length(v_items) > v_lim THEN
      v_next_cursor := (v_items->(v_lim - 1)->>'id');
      v_items := (
        SELECT coalesce(jsonb_agg(elem), '[]'::jsonb)
        FROM jsonb_array_elements(v_items) WITH ORDINALITY AS t(elem, ord)
        WHERE ord <= v_lim
      );
    END IF;

  ELSIF p_kind = 'custody' THEN
    IF coalesce(btrim(p_cursor), '') <> '' THEN
      v_cursor_entry_id := p_cursor::uuid;
    END IF;

    SELECT coalesce(jsonb_agg(row_data ORDER BY sort_created DESC, sort_id DESC), '[]'::jsonb)
    INTO v_items
    FROM (
      SELECT
        jsonb_build_object(
          'id', l.id::text,
          'type', l.type,
          'amount', l.amount,
          'balance_after', l.balance_after,
          'source_type', l.source_type,
          'source_id', l.source_id,
          'created_at', l.created_at,
          'is_reversal', (l.metadata ? 'reversal_of'),
          'metadata', coalesce(l.metadata, '{}'::jsonb),
          'cashbook_point_id', l.cashbook_point_id,
          'cashbook_point_name', cp.name
        ) AS row_data,
        l.created_at AS sort_created,
        l.id AS sort_id
      FROM public.cashbook_entries l
      LEFT JOIN public.cashbook_points cp ON cp.id = l.cashbook_point_id
      WHERE l.tenant_id = v_books_id
        AND l.entity_type = p_entity_type
        AND l.entity_id = v_ledger_entity_id
        AND (v_cursor_entry_id IS NULL OR l.created_at < (
          SELECT l2.created_at FROM public.cashbook_entries l2 WHERE l2.id = v_cursor_entry_id
        ))
      ORDER BY l.created_at DESC, l.id DESC
      LIMIT v_lim + 1
    ) ledger_rows;

    IF jsonb_array_length(v_items) > v_lim THEN
      v_next_cursor := (v_items->(v_lim - 1)->>'id');
      v_items := (
        SELECT coalesce(jsonb_agg(elem), '[]'::jsonb)
        FROM jsonb_array_elements(v_items) WITH ORDINALITY AS t(elem, ord)
        WHERE ord <= v_lim
      );
    END IF;

  ELSIF p_kind = 'bills' THEN
    v_cursor_bill_id := NULLIF(btrim(coalesce(p_cursor, '')), '')::bigint;

    SELECT coalesce(jsonb_agg(row_data ORDER BY sort_id DESC), '[]'::jsonb)
    INTO v_items
    FROM (
      SELECT
        jsonb_build_object(
          'bill_id', s.bill_id,
          'invoice_no', s.invoice_no,
          'total_amount', s.total_amount,
          'open_books', s.open_books,
          'due_date', s.due_date,
          'invoice_type', s.invoice_type,
          'document_kind', s.document_kind,
          'lifecycle_status', s.lifecycle_status,
          'payment_status', s.payment_status,
          'profile_id', s.profile_id,
          'from_profile_id', s.from_profile_id,
          'to_profile_id', s.to_profile_id
        ) AS row_data,
        s.bill_id AS sort_id
      FROM public.v_kernel_bill_summaries s
      WHERE s.tenant_id = v_books_id
        AND s.lifecycle_status = 'issued'::public.bill_lifecycle_status
        AND (
          (p_entity_type = 'tenant' AND s.tenant_id = v_books_id)
          OR (
            p_entity_type <> 'tenant'
            AND (
              s.profile_id = coalesce(v_money_profile_id, p_entity_id)
              OR s.from_profile_id = coalesce(v_money_profile_id, p_entity_id)
              OR s.to_profile_id = coalesce(v_money_profile_id, p_entity_id)
            )
          )
        )
        AND (v_cursor_bill_id IS NULL OR s.bill_id < v_cursor_bill_id)
      ORDER BY s.bill_id DESC
      LIMIT v_lim + 1
    ) bill_rows;

    IF jsonb_array_length(v_items) > v_lim THEN
      v_next_cursor := (v_items->(v_lim - 1)->>'bill_id');
      v_items := (
        SELECT coalesce(jsonb_agg(elem), '[]'::jsonb)
        FROM jsonb_array_elements(v_items) WITH ORDINALITY AS t(elem, ord)
        WHERE ord <= v_lim
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'kind', p_kind,
    'items', v_items,
    'next_cursor', v_next_cursor
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public._kernel_bundle_owner_profile_id(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._kernel_profile_pay_row_json(money_kernel.pays, bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_revert_pays(bigint, bigint, text, text) TO authenticated, service_role;

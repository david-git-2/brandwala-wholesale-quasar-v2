-- Global public.profiles + money_kernel cashbook (follow-up to 20261112210000)


DROP FUNCTION IF EXISTS public._desk_resolve_public_profile_id_for_cashbook(bigint, bigint);


DROP FUNCTION IF EXISTS public._desk_profile_json_kernel(bigint, bigint);


CREATE OR REPLACE FUNCTION public.fn_provision_kernel_cashbook_currency(
  p_books_tenant_id bigint,
  p_profile_id    bigint,
  p_currency_code text,
  p_point_code    text DEFAULT 'main'
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_ccy text;
  v_account_id bigint;
  v_point_id   bigint;
  v_pot_id     bigint;
BEGIN
  IF p_books_tenant_id IS NULL OR p_profile_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_ccy := upper(trim(coalesce(p_currency_code, 'BDT')));
  IF v_ccy = '' THEN
    v_ccy := 'BDT';
  END IF;

  v_account_id := public.fn_provision_kernel_cashbook_for_profile_row(p_books_tenant_id, p_profile_id);
  IF v_account_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT cp.id INTO v_point_id
  FROM money_kernel.cashbook_points cp
  WHERE cp.cashbook_account_id = v_account_id
    AND cp.code = p_point_code
  LIMIT 1;

  IF v_point_id IS NULL THEN
    INSERT INTO money_kernel.cashbook_points
      (tenant_id, cashbook_account_id, code, name)
    VALUES
      (p_books_tenant_id, v_account_id, p_point_code, initcap(p_point_code))
    RETURNING id INTO v_point_id;
  END IF;

  INSERT INTO money_kernel.cashbook_point_pots
    (tenant_id, cashbook_point_id, currency_code)
  VALUES
    (p_books_tenant_id, v_point_id, v_ccy)
  ON CONFLICT (cashbook_point_id, currency_code) DO NOTHING
  RETURNING id INTO v_pot_id;

  IF v_pot_id IS NULL THEN
    SELECT pp.id INTO v_pot_id
    FROM money_kernel.cashbook_point_pots pp
    WHERE pp.cashbook_point_id = v_point_id
      AND pp.currency_code = v_ccy
    LIMIT 1;
  END IF;

  RETURN v_pot_id;
END;
$$;


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

  SELECT ca.id, ca.default_cashbook_point_pot_id
  INTO v_account_id, v_default_pot
  FROM money_kernel.cashbook_accounts ca
  WHERE ca.tenant_id = p_books_tenant_id
    AND ca.entity_type = 'profile'
    AND ca.entity_id = p_bill_profile_id
  LIMIT 1;

  IF v_account_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT pp.id INTO v_ccy_pot
  FROM money_kernel.cashbook_point_pots pp
  JOIN money_kernel.cashbook_points pt ON pt.id = pp.cashbook_point_id
  WHERE pt.cashbook_account_id = v_account_id
    AND upper(trim(pp.currency_code)) = v_ccy
  ORDER BY pt.code, pp.id
  LIMIT 1;

  v_default_pot := coalesce(v_ccy_pot, v_default_pot);

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', cp.id,
      'code', cp.code,
      'name', cp.name,
      'is_active', true
    )
    ORDER BY cp.name, cp.id
  ), '[]'::jsonb)
  INTO v_points
  FROM money_kernel.cashbook_points cp
  WHERE cp.cashbook_account_id = v_account_id;

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
  FROM money_kernel.cashbook_point_pots pp
  JOIN money_kernel.cashbook_points pt ON pt.id = pp.cashbook_point_id
  WHERE pt.cashbook_account_id = v_account_id;

  RETURN jsonb_build_object(
    'profile_id', p_bill_profile_id,
    'cashbook_account_id', v_account_id,
    'default_pot_id', v_default_pot,
    'points', v_points,
    'pots', v_pots
  );
END;
$$;


CREATE OR REPLACE FUNCTION public._get_bill_detail_bundle_from_kernel(
  p_tenant_id bigint,
  p_bill_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent_id bigint;
  v_b money_kernel.bills;
  v_invoice_type text;
  v_invoice_status text;
  v_payment_status text;
  v_bill_json jsonb;
  v_bill_lines jsonb := '[]'::jsonb;
  v_adjustments jsonb := '[]'::jsonb;
  v_ap_kind text;
BEGIN
  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  IF NOT (
    public.user_can_manage_books_tenant(v_parent_id)
    OR public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  SELECT * INTO v_b
  FROM money_kernel.bills
  WHERE id = p_bill_id AND tenant_id = v_parent_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;

  v_invoice_type := public._desk_kernel_kind_invoice_type(v_b.kind);
  v_invoice_status := CASE v_b.status
    WHEN 'draft' THEN 'draft'
    WHEN 'voided' THEN 'voided'
    WHEN 'proforma_generated' THEN 'draft'
    ELSE 'issued'
  END;
  v_payment_status := public._desk_kernel_status_payment(v_b.status, v_b.due_amount);
  v_ap_kind := COALESCE(v_b.meta->>'ap_kind', NULL);

  v_bill_json := jsonb_build_object(
    'id', v_b.id,
    'tenant_id', v_b.tenant_id,
    'invoice_no', v_b.invoice_no,
    'invoice_date', v_b.invoice_date,
    'due_date', v_b.due_date,
    'invoice_type', v_invoice_type,
    'invoice_status', v_invoice_status,
    'payment_status', v_payment_status,
    'document_kind', CASE v_b.kind WHEN 'credit_note' THEN 'credit_note' WHEN 'debit_note' THEN 'debit_note' ELSE 'standard' END,
    'total_amount', v_b.total_amount,
    'due_amount', v_b.due_amount,
    'paid_amount', v_b.paid_amount,
    'currency_code', v_b.currency_code,
    'from_profile_id', v_b.from_profile_id,
    'to_profile_id', v_b.to_profile_id,
    'profile_id', v_b.counterparty_profile_id,
    'source_type', v_b.source_type,
    'source_id', v_b.source_id,
    'source_key', v_b.source_key,
    'parent_bill_id', v_b.parent_bill_id,
    'ap_kind', v_ap_kind,
    'channel_meta', jsonb_build_object('ap_kind', v_ap_kind, 'money_kernel_v2', true),
    'note', v_b.note,
    'spine', 'kernel',
    'kernel_kind', v_b.kind
  )
  || jsonb_build_object(
    'profiles', public._desk_profile_json_public(v_b.counterparty_profile_id),
    'from_profile', public._desk_profile_json_public(v_b.from_profile_id),
    'to_profile', public._desk_profile_json_public(v_b.to_profile_id)
  );

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', bl.id,
      'name_snapshot', COALESCE(bl.description, 'Line'),
      'currency_code', upper(v_b.currency_code),
      'line_total_amount', bl.line_total,
      'books_amount', bl.line_total,
      'quantity', bl.quantity
    )
    ORDER BY bl.line_no
  ), '[]'::jsonb)
  INTO v_bill_lines
  FROM money_kernel.bill_lines bl
  WHERE bl.bill_id = p_bill_id AND bl.tenant_id = v_parent_id;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'invoice_no', c.invoice_no,
      'document_kind', c.kind,
      'invoice_status', c.status,
      'total_amount', c.total_amount
    )
    ORDER BY c.id
  ), '[]'::jsonb)
  INTO v_adjustments
  FROM money_kernel.bills c
  WHERE c.parent_bill_id = p_bill_id
    AND c.tenant_id = v_parent_id
    AND c.kind IN ('credit_note', 'debit_note')
    AND c.status <> 'voided';

  RETURN jsonb_build_object(
    'bill', v_bill_json,
    'payment_history', public._desk_kernel_payment_history_json(v_parent_id, p_bill_id),
    'net_balances', public._desk_kernel_net_balances_json(p_bill_id),
    'adjustments', v_adjustments,
    'stock_items', '[]'::jsonb,
    'bill_lines', v_bill_lines,
    'pay_cashbook_legs', public._desk_bill_pay_cashbook_legs_json(
      p_tenant_id,
      v_invoice_type,
      v_b.from_profile_id,
      v_b.to_profile_id,
      v_b.currency_code
    )
  );
END;
$$;


CREATE OR REPLACE FUNCTION public._resolve_shipment_cost_ap_kernel_parties(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
  v_parent bigint;
  v_from_profile bigint;
  v_buckets text[] := ARRAY[
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ];
  v_bucket text;
  v_bucket_enum public.global_shipment_cost_bucket;
  v_to_profile bigint;
  v_diag text;
  v_payees jsonb := '{}'::jsonb;
BEGIN
  SELECT * INTO v_ship FROM public.global_shipments WHERE id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  v_parent := v_ship.tenant_id;

  BEGIN
    v_from_profile := public._shipment_cost_ap_ensure_public_from_profile(v_parent);
    IF v_from_profile IS NOT NULL THEN
      PERFORM money_kernel.ensure_profile_for_public_party(v_parent, v_from_profile);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_from_profile := NULL;
  END;

  FOREACH v_bucket IN ARRAY v_buckets
  LOOP
    v_bucket_enum := v_bucket::public.global_shipment_cost_bucket;
    SELECT tp.profile_id, tp.diagnostic
      INTO v_to_profile, v_diag
      FROM public._shipment_cost_ap_ensure_public_to_profile(v_parent, v_ship, v_bucket_enum) tp;

    IF v_to_profile IS NOT NULL THEN
      BEGIN
        PERFORM money_kernel.ensure_profile_for_public_party(v_parent, v_to_profile);
      EXCEPTION WHEN OTHERS THEN
        v_diag := COALESCE(v_diag, SQLERRM);
        v_to_profile := NULL;
      END;
    END IF;

    v_payees := v_payees || jsonb_build_object(
      v_bucket,
      jsonb_build_object(
        'profile_id', v_to_profile,
        'ready', (v_to_profile IS NOT NULL AND v_from_profile IS NOT NULL),
        'diagnostic', v_diag
      )
    );
  END LOOP;

  RETURN jsonb_build_object(
    'books_tenant_id', v_parent,
    'from_profile_id', v_from_profile,
    'payees_by_bucket', v_payees
  );
END;
$$;


CREATE OR REPLACE FUNCTION public.rpc_deposit(
  p_tenant_id       bigint,
  p_profile_id      bigint,
  p_amount          numeric,
  p_currency_code   text    DEFAULT 'BDT',
  p_pot_id          bigint  DEFAULT NULL,
  p_meta            jsonb   DEFAULT '{}'::jsonb,
  p_idempotency_key text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
v_pays money_kernel.pays;
  v_pot_id  bigint;
  v_balance numeric(18,4);
  v_books   numeric(18,4);
BEGIN

  v_books_rate := money_kernel.fn_resolve_books_rate(p_tenant_id, COALESCE(p_currency_code, 'BDT'));
  v_exchange_rate := 1;
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'deposit');

  -- Validation
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount: must be > 0';
  END IF;
  IF v_books_rate IS NULL OR v_books_rate <= 0 THEN
    RAISE EXCEPTION 'invalid_rate: books_rate must be > 0';
  END IF;

  PERFORM public.money_kernel_assert_profile_in_tenant(p_tenant_id, p_profile_id);

  -- Idempotency (posted only)
  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_pays FROM money_kernel.pays
      WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
        AND status = 'posted';
    IF FOUND THEN
      IF v_pays.kind <> 'deposit' OR v_pays.amount <> p_amount
         OR v_pays.currency_code <> p_currency_code THEN
        RAISE EXCEPTION
          'idempotency_conflict: key % used for different parameters', p_idempotency_key;
      END IF;
      SELECT amount INTO v_balance FROM money_kernel.cashbook_point_pots WHERE id = v_pays.to_pot_id;
      RETURN jsonb_build_object(
        'pays_id', v_pays.id, 'kind', 'deposit', 'pot_id', v_pays.to_pot_id,
        'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
        'books_amount', v_pays.books_amount, 'balance_after', v_balance,
        'payment_date', v_pays.payment_date, 'status', v_pays.status,
        'idempotent', true
      );
    END IF;
  END IF;

  -- Resolve destination pot
  IF p_pot_id IS NOT NULL THEN
    SELECT pp.id INTO v_pot_id
      FROM money_kernel.cashbook_point_pots pp
      JOIN money_kernel.cashbook_points    pt ON pt.id = pp.cashbook_point_id
      JOIN money_kernel.cashbook_accounts  a  ON a.id  = pt.cashbook_account_id
     WHERE pp.id = p_pot_id AND pp.currency_code = p_currency_code
       AND a.tenant_id = p_tenant_id AND a.entity_type = 'profile'
       AND a.entity_id = p_profile_id;
    IF v_pot_id IS NULL THEN
      RAISE EXCEPTION
        'not_found: pot % valid for profile % in %', p_pot_id, p_profile_id, p_currency_code;
    END IF;
  ELSE
    SELECT pp.id INTO v_pot_id
      FROM money_kernel.cashbook_accounts a
      JOIN money_kernel.cashbook_points    pt ON pt.cashbook_account_id = a.id
      JOIN money_kernel.cashbook_point_pots pp ON pp.cashbook_point_id = pt.id
     WHERE a.tenant_id = p_tenant_id AND a.entity_type = 'profile'
       AND a.entity_id = p_profile_id AND pp.currency_code = p_currency_code
     ORDER BY (a.default_cashbook_point_pot_id = pp.id) DESC, pp.id ASC
     LIMIT 1;
    IF v_pot_id IS NULL THEN
      RAISE EXCEPTION
        'not_found: no % pot for profile %; call rpc_provision_cashbook_currency',
        p_currency_code, p_profile_id;
    END IF;
  END IF;

  PERFORM 1 FROM money_kernel.cashbook_point_pots WHERE id = v_pot_id FOR UPDATE;
  v_books := round(p_amount * v_books_rate, 4);

  BEGIN
    INSERT INTO money_kernel.pays (
      tenant_id, kind, from_pot_id, to_pot_id,
      amount, currency_code, books_amount, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'deposit', NULL, v_pot_id,
      p_amount, p_currency_code, v_books, 1,
      CURRENT_DATE, 'posted', p_idempotency_key, '{}'::jsonb, p_meta, auth.uid()
    ) RETURNING * INTO v_pays;
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_pays FROM money_kernel.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF NOT FOUND THEN RAISE; END IF;
    IF v_pays.kind <> 'deposit' OR v_pays.amount <> p_amount
       OR v_pays.currency_code <> p_currency_code THEN
      RAISE EXCEPTION
        'idempotency_conflict: key % used for different parameters', p_idempotency_key;
    END IF;
    SELECT amount INTO v_balance FROM money_kernel.cashbook_point_pots WHERE id = v_pays.to_pot_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'kind', 'deposit', 'pot_id', v_pays.to_pot_id,
      'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
      'books_amount', v_pays.books_amount, 'balance_after', v_balance,
      'payment_date', v_pays.payment_date, 'status', v_pays.status,
      'idempotent', true
    );
  END;

  SELECT amount INTO v_balance FROM money_kernel.cashbook_point_pots WHERE id = v_pot_id;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'kind', 'deposit', 'pot_id', v_pot_id,
    'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
    'books_amount', v_pays.books_amount, 'balance_after', v_balance,
    'payment_date', v_pays.payment_date, 'status', v_pays.status,
    'idempotent', false
  );
END;
$$;


CREATE OR REPLACE FUNCTION public.rpc_withdraw(
  p_tenant_id       bigint,
  p_profile_id      bigint,
  p_amount          numeric,
  p_currency_code   text    DEFAULT 'BDT',
  p_pot_id          bigint  DEFAULT NULL,
  p_meta            jsonb   DEFAULT '{}'::jsonb,
  p_idempotency_key text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
v_pays money_kernel.pays;
  v_pot_id  bigint;
  v_balance numeric(18,4);
  v_books   numeric(18,4);
BEGIN

  v_books_rate := money_kernel.fn_resolve_books_rate(p_tenant_id, COALESCE(p_currency_code, 'BDT'));
  v_exchange_rate := 1;
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'withdraw');

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount: must be > 0';
  END IF;
  IF v_books_rate IS NULL OR v_books_rate <= 0 THEN
    RAISE EXCEPTION 'invalid_rate: books_rate must be > 0';
  END IF;

  PERFORM public.money_kernel_assert_profile_in_tenant(p_tenant_id, p_profile_id);

  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_pays FROM money_kernel.pays
      WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF FOUND THEN
      IF v_pays.kind <> 'withdrawal' OR v_pays.amount <> p_amount
         OR v_pays.currency_code <> p_currency_code THEN
        RAISE EXCEPTION
          'idempotency_conflict: key % used for different parameters', p_idempotency_key;
      END IF;
      SELECT amount INTO v_balance FROM money_kernel.cashbook_point_pots WHERE id = v_pays.from_pot_id;
      RETURN jsonb_build_object(
        'pays_id', v_pays.id, 'kind', 'withdrawal', 'pot_id', v_pays.from_pot_id,
        'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
        'books_amount', v_pays.books_amount, 'balance_after', v_balance,
        'payment_date', v_pays.payment_date, 'status', v_pays.status,
        'idempotent', true
      );
    END IF;
  END IF;

  IF p_pot_id IS NOT NULL THEN
    SELECT pp.id INTO v_pot_id
      FROM money_kernel.cashbook_point_pots pp
      JOIN money_kernel.cashbook_points    pt ON pt.id = pp.cashbook_point_id
      JOIN money_kernel.cashbook_accounts  a  ON a.id  = pt.cashbook_account_id
     WHERE pp.id = p_pot_id AND pp.currency_code = p_currency_code
       AND a.tenant_id = p_tenant_id AND a.entity_type = 'profile'
       AND a.entity_id = p_profile_id;
    IF v_pot_id IS NULL THEN
      RAISE EXCEPTION
        'not_found: pot % valid for profile % in %', p_pot_id, p_profile_id, p_currency_code;
    END IF;
  ELSE
    SELECT pp.id INTO v_pot_id
      FROM money_kernel.cashbook_accounts a
      JOIN money_kernel.cashbook_points    pt ON pt.cashbook_account_id = a.id
      JOIN money_kernel.cashbook_point_pots pp ON pp.cashbook_point_id = pt.id
     WHERE a.tenant_id = p_tenant_id AND a.entity_type = 'profile'
       AND a.entity_id = p_profile_id AND pp.currency_code = p_currency_code
     ORDER BY (a.default_cashbook_point_pot_id = pp.id) DESC, pp.id ASC
     LIMIT 1;
    IF v_pot_id IS NULL THEN
      RAISE EXCEPTION 'not_found: no % pot for profile %', p_currency_code, p_profile_id;
    END IF;
  END IF;

  -- Lock + balance check (only withdraw needs this)
  SELECT amount INTO v_balance
    FROM money_kernel.cashbook_point_pots WHERE id = v_pot_id FOR UPDATE;
  IF v_balance < p_amount THEN
    RAISE EXCEPTION
      'insufficient_balance: pot % has %, withdrawal is %', v_pot_id, v_balance, p_amount;
  END IF;

  v_books := round(p_amount * v_books_rate, 4);

  BEGIN
    INSERT INTO money_kernel.pays (
      tenant_id, kind, from_pot_id, to_pot_id,
      amount, currency_code, books_amount, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'withdrawal', v_pot_id, NULL,
      p_amount, p_currency_code, v_books, 1,
      CURRENT_DATE, 'posted', p_idempotency_key, '{}'::jsonb, p_meta, auth.uid()
    ) RETURNING * INTO v_pays;
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_pays FROM money_kernel.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF NOT FOUND THEN RAISE; END IF;
    IF v_pays.kind <> 'withdrawal' OR v_pays.amount <> p_amount
       OR v_pays.currency_code <> p_currency_code THEN
      RAISE EXCEPTION
        'idempotency_conflict: key % used for different parameters', p_idempotency_key;
    END IF;
    SELECT amount INTO v_balance FROM money_kernel.cashbook_point_pots WHERE id = v_pays.from_pot_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'kind', 'withdrawal', 'pot_id', v_pays.from_pot_id,
      'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
      'books_amount', v_pays.books_amount, 'balance_after', v_balance,
      'payment_date', v_pays.payment_date, 'status', v_pays.status,
      'idempotent', true
    );
  END;

  SELECT amount INTO v_balance FROM money_kernel.cashbook_point_pots WHERE id = v_pot_id;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'kind', 'withdrawal', 'pot_id', v_pot_id,
    'amount', v_pays.amount, 'currency_code', v_pays.currency_code,
    'books_amount', v_pays.books_amount, 'balance_after', v_balance,
    'payment_date', v_pays.payment_date, 'status', v_pays.status,
    'idempotent', false
  );
END;
$$;


CREATE OR REPLACE FUNCTION public.rpc_pay_bills(
  p_tenant_id        bigint,
  p_payer_profile_id bigint,
  p_from_pot_id      bigint,
  p_amount           numeric,
  p_allocations      jsonb,
  p_to_pot_id        bigint DEFAULT NULL,
  p_meta             jsonb DEFAULT '{}'::jsonb,
  p_idempotency_key  text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
v_pays money_kernel.pays;
  v_from_pot money_kernel.cashbook_point_pots;
  v_to_pot money_kernel.cashbook_point_pots;
  v_to_pot_id  bigint;
  v_books      numeric(18,4);
  v_bill_ids   bigint[];
  v_bill_id    bigint;
  v_alloc_amt  numeric(18,4);
  v_alloc      jsonb;
  v_bill money_kernel.bills;
  v_settlements jsonb := '[]'::jsonb;
  v_settlement money_kernel.bill_settlements;
  v_sum_alloc  numeric(18,4);
  v_settle_books numeric(18,4);
  v_books_left numeric(18,4);
  v_line_books numeric(18,4);
  v_alloc_n    int;
  v_alloc_i    int;
  v_err        text;
BEGIN

  v_books_rate := money_kernel.fn_resolve_books_rate(p_tenant_id, 'BDT');
  v_exchange_rate := 1;
  PERFORM public.assert_kernel_money_access(p_tenant_id);

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount: must be > 0';
  END IF;
  IF p_allocations IS NULL OR jsonb_typeof(p_allocations) <> 'array'
     OR jsonb_array_length(p_allocations) = 0 THEN
    RAISE EXCEPTION 'invalid_arguments: p_allocations must be a non-empty array';
  END IF;
  IF (
    SELECT count(*) <> count(DISTINCT (a->>'bill_id')::bigint)
      FROM jsonb_array_elements(p_allocations) a
  ) THEN
    RAISE EXCEPTION 'invalid_arguments: duplicate bill_id in p_allocations';
  END IF;

  -- [SHIP] Derive to_pot from bill.to_profile_id + currency (Option C / I30–I32).
  -- If p_to_pot_id passed, must equal derived pot for every bill in p_allocations.
  -- Reject mixed payees; reject from_pot = to_pot.
  -- Body below still shows legacy tenant-default path until rewritten.
  IF p_to_pot_id IS NOT NULL THEN
    v_to_pot_id := p_to_pot_id;
  ELSE
    SELECT default_cashbook_point_pot_id INTO v_to_pot_id
      FROM money_kernel.cashbook_accounts
     WHERE tenant_id = p_tenant_id AND entity_type = 'tenant'
       AND entity_id = p_tenant_id;
    IF v_to_pot_id IS NULL THEN
      RAISE EXCEPTION 'not_found: payee pot; provision payee cashbook';
    END IF;
  END IF;

  -- Idempotency before locks
  -- [CORRECTED: was kind+amount only → also pots, books_rate, allocations]
  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_pays FROM money_kernel.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF FOUND THEN
      IF v_pays.kind <> 'payment'
         OR v_pays.amount <> p_amount
         OR v_pays.from_pot_id IS DISTINCT FROM p_from_pot_id
         OR v_pays.to_pot_id IS DISTINCT FROM v_to_pot_id
         OR v_pays.books_amount <> round(p_amount * v_books_rate, 4)
         OR COALESCE(v_pays.refs->'allocations', 'null'::jsonb)
            IS DISTINCT FROM COALESCE(p_allocations, 'null'::jsonb)
      THEN
        RAISE EXCEPTION 'idempotency_conflict: key % used for different parameters', p_idempotency_key;
      END IF;
      RETURN jsonb_build_object(
        'pays_id', v_pays.id, 'amount', v_pays.amount, 'status', v_pays.status,
        'idempotent', true
      );
    END IF;
  END IF;

  SELECT COALESCE(array_agg(x ORDER BY x), '{}') INTO v_bill_ids
    FROM (
      SELECT DISTINCT (a->>'bill_id')::bigint AS x
        FROM jsonb_array_elements(p_allocations) a
    ) s;

  -- One lock statement for all bills (ascending id)
  PERFORM 1 FROM money_kernel.bills
   WHERE tenant_id = p_tenant_id AND id = ANY(v_bill_ids)
   ORDER BY id
   FOR UPDATE;

  -- Lock + read pots in id order (no second SELECT)
  IF p_from_pot_id < v_to_pot_id THEN
    SELECT * INTO v_from_pot FROM money_kernel.cashbook_point_pots WHERE id = p_from_pot_id FOR UPDATE;
    SELECT * INTO v_to_pot   FROM money_kernel.cashbook_point_pots WHERE id = v_to_pot_id   FOR UPDATE;
  ELSE
    SELECT * INTO v_to_pot   FROM money_kernel.cashbook_point_pots WHERE id = v_to_pot_id   FOR UPDATE;
    SELECT * INTO v_from_pot FROM money_kernel.cashbook_point_pots WHERE id = p_from_pot_id FOR UPDATE;
  END IF;
  IF v_from_pot.id IS NULL OR v_to_pot.id IS NULL THEN
    RAISE EXCEPTION 'not_found: pot';
  END IF;
  IF v_from_pot.tenant_id <> p_tenant_id OR v_to_pot.tenant_id <> p_tenant_id THEN
    RAISE EXCEPTION 'invalid_arguments: pots must belong to tenant %', p_tenant_id;
  END IF;

  PERFORM public.money_kernel_assert_profile_in_tenant(p_tenant_id, p_payer_profile_id);

  PERFORM 1 FROM money_kernel.cashbook_point_pots pp
    JOIN money_kernel.cashbook_points pt ON pt.id = pp.cashbook_point_id
    JOIN money_kernel.cashbook_accounts a ON a.id = pt.cashbook_account_id
   WHERE pp.id = p_from_pot_id AND a.entity_type = 'profile'
     AND a.entity_id = p_payer_profile_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: from_pot % does not belong to profile %', p_from_pot_id, p_payer_profile_id;
  END IF;

  IF v_from_pot.amount < p_amount THEN
    RAISE EXCEPTION 'insufficient_balance: pot % has %, payment is %',
      p_from_pot_id, v_from_pot.amount, p_amount;
  END IF;

  -- Set-based allocation validation (one join pass; first failure wins)
  SELECT x.err INTO v_err
    FROM (
      SELECT
        (a.elem->>'bill_id')::bigint AS bill_id,
        round((a.elem->>'amount')::numeric, 2) AS alloc_amt,
        CASE
          WHEN round((a.elem->>'amount')::numeric, 2) IS NULL
            OR round((a.elem->>'amount')::numeric, 2) <= 0
            THEN 'invalid_amount: each allocation amount must be > 0'
          WHEN b.id IS NULL
            THEN format('not_found: bill %s', a.elem->>'bill_id')
          WHEN b.kind = 'credit_note' OR COALESCE(r.can_be_paid, true) = false
            THEN format(
              'invalid_arguments: bill %s kind %s cannot be cash-paid; use rpc_apply_document_settlement',
              b.id, b.kind)
          WHEN b.status IN ('draft','voided')
            THEN format('invalid_state: cannot pay bill %s status %s', b.id, b.status)
          WHEN b.from_profile_id IS NULL OR b.from_profile_id <> p_payer_profile_id
            THEN format(
              'invalid_arguments: payer_profile %s must equal bill.from_profile_id %s',
              p_payer_profile_id, b.from_profile_id)
          WHEN b.currency_code <> v_from_pot.currency_code
            OR b.currency_code <> v_to_pot.currency_code
            THEN format('invalid_arguments: pots and bill %s must share currency (I7b)', b.id)
          WHEN round((a.elem->>'amount')::numeric, 2) > b.due_amount
            THEN format(
              'invalid_amount: allocation %s exceeds bill %s due %s',
              round((a.elem->>'amount')::numeric, 2), b.id, b.due_amount)
          ELSE NULL
        END AS err
      FROM jsonb_array_elements(p_allocations) WITH ORDINALITY AS a(elem, ord)
      LEFT JOIN money_kernel.bills b
        ON b.id = (a.elem->>'bill_id')::bigint AND b.tenant_id = p_tenant_id
      LEFT JOIN money_kernel.bill_kind_registry r ON r.kind = b.kind
      ORDER BY a.ord
    ) x
   WHERE x.err IS NOT NULL
   LIMIT 1;
  IF v_err IS NOT NULL THEN
    RAISE EXCEPTION '%', v_err;
  END IF;

  SELECT COALESCE(SUM(round((a->>'amount')::numeric, 2)), 0) INTO v_sum_alloc
    FROM jsonb_array_elements(p_allocations) a;
  IF v_sum_alloc > round(p_amount, 2) THEN
    RAISE EXCEPTION 'invalid_amount: sum(allocations) % exceeds pays amount %',
      v_sum_alloc, p_amount;
  END IF;

  v_books := round(p_amount * v_books_rate, 4);
  -- Books for settlements cover allocated cash only; unapplied cash leaves books on pays
  v_settle_books := round(v_sum_alloc * v_books_rate, 4);
  v_books_left := v_settle_books;
  v_alloc_n := jsonb_array_length(p_allocations);

  BEGIN
    INSERT INTO money_kernel.pays (
      tenant_id, kind, from_pot_id, to_pot_id,
      amount, currency_code, books_amount, exchange_rate,
      payment_date, status, idempotency_key, refs, meta, created_by
    ) VALUES (
      p_tenant_id, 'payment', p_from_pot_id, v_to_pot_id,
      p_amount, v_from_pot.currency_code, v_books, 1,
      CURRENT_DATE, 'posted', p_idempotency_key,
      jsonb_build_object('allocations', p_allocations),
      COALESCE(p_meta, '{}'::jsonb), auth.uid()
    ) RETURNING * INTO v_pays;
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_pays FROM money_kernel.pays
     WHERE tenant_id = p_tenant_id AND idempotency_key = p_idempotency_key
       AND status = 'posted';
    IF NOT FOUND THEN RAISE; END IF;
    -- [CORRECTED: same full param match as pre-lock path]
    IF v_pays.kind <> 'payment'
       OR v_pays.amount <> p_amount
       OR v_pays.from_pot_id IS DISTINCT FROM p_from_pot_id
       OR v_pays.to_pot_id IS DISTINCT FROM v_to_pot_id
       OR v_pays.books_amount <> round(p_amount * v_books_rate, 4)
       OR COALESCE(v_pays.refs->'allocations', 'null'::jsonb)
          IS DISTINCT FROM COALESCE(p_allocations, 'null'::jsonb)
    THEN
      RAISE EXCEPTION 'idempotency_conflict: key % used for different parameters', p_idempotency_key;
    END IF;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'amount', v_pays.amount, 'status', v_pays.status,
      'idempotent', true
    );
  END;

  v_alloc_i := 0;
  FOR v_alloc IN SELECT * FROM jsonb_array_elements(p_allocations) LOOP
    v_alloc_i := v_alloc_i + 1;
    v_bill_id := (v_alloc->>'bill_id')::bigint;
    v_alloc_amt := round((v_alloc->>'amount')::numeric, 2);
    IF v_alloc_i = v_alloc_n THEN
      v_line_books := v_books_left;  -- absorb rounding residue
    ELSE
      v_line_books := round(v_alloc_amt * v_books_rate, 4);
      v_books_left := v_books_left - v_line_books;
    END IF;
    INSERT INTO money_kernel.bill_settlements (
      tenant_id, bill_id, settlement_kind, pays_id, source_bill_id,
      allocated_amount, allocated_books_amount
    ) VALUES (
      p_tenant_id, v_bill_id, 'pay', v_pays.id, NULL,
      v_alloc_amt, v_line_books
    ) RETURNING * INTO v_settlement;
    v_settlements := v_settlements || jsonb_build_object(
      'settlement_id', v_settlement.id,
      'bill_id', v_bill_id,
      'allocated_amount', v_alloc_amt
    );
  END LOOP;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'amount', p_amount, 'books_amount', v_books,
    'from_pot_id', p_from_pot_id, 'to_pot_id', v_to_pot_id,
    'settlements', v_settlements, 'status', 'posted', 'idempotent', false
  );
END;
$$;


CREATE OR REPLACE FUNCTION public.rpc_profile_transactions(
  p_tenant_id        bigint,
  p_profile_id       bigint,
  p_from_date        date    DEFAULT NULL,
  p_to_date          date    DEFAULT NULL,
  p_kind             text    DEFAULT NULL,
  p_currency_code    text    DEFAULT NULL,
  p_pot_id           bigint  DEFAULT NULL,
  p_bill_id          bigint  DEFAULT NULL,
  p_include_voided   boolean DEFAULT false,
  p_limit            int     DEFAULT 20,
  p_cursor           jsonb   DEFAULT NULL
    -- {"created_at":"...","pays_id":N,"direction":"in"|"out"}
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_result jsonb;
  v_c_at   timestamptz;
  v_c_pays bigint;
  v_c_dir  text;
BEGIN
  IF p_tenant_id IS NULL OR p_profile_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id and profile_id required';
  END IF;
  IF p_limit < 1 OR p_limit > 500 THEN
    RAISE EXCEPTION 'invalid_arguments: limit must be 1..500';
  END IF;
  IF p_from_date IS NOT NULL AND p_to_date IS NOT NULL AND p_from_date > p_to_date THEN
    RAISE EXCEPTION 'invalid_arguments: from_date must be <= to_date';
  END IF;
  IF p_cursor IS NOT NULL THEN
    v_c_at   := (p_cursor->>'created_at')::timestamptz;
    v_c_pays := (p_cursor->>'pays_id')::bigint;
    v_c_dir  := p_cursor->>'direction';
    IF v_c_at IS NULL OR v_c_pays IS NULL OR v_c_dir IS NULL THEN
      RAISE EXCEPTION 'invalid_arguments: cursor requires created_at, pays_id, direction';
    END IF;
  END IF;

  PERFORM public.money_kernel_assert_profile_in_tenant(p_tenant_id, p_profile_id);

  WITH my_pots AS (
    SELECT pp.id AS pot_id, pp.currency_code, pp.amount AS current_balance
      FROM money_kernel.cashbook_point_pots pp
      JOIN money_kernel.cashbook_points    pt ON pt.id = pp.cashbook_point_id
      JOIN money_kernel.cashbook_accounts  a  ON a.id  = pt.cashbook_account_id
     WHERE a.tenant_id = p_tenant_id
       AND a.entity_type = 'profile'
       AND a.entity_id = p_profile_id
       AND (p_pot_id IS NULL OR pp.id = p_pot_id)
       AND (p_currency_code IS NULL OR pp.currency_code = p_currency_code)
  ),
  legs AS (
    SELECT p.id AS pays_id, p.kind, p.payment_date, p.created_at,
           mp.pot_id, mp.currency_code AS pot_currency, mp.current_balance,
           p.books_amount, p.exchange_rate, p.refs, p.meta, p.status,
           'out'::text AS direction,
           p.amount           AS leg_amount,
           -p.amount          AS signed_amount,
           CASE WHEN p.status = 'posted' THEN -p.amount ELSE 0 END AS signed_for_balance,
           p.to_pot_id        AS other_pot_id
      FROM money_kernel.pays p
      JOIN my_pots mp ON mp.pot_id = p.from_pot_id
     WHERE p.tenant_id = p_tenant_id
       AND p.from_pot_id IS NOT NULL
       AND (p_include_voided OR p.status = 'posted')
       AND (p_from_date IS NULL OR p.payment_date >= p_from_date)
       AND (p_to_date   IS NULL OR p.payment_date <= p_to_date)
       AND (p_kind      IS NULL OR p.kind = p_kind)
       AND (p_bill_id   IS NULL OR EXISTS (
         SELECT 1 FROM money_kernel.bill_settlements bs
          WHERE bs.pays_id = p.id AND bs.bill_id = p_bill_id))

    UNION ALL

    SELECT p.id, p.kind, p.payment_date, p.created_at,
           mp.pot_id, mp.currency_code, mp.current_balance,
           p.books_amount, p.exchange_rate, p.refs, p.meta, p.status,
           'in'::text,
           CASE WHEN p.kind = 'transfer' THEN p.amount * p.exchange_rate ELSE p.amount END,
           CASE WHEN p.kind = 'transfer' THEN p.amount * p.exchange_rate ELSE p.amount END,
           CASE WHEN p.status = 'posted'
                THEN (CASE WHEN p.kind = 'transfer'
                           THEN p.amount * p.exchange_rate ELSE p.amount END)
                ELSE 0 END,
           p.from_pot_id
      FROM money_kernel.pays p
      JOIN my_pots mp ON mp.pot_id = p.to_pot_id
     WHERE p.tenant_id = p_tenant_id
       AND p.to_pot_id IS NOT NULL
       AND (p_include_voided OR p.status = 'posted')
       AND (p_from_date IS NULL OR p.payment_date >= p_from_date)
       AND (p_to_date   IS NULL OR p.payment_date <= p_to_date)
       AND (p_kind      IS NULL OR p.kind = p_kind)
       AND (p_bill_id   IS NULL OR EXISTS (
         SELECT 1 FROM money_kernel.bill_settlements bs
          WHERE bs.pays_id = p.id AND bs.bill_id = p_bill_id))
  ),
  with_balance AS MATERIALIZED (
    SELECT l.*,
           l.current_balance - COALESCE(
             SUM(l.signed_for_balance) OVER (
               PARTITION BY l.pot_id
               ORDER BY l.created_at DESC, l.pays_id DESC, l.direction DESC
               ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
             ), 0
           ) AS balance_after
      FROM legs l
  ),
  filtered AS (
    SELECT *
      FROM with_balance wb
     WHERE p_cursor IS NULL
        OR (wb.created_at, wb.pays_id, wb.direction)
             < (v_c_at, v_c_pays, v_c_dir)
     ORDER BY created_at DESC, pays_id DESC, direction DESC
     LIMIT p_limit + 1
  ),
  page_rows AS (
    SELECT f.*, row_number() OVER () AS _rn
      FROM filtered f
     LIMIT p_limit
  )
  SELECT jsonb_build_object(
    'profile_id',  p_profile_id,
    'limit',       p_limit,
    'has_more',    (SELECT count(*) > p_limit FROM filtered),
    'next_cursor', CASE
      WHEN (SELECT count(*) > p_limit FROM filtered) THEN (
        SELECT jsonb_build_object(
          'created_at', b.created_at,
          'pays_id',    b.pays_id,
          'direction',  b.direction
        )
        FROM page_rows b
        WHERE b._rn = (SELECT max(_rn) FROM page_rows)
      )
      ELSE NULL
    END,
    'balances', jsonb_build_object(
      'by_pot', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'pot_id', pot_id, 'currency', currency_code, 'balance', current_balance
        ) ORDER BY pot_id)
        FROM my_pots
      ), '[]'::jsonb),
      'by_currency', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'currency', currency_code, 'balance', SUM(current_balance)
        ) ORDER BY currency_code)
        FROM my_pots GROUP BY currency_code
      ), '[]'::jsonb)
    ),
    'transactions', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'pays_id',       pd.pays_id,
        'kind',          pd.kind,
        'payment_date',  pd.payment_date,
        'created_at',    pd.created_at,
        'status',        pd.status,
        'direction',     pd.direction,
        'signed_amount', pd.signed_amount,
        'leg_amount',    pd.leg_amount,
        'pot_id',        pd.pot_id,
        'pot_currency',  pd.pot_currency,
        'balance_after', pd.balance_after,
        'books_amount',  pd.books_amount,
        'exchange_rate', pd.exchange_rate,
        'other_side', CASE
          WHEN pd.other_pot_id IS NULL
            THEN jsonb_build_object('kind', 'external')
          ELSE (
            SELECT jsonb_build_object(
              'pot_id',   pp.id,
              'currency', pp.currency_code,
              'kind',     a.entity_type,
              'id',       a.entity_id,
              'name',     COALESCE(pr.name, t.name, a.entity_type)
            )
            FROM money_kernel.cashbook_point_pots pp
            JOIN money_kernel.cashbook_points    pt ON pt.id = pp.cashbook_point_id
            JOIN money_kernel.cashbook_accounts  a  ON a.id  = pt.cashbook_account_id
            LEFT JOIN public.profiles      pr ON pr.id = a.entity_id AND a.entity_type = 'profile' AND pr.tenant_id = a.tenant_id
            LEFT JOIN public.tenants       t  ON t.id  = a.entity_id AND a.entity_type = 'tenant'
            WHERE pp.id = pd.other_pot_id
          )
        END,
        'refs', pd.refs,
        'meta', pd.meta
      ) ORDER BY pd.created_at DESC, pd.pays_id DESC, pd.direction DESC)
      FROM page_rows pd
    ), '[]'::jsonb),
    'echoed_filters', jsonb_build_object(
      'tenant_id',      p_tenant_id,
      'profile_id',     p_profile_id,
      'from_date',      p_from_date,
      'to_date',        p_to_date,
      'kind',           p_kind,
      'currency_code',  p_currency_code,
      'pot_id',         p_pot_id,
      'bill_id',        p_bill_id,
      'include_voided', p_include_voided,
      'limit',          p_limit,
      'cursor',         p_cursor
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;


CREATE OR REPLACE FUNCTION public.list_bills_desk_page(
  p_tenant_id bigint,
  p_to_profile_type text DEFAULT NULL,
  p_from_profile_id bigint DEFAULT NULL,
  p_invoice_status text DEFAULT NULL,
  p_payment_status text DEFAULT NULL,
  p_quick_filter text DEFAULT NULL,
  p_page_size integer DEFAULT 25,
  p_cursor bigint DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent_id bigint;
  v_limit integer;
  v_data jsonb;
  v_fetched integer;
  v_has_more boolean := false;
  v_next_cursor bigint;
  v_to_type text := nullif(trim(coalesce(p_to_profile_type, '')), '');
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  IF NOT (
    public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
    OR public.user_can_manage_books_tenant(v_parent_id)
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  v_limit := greatest(COALESCE(p_page_size, 25), 1);

  SELECT COALESCE(jsonb_agg(row_json ORDER BY sort_id DESC), '[]'::jsonb)
  INTO v_data
  FROM (
    SELECT sort_id, row_json
    FROM (
      SELECT
        b.id AS sort_id,
        jsonb_build_object(
          'id', b.id,
          'invoice_no', b.invoice_no,
          'invoice_date', b.invoice_date,
          'invoice_type', b.invoice_type::text,
          'invoice_status', b.invoice_status::text,
          'payment_status', b.payment_status::text,
          'total_amount', b.total_amount,
          'due_amount', COALESCE(ks.open_books, b.due_amount),
          'currency_code', upper(COALESCE(b.currency_code, 'BDT')),
          'from_profile_id', b.from_profile_id,
          'from_profile_name', from_pr.name,
          'from_profile_type', from_pr.profile_type::text,
          'to_profile_id', b.to_profile_id,
          'to_profile_name', to_pr.name,
          'to_profile_type', to_pr.profile_type::text,
          'profile_name', to_pr.name,
          'ap_kind', b.ap_kind,
          'document_kind', b.document_kind::text,
          'parent_bill_id', b.parent_bill_id,
          'spine', 'legacy',
          'kind', NULL,
          'list_status', public._desk_list_status_slug(
            b.invoice_status::text,
            b.payment_status::text,
            COALESCE(ks.open_books, b.due_amount),
            NULL
          )
        ) AS row_json
      FROM public.bills b
      INNER JOIN public.profiles to_pr
        ON to_pr.id = b.to_profile_id AND to_pr.tenant_id = v_parent_id
      LEFT JOIN public.profiles from_pr
        ON from_pr.id = b.from_profile_id AND from_pr.tenant_id = v_parent_id
      LEFT JOIN public.v_kernel_bill_summaries ks ON ks.bill_id = b.id
      WHERE b.tenant_id = v_parent_id
        AND (v_to_type IS NULL OR to_pr.profile_type::text = v_to_type)
        AND (p_from_profile_id IS NULL OR b.from_profile_id = p_from_profile_id)
        AND (p_payment_status IS NULL OR b.payment_status::text = p_payment_status)
        AND (
          p_invoice_status IS NULL
          OR (
            p_invoice_status = 'draft'
            AND b.invoice_status IN ('draft', 'proforma_generated')
          )
          OR (
            p_invoice_status <> 'draft'
            AND b.invoice_status::text = p_invoice_status
          )
        )
        AND (
          p_quick_filter IS NULL OR p_quick_filter = ''
          OR (p_quick_filter = 'paid' AND COALESCE(ks.open_books, b.due_amount) <= 0 AND b.invoice_status = 'issued')
          OR (p_quick_filter = 'paid' AND b.payment_status = 'paid')
          OR (p_quick_filter = 'unpaid' AND COALESCE(ks.open_books, b.due_amount) > 0 AND b.invoice_status = 'issued')
        )
        AND (p_cursor IS NULL OR b.id < p_cursor)

      UNION ALL

      SELECT
        b.id AS sort_id,
        jsonb_build_object(
          'id', b.id,
          'invoice_no', b.invoice_no,
          'invoice_date', b.invoice_date,
          'invoice_type', public._desk_kernel_kind_invoice_type(b.kind),
          'invoice_status', CASE b.status WHEN 'draft' THEN 'draft' WHEN 'voided' THEN 'voided' ELSE 'issued' END,
          'payment_status', public._desk_kernel_status_payment(b.status, b.due_amount),
          'total_amount', b.total_amount,
          'due_amount', b.due_amount,
          'currency_code', upper(b.currency_code),
          'from_profile_id', b.from_profile_id,
          'from_profile_name', from_pr.name,
          'from_profile_type', from_pr.profile_type,
          'to_profile_id', b.to_profile_id,
          'to_profile_name', to_pr.name,
          'to_profile_type', to_pr.profile_type,
          'profile_name', to_pr.name,
          'ap_kind', COALESCE(b.meta->>'ap_kind', NULL),
          'document_kind', CASE b.kind WHEN 'credit_note' THEN 'credit_note' WHEN 'debit_note' THEN 'debit_note' ELSE 'standard' END,
          'parent_bill_id', b.parent_bill_id,
          'spine', 'kernel',
          'kind', b.kind,
          'list_status', public._desk_list_status_slug(
            CASE b.status WHEN 'draft' THEN 'draft' WHEN 'voided' THEN 'voided' ELSE 'issued' END,
            public._desk_kernel_status_payment(b.status, b.due_amount),
            b.due_amount,
            b.status
          )
        ) AS row_json
      FROM money_kernel.bills b
      INNER JOIN public.profiles to_pr
        ON to_pr.id = b.to_profile_id AND to_pr.tenant_id = b.tenant_id
      LEFT JOIN public.profiles from_pr
        ON from_pr.id = b.from_profile_id AND from_pr.tenant_id = b.tenant_id
      WHERE b.tenant_id = v_parent_id
        AND NOT EXISTS (SELECT 1 FROM public.bills pb WHERE pb.id = b.id)
        AND (v_to_type IS NULL OR to_pr.profile_type::text = v_to_type)
        AND (p_from_profile_id IS NULL OR b.from_profile_id = p_from_profile_id)
        AND (p_payment_status IS NULL OR public._desk_kernel_status_payment(b.status, b.due_amount) = p_payment_status)
        AND (
          p_invoice_status IS NULL
          OR (p_invoice_status = 'draft' AND b.status = 'draft')
          OR (p_invoice_status = 'voided' AND b.status = 'voided')
          OR (p_invoice_status = 'issued' AND b.status IN ('issued', 'partial', 'paid', 'written_off'))
        )
        AND (
          p_quick_filter IS NULL OR p_quick_filter = ''
          OR (p_quick_filter = 'paid' AND (b.status IN ('paid', 'written_off') OR b.due_amount <= 0))
          OR (p_quick_filter = 'unpaid' AND b.due_amount > 0 AND b.status NOT IN ('voided', 'draft', 'paid', 'written_off'))
        )
        AND (p_cursor IS NULL OR b.id < p_cursor)
    ) combined
    ORDER BY sort_id DESC
    LIMIT v_limit + 1
  ) q;

  v_fetched := COALESCE(jsonb_array_length(v_data), 0);
  IF v_fetched > v_limit THEN
    v_has_more := true;
    v_data := COALESCE(
      (
        SELECT jsonb_agg(elem ORDER BY (elem->>'id')::bigint DESC)
        FROM (
          SELECT elem
          FROM jsonb_array_elements(v_data) AS elem
          LIMIT v_limit
        ) trimmed
      ),
      '[]'::jsonb
    );
  END IF;

  IF COALESCE(jsonb_array_length(v_data), 0) > 0 THEN
    v_next_cursor := (v_data->(jsonb_array_length(v_data) - 1)->>'id')::bigint;
  ELSE
    v_next_cursor := NULL;
  END IF;

  IF NOT v_has_more THEN
    v_next_cursor := NULL;
  END IF;

  RETURN jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    )
  );
END;
$$;

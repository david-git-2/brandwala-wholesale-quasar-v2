-- P5a/P5b: wallet staff RPCs (LIST_WALLET_ENTITIES + UNIVERSAL_WALLET_DETAIL specs)

CREATE OR REPLACE FUNCTION public.wallet_staff_can_view(p_tenant_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    public.is_superadmin()
    OR public.membership_has_module_action(public.resolve_parent_tenant_id(p_tenant_id), 'universal_wallet', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'universal_wallet', 'view')
    OR public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id));
$$;

CREATE OR REPLACE FUNCTION public.wallet_staff_can_edit(p_tenant_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    public.is_superadmin()
    OR public.membership_has_module_action(public.resolve_parent_tenant_id(p_tenant_id), 'universal_wallet', 'edit')
    OR public.membership_has_module_action(p_tenant_id, 'universal_wallet', 'edit')
    OR public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id));
$$;

CREATE OR REPLACE FUNCTION public.list_wallet_entities_for_staff(
  p_tenant_id bigint,
  p_entity_type text,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 100,
  p_offset integer DEFAULT 0,
  p_currency_code text DEFAULT 'BDT'
)
RETURNS TABLE (
  entity_id bigint,
  entity_type text,
  name text,
  code text,
  caption text,
  available_balance numeric(18,4),
  pending_balance numeric(18,4),
  locked_balance numeric(18,4),
  total_balance numeric(18,4),
  source_uuid uuid,
  operating_tenant_id bigint,
  has_wallet_activity boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_books_id bigint;
  v_search text;
  v_limit integer;
  v_offset integer;
BEGIN
  IF p_entity_type NOT IN ('customer', 'vendor', 'courier', 'cargo_company', 'investor') THEN
    RAISE EXCEPTION 'Invalid entity_type %. Allowed: customer, vendor, courier, cargo_company, investor', p_entity_type;
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT public.wallet_staff_can_view(p_tenant_id) THEN
    RETURN;
  END IF;

  v_search := nullif(trim(p_search), '');
  v_limit := greatest(least(coalesce(p_limit, 100), 500), 1);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  IF p_entity_type = 'customer' THEN
    RETURN QUERY
    SELECT
      bp.id,
      'customer'::text,
      CASE WHEN cg.name IS NOT NULL THEN cg.name || ' · ' || bp.name ELSE bp.name END,
      NULL::text,
      nullif(trim(concat_ws(' • ', bp.phone, bp.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid,
      bp.tenant_id,
      wa.id IS NOT NULL
    FROM public.billing_profiles bp
    LEFT JOIN public.customer_groups cg ON cg.id = bp.customer_group_id
    LEFT JOIN public.wallet_accounts wa
      ON wa.parent_tenant_id = v_books_id
     AND wa.entity_type = 'customer'
     AND wa.entity_id = bp.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE (bp.tenant_id = v_books_id
       OR bp.tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id))
      AND (
        v_search IS NULL
        OR bp.name ILIKE '%' || v_search || '%'
        OR coalesce(cg.name, '') ILIKE '%' || v_search || '%'
        OR coalesce(bp.phone, '') ILIKE '%' || v_search || '%'
        OR coalesce(bp.email, '') ILIKE '%' || v_search || '%'
      )
    ORDER BY 3 ASC, bp.id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'vendor' THEN
    RETURN QUERY
    SELECT
      v.id, 'vendor'::text, v.name, v.code,
      nullif(trim(concat_ws(' • ', v.phone, v.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid, v.tenant_id, wa.id IS NOT NULL
    FROM public.vendors v
    LEFT JOIN public.wallet_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'vendor' AND wa.entity_id = v.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE v.tenant_id = v_books_id
      AND (v_search IS NULL OR v.name ILIKE '%' || v_search || '%' OR coalesce(v.code, '') ILIKE '%' || v_search || '%')
    ORDER BY v.name ASC, v.id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'cargo_company' THEN
    RETURN QUERY
    SELECT
      c.id, 'cargo_company'::text, c.name, c.code,
      nullif(trim(concat_ws(' • ', c.phone, c.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid, c.tenant_id, wa.id IS NOT NULL
    FROM public.cargo_companies c
    LEFT JOIN public.wallet_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'cargo_company' AND wa.entity_id = c.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE c.tenant_id = v_books_id
      AND (v_search IS NULL OR c.name ILIKE '%' || v_search || '%' OR coalesce(c.code, '') ILIKE '%' || v_search || '%')
    ORDER BY c.name ASC, c.id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'courier' THEN
    RETURN QUERY
    SELECT
      cs.wallet_entity_id,
      'courier'::text,
      cs.name,
      upper(cs.code),
      coalesce(nullif(trim(cs.notes), ''), 'Courier service'),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      cs.id,
      coalesce(cs.tenant_id, v_books_id),
      wa.id IS NOT NULL
    FROM public.courier_services cs
    LEFT JOIN public.wallet_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'courier' AND wa.entity_id = cs.wallet_entity_id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE cs.is_active = true
      AND cs.wallet_entity_id IS NOT NULL
      AND (cs.tenant_id IS NULL OR cs.tenant_id = v_books_id
           OR cs.tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id))
      AND (v_search IS NULL OR cs.name ILIKE '%' || v_search || '%' OR coalesce(cs.code, '') ILIKE '%' || v_search || '%')
    ORDER BY cs.name ASC, cs.wallet_entity_id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'investor' THEN
    RETURN QUERY
    SELECT
      i.id, 'investor'::text, i.name, NULL::text,
      nullif(trim(concat_ws(' • ', i.phone, i.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid, i.tenant_id, wa.id IS NOT NULL
    FROM public.investors i
    LEFT JOIN public.wallet_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'investor' AND wa.entity_id = i.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE i.tenant_id = v_books_id
      AND (v_search IS NULL OR i.name ILIKE '%' || v_search || '%')
    ORDER BY i.name ASC, i.id ASC
    LIMIT v_limit OFFSET v_offset;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_wallet_detail_for_staff(
  p_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_currency_code text DEFAULT 'BDT'
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
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
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_operating_id := p_tenant_id;
  v_entity_id := p_entity_id;

  IF NOT public.wallet_staff_can_view(p_tenant_id) THEN
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
      CASE WHEN cg.name IS NOT NULL THEN cg.name || ' · ' || bp.name ELSE bp.name END,
      nullif(trim(concat_ws(' • ', bp.phone, bp.email)), '')
    INTO v_name, v_caption
    FROM public.billing_profiles bp
    LEFT JOIN public.customer_groups cg ON cg.id = bp.customer_group_id
    WHERE bp.id = p_entity_id
      AND (bp.tenant_id = v_books_id OR bp.tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id));
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

  v_account := public.get_wallet_account_balances(v_books_id, p_entity_type, v_entity_id, p_currency_code);

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
      'total_balance', coalesce((v_account->>'total_balance')::numeric, 0)
    ),
    'permissions', jsonb_build_object(
      'can_record_manual', public.wallet_staff_can_edit(p_tenant_id),
      'can_reverse', public.wallet_staff_can_edit(p_tenant_id)
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.list_wallet_ledger_for_staff(
  p_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_search text DEFAULT NULL,
  p_operating_tenant_id bigint DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  parent_tenant_id bigint,
  operating_tenant_id bigint,
  entity_type text,
  entity_id bigint,
  type text,
  amount numeric(15,4),
  currency_code text,
  exchange_rate numeric(15,6),
  base_amount numeric(15,4),
  balance_after numeric(15,4),
  source_type text,
  source_id text,
  metadata jsonb,
  created_at timestamptz,
  is_reversal boolean,
  reversed_entry_id uuid
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_books_id bigint;
  v_entity_id bigint;
  v_search text;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN v_entity_id := v_books_id; END IF;

  IF NOT public.wallet_staff_can_view(p_tenant_id) THEN RETURN; END IF;

  v_search := nullif(trim(p_search), '');

  RETURN QUERY
  SELECT
    l.id,
    l.parent_tenant_id,
    l.operating_tenant_id,
    l.entity_type,
    l.entity_id,
    l.type,
    l.amount,
    l.currency_code,
    l.exchange_rate,
    l.base_amount,
    l.balance_after,
    l.source_type,
    l.source_id,
    l.metadata,
    l.created_at,
    (l.metadata ? 'reversal_of'),
    CASE WHEN l.metadata ? 'reversal_of' THEN (l.metadata->>'reversal_of')::uuid ELSE NULL END
  FROM public.universal_wallet_ledger l
  WHERE l.parent_tenant_id = v_books_id
    AND l.entity_type = p_entity_type
    AND l.entity_id = v_entity_id
    AND (p_operating_tenant_id IS NULL OR l.operating_tenant_id = p_operating_tenant_id)
    AND (
      v_search IS NULL
      OR coalesce(l.source_id, '') ILIKE '%' || v_search || '%'
      OR coalesce(l.metadata->>'note', '') ILIKE '%' || v_search || '%'
      OR coalesce(l.metadata->>'trx_id', '') ILIKE '%' || v_search || '%'
      OR coalesce(l.metadata->>'section', '') ILIKE '%' || v_search || '%'
      OR coalesce(l.source_type, '') ILIKE '%' || v_search || '%'
    )
  ORDER BY l.created_at DESC, l.id DESC
  LIMIT greatest(least(coalesce(p_limit, 50), 200), 1)
  OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.record_wallet_manual_transaction_for_staff(
  p_tenant_id bigint,
  p_action_type text,
  p_primary_entity_type text,
  p_primary_entity_id bigint,
  p_amount numeric,
  p_currency_code text DEFAULT 'BDT',
  p_exchange_rate numeric DEFAULT 1.000000,
  p_category text DEFAULT NULL,
  p_payment_method text DEFAULT NULL,
  p_reference_id text DEFAULT NULL,
  p_note text DEFAULT NULL,
  p_counterparty_entity_type text DEFAULT NULL,
  p_counterparty_entity_id bigint DEFAULT NULL,
  p_target_bucket text DEFAULT 'available'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_books_id bigint;
  v_operating_id bigint;
  v_source_id text;
  v_meta jsonb;
  v_primary_id bigint;
  v_ledger_ids uuid[] := '{}';
  v_entry jsonb;
  v_primary_entity_id bigint;
  v_counterparty_id bigint;
BEGIN
  IF NOT public.wallet_staff_can_edit(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  IF coalesce(p_amount, 0) <= 0 OR coalesce(p_exchange_rate, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'amount and exchange_rate must be positive');
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_operating_id := p_tenant_id;
  v_primary_entity_id := p_primary_entity_id;
  IF p_primary_entity_type = 'tenant' THEN v_primary_entity_id := v_books_id; END IF;

  v_source_id := coalesce(nullif(trim(p_reference_id), ''),
    CASE p_action_type
      WHEN 'pay' THEN 'MAN-PAY-' || gen_random_uuid()::text
      WHEN 'withdraw' THEN 'MAN-WD-' || gen_random_uuid()::text
      WHEN 'deposit' THEN 'MAN-DEP-' || gen_random_uuid()::text
      ELSE 'MAN-CR-' || gen_random_uuid()::text
    END);

  v_meta := jsonb_build_object(
    'section', p_category,
    'method', p_payment_method,
    'trx_id', v_source_id,
    'note', p_note,
    'action_type', p_action_type,
    'transaction_type', 'manual_adjustment',
    'label', initcap(p_action_type),
    'recorded_by', public.current_user_email(),
    'target_bucket', coalesce(p_target_bucket, 'available')
  );

  IF p_action_type IN ('pay', 'credit') AND p_primary_entity_type = 'tenant'
     AND (p_counterparty_entity_type IS NULL OR p_counterparty_entity_id IS NULL) THEN
    RETURN jsonb_build_object('success', false, 'error', 'counterparty required');
  END IF;

  IF p_action_type = 'deposit' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'withdraw' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'debit', p_amount, p_currency_code, p_exchange_rate,
      'payout', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'credit' AND p_primary_entity_type = 'tenant' THEN
    v_counterparty_id := p_counterparty_entity_id;
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_counterparty_entity_type, v_counterparty_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'credit' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'pay' AND p_primary_entity_type = 'tenant' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, 'tenant', v_books_id,
      'debit', p_amount, p_currency_code, p_exchange_rate,
      CASE WHEN p_category = 'vendor_purchase' THEN 'vendor_purchase' ELSE 'adjustment' END,
      v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_counterparty_entity_type, p_counterparty_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      CASE WHEN p_category = 'vendor_purchase' THEN 'vendor_purchase' ELSE 'adjustment' END,
      v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'pay' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, 'tenant', v_books_id,
      'debit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'invalid action_type');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'ledger_entry_ids', to_jsonb(v_ledger_ids),
    'primary_account', public.get_wallet_account_balances(v_books_id, p_primary_entity_type, v_primary_entity_id, p_currency_code)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.reverse_wallet_ledger_entry_for_staff(
  p_tenant_id bigint,
  p_ledger_entry_id uuid,
  p_reason text,
  p_reference_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_books_id bigint;
  v_orig public.universal_wallet_ledger%ROWTYPE;
  v_reversal_type text;
  v_reversal_id uuid;
  v_meta jsonb;
  v_entry jsonb;
BEGIN
  IF NOT public.wallet_staff_can_edit(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  IF nullif(trim(p_reason), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'reason required');
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  SELECT * INTO v_orig FROM public.universal_wallet_ledger WHERE id = p_ledger_entry_id;
  IF v_orig.id IS NULL OR v_orig.parent_tenant_id <> v_books_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'entry not found');
  END IF;

  IF v_orig.metadata ? 'reversed_by' OR v_orig.metadata ? 'reversal_of' THEN
    RETURN jsonb_build_object('success', false, 'error', 'entry already reversed or is a reversal');
  END IF;

  IF v_orig.source_type = 'shop_order' AND NOT coalesce((v_orig.metadata->>'allow_manual_reversal')::boolean, false)
     AND NOT public.is_superadmin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'system shop_order entries cannot be reversed');
  END IF;

  v_reversal_type := CASE WHEN v_orig.type = 'credit' THEN 'debit' ELSE 'credit' END;
  v_meta := jsonb_build_object(
    'reversal_of', v_orig.id::text,
    'transaction_type', 'manual_reversal',
    'note', p_reason,
    'trx_id', coalesce(p_reference_id, 'REV-' || gen_random_uuid()::text),
    'recorded_by', public.current_user_email()
  );

  v_entry := public.record_ledger_transaction(
    v_orig.parent_tenant_id,
    v_orig.operating_tenant_id,
    v_orig.entity_type,
    v_orig.entity_id,
    v_reversal_type,
    v_orig.amount,
    v_orig.currency_code,
    v_orig.exchange_rate,
    v_orig.source_type,
    coalesce(p_reference_id, v_orig.source_id),
    v_meta,
    coalesce(v_orig.metadata->>'target_bucket', 'available'),
    false
  );
  v_reversal_id := (v_entry->>'id')::uuid;

  UPDATE public.universal_wallet_ledger
  SET metadata = metadata || jsonb_build_object('reversed_by', v_reversal_id::text)
  WHERE id = v_orig.id;

  RETURN jsonb_build_object(
    'success', true,
    'reversal_entry_id', v_reversal_id,
    'account', public.get_wallet_account_balances(
      v_books_id, v_orig.entity_type, v_orig.entity_id, v_orig.currency_code
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_wallet_entities_for_staff(bigint, text, text, integer, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_wallet_detail_for_staff(bigint, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_wallet_ledger_for_staff(bigint, text, bigint, text, bigint, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_wallet_manual_transaction_for_staff(
  bigint, text, text, bigint, numeric, text, numeric, text, text, text, text, text, bigint, text
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reverse_wallet_ledger_entry_for_staff(bigint, uuid, text, text) TO authenticated;

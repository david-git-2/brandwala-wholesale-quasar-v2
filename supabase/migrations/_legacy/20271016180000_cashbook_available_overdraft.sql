-- Allow negative available balance on cashbook debits and transfers.
CREATE OR REPLACE FUNCTION "public"."record_ledger_transaction"("p_parent_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_type" "text", "p_amount" numeric, "p_currency_code" "text" DEFAULT 'BDT'::"text", "p_exchange_rate" numeric DEFAULT 1.000000, "p_source_type" "text" DEFAULT 'adjustment'::"text", "p_source_id" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb", "p_target_bucket" "text" DEFAULT 'available'::"text", "p_allow_overdraft" boolean DEFAULT false, "p_cashbook_point_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
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
  IF p_entity_type = 'tenant' AND v_entity_id IS DISTINCT FROM p_parent_tenant_id THEN
    v_entity_id := p_parent_tenant_id;
  END IF;

  INSERT INTO public.cashbook_accounts (
    tenant_id, parent_tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance
  )
  VALUES (
    p_parent_tenant_id, p_parent_tenant_id, p_entity_type, v_entity_id,
    coalesce(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000
  )
  ON CONFLICT (parent_tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  IF p_cashbook_point_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.cashbook_points cp
      WHERE cp.id = p_cashbook_point_id
        AND cp.parent_tenant_id = p_parent_tenant_id
        AND cp.cashbook_account_id = v_account_id
        AND cp.is_active = true
    ) INTO v_point_ok;
    IF NOT coalesce(v_point_ok, false) THEN
      RAISE EXCEPTION 'Invalid cashbook point for this account.';
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
    tenant_id = p_parent_tenant_id,
    updated_at = now()
  WHERE id = v_account_id;

  v_base_amount := p_amount * coalesce(p_exchange_rate, 1.000000);

  INSERT INTO public.cashbook_entries (
    tenant_id,
    parent_tenant_id,
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
    cashbook_point_id
  )
  VALUES (
    p_parent_tenant_id,
    p_parent_tenant_id,
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
    p_cashbook_point_id
  )
  RETURNING id INTO v_ledger_id;

  SELECT jsonb_build_object(
    'id', id,
    'parent_tenant_id', parent_tenant_id,
    'operating_tenant_id', operating_tenant_id,
    'tenant_id', parent_tenant_id,
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

CREATE OR REPLACE FUNCTION "public"."transfer_wallet_balance"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_from_bucket" "text", "p_to_bucket" "text", "p_amount" numeric, "p_currency_code" "text" DEFAULT 'BDT'::"text", "p_notes" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_parent_tenant_id bigint;
  v_operating_tenant_id bigint;
  v_account_id bigint;
  v_avail numeric(18,4);
  v_pend numeric(18,4);
  v_lock numeric(18,4);
  v_result jsonb;
  v_entity_id bigint;
BEGIN
  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_operating_tenant_id := p_tenant_id;
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transfer amount must be greater than zero.';
  END IF;

  IF p_from_bucket = p_to_bucket THEN
    RAISE EXCEPTION 'Source and target buckets cannot be identical.';
  END IF;

  IF p_from_bucket NOT IN ('available', 'pending', 'locked')
     OR p_to_bucket NOT IN ('available', 'pending', 'locked') THEN
    RAISE EXCEPTION 'Invalid bucket specifiers. Must be available, pending, or locked.';
  END IF;

  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_parent_tenant_id;
  END IF;

  INSERT INTO public.cashbook_accounts (
    tenant_id, parent_tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance
  )
  VALUES (
    v_parent_tenant_id, v_parent_tenant_id, p_entity_type, v_entity_id,
    coalesce(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000
  )
  ON CONFLICT (parent_tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  SELECT available_balance, pending_balance, locked_balance
  INTO v_avail, v_pend, v_lock
  FROM public.cashbook_accounts
  WHERE id = v_account_id
  FOR UPDATE;

  IF p_from_bucket = 'pending' THEN
    IF v_pend < p_amount THEN
      RAISE EXCEPTION 'Insufficient pending balance (Pending: %, Requested: %).', v_pend, p_amount;
    END IF;
    v_pend := v_pend - p_amount;
  ELSIF p_from_bucket = 'available' THEN
    v_avail := v_avail - p_amount;
  ELSIF p_from_bucket = 'locked' THEN
    IF v_lock < p_amount THEN
      RAISE EXCEPTION 'Insufficient locked balance (Locked: %, Requested: %).', v_lock, p_amount;
    END IF;
    v_lock := v_lock - p_amount;
  END IF;

  IF p_to_bucket = 'pending' THEN
    v_pend := v_pend + p_amount;
  ELSIF p_to_bucket = 'available' THEN
    v_avail := v_avail + p_amount;
  ELSIF p_to_bucket = 'locked' THEN
    v_lock := v_lock + p_amount;
  END IF;

  UPDATE public.cashbook_accounts
  SET
    available_balance = v_avail,
    pending_balance = v_pend,
    locked_balance = v_lock,
    tenant_id = v_parent_tenant_id,
    updated_at = now()
  WHERE id = v_account_id;

  INSERT INTO public.cashbook_entries (
    tenant_id, parent_tenant_id, operating_tenant_id,
    entity_type, entity_id, type, amount, currency_code,
    exchange_rate, base_amount, balance_after, source_type, source_id, metadata
  )
  VALUES (
    v_parent_tenant_id, v_parent_tenant_id, v_operating_tenant_id,
    p_entity_type, v_entity_id, 'credit', p_amount, coalesce(p_currency_code, 'BDT'),
    1.000000, p_amount, v_avail, 'bucket_transfer', NULL,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'from_bucket', p_from_bucket,
      'to_bucket', p_to_bucket,
      'notes', p_notes
    )
  );

  SELECT jsonb_build_object(
    'account_id', v_account_id,
    'parent_tenant_id', v_parent_tenant_id,
    'tenant_id', v_parent_tenant_id,
    'entity_type', p_entity_type,
    'entity_id', v_entity_id,
    'currency_code', coalesce(p_currency_code, 'BDT'),
    'available_balance', v_avail,
    'pending_balance', v_pend,
    'locked_balance', v_lock
  ) INTO v_result;

  RETURN v_result;
END;
$$;

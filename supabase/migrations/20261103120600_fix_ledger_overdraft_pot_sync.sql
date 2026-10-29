-- BP22 pot sync + AP allow_overdraft: skip pot update when till short; restore books overdraft check.
CREATE OR REPLACE FUNCTION public."record_ledger_transaction"("p_parent_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_entity_type" text, "p_entity_id" bigint, "p_type" text, "p_amount" numeric, "p_currency_code" text DEFAULT 'BDT'::text, "p_exchange_rate" numeric DEFAULT 1.000000, "p_source_type" text DEFAULT 'adjustment'::text, "p_source_id" text DEFAULT NULL::text, "p_metadata" jsonb DEFAULT '{}'::jsonb, "p_target_bucket" text DEFAULT 'available'::text, "p_allow_overdraft" boolean DEFAULT false, "p_cashbook_point_id" bigint DEFAULT NULL::bigint) RETURNS jsonb
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
    available_balance, pending_balance, locked_balance, account_class
  )
  VALUES (
    p_parent_tenant_id, p_parent_tenant_id, p_entity_type, v_entity_id,
    coalesce(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000,
    CASE WHEN p_entity_type = 'tenant' THEN 'tenant_asset'::public.cashbook_account_class
         ELSE 'profile_custody'::public.cashbook_account_class END
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

    v_pot_id := public._kernel_ensure_cashbook_point_pot(
      p_parent_tenant_id,
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
    cashbook_point_id,
    cashbook_point_pot_id
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
    p_cashbook_point_id,
    v_pot_id
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

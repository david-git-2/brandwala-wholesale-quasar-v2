-- Migration: 20270818000010_settle_shipment_payee.sql
-- Description: Add p_allow_overdraft to record_ledger_transaction, and create settle_shipment_payee + list_shipment_payee_settlements RPCs

-- 1. Drop existing record_ledger_transaction function signatures and recreate with p_allow_overdraft
DROP FUNCTION IF EXISTS public.record_ledger_transaction(BIGINT, TEXT, BIGINT, TEXT, NUMERIC, TEXT, NUMERIC, TEXT, TEXT, JSONB);
DROP FUNCTION IF EXISTS public.record_ledger_transaction(BIGINT, TEXT, BIGINT, TEXT, NUMERIC, TEXT, NUMERIC, TEXT, TEXT, JSONB, TEXT);
DROP FUNCTION IF EXISTS public.record_ledger_transaction(BIGINT, TEXT, BIGINT, TEXT, NUMERIC, TEXT, NUMERIC, TEXT, TEXT, JSONB, TEXT, BOOLEAN);

CREATE OR REPLACE FUNCTION public.record_ledger_transaction(
  p_tenant_id BIGINT,
  p_entity_type TEXT,
  p_entity_id BIGINT,
  p_type TEXT, -- 'credit' or 'debit'
  p_amount NUMERIC(18,4),
  p_currency_code TEXT DEFAULT 'BDT',
  p_exchange_rate NUMERIC(12,6) DEFAULT 1.000000,
  p_source_type TEXT DEFAULT 'adjustment',
  p_source_id TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb,
  p_target_bucket TEXT DEFAULT 'available', -- 'available', 'pending', 'locked'
  p_allow_overdraft BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id BIGINT;
  v_avail NUMERIC(18,4);
  v_pend NUMERIC(18,4);
  v_lock NUMERIC(18,4);
  v_base_amount NUMERIC(18,4);
  v_new_balance NUMERIC(18,4);
  v_ledger_entry JSONB;
  v_ledger_id UUID;
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

  -- 1. Upsert & Lock wallet_accounts row
  INSERT INTO public.wallet_accounts (tenant_id, entity_type, entity_id, currency_code, available_balance, pending_balance, locked_balance)
  VALUES (p_tenant_id, p_entity_type, p_entity_id, COALESCE(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000)
  ON CONFLICT (tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  -- Lock row FOR UPDATE
  SELECT available_balance, pending_balance, locked_balance
  INTO v_avail, v_pend, v_lock
  FROM public.wallet_accounts
  WHERE id = v_account_id
  FOR UPDATE;

  -- 2. Apply delta to target bucket
  IF p_target_bucket = 'available' THEN
    IF p_type = 'credit' THEN
      v_avail := v_avail + p_amount;
    ELSE
      IF v_avail < p_amount AND NOT COALESCE(p_allow_overdraft, FALSE) THEN
        RAISE EXCEPTION 'Insufficient available balance (Available: %, Requested debit: %).', v_avail, p_amount;
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

  -- Update materialized balances
  UPDATE public.wallet_accounts
  SET 
    available_balance = v_avail,
    pending_balance = v_pend,
    locked_balance = v_lock,
    updated_at = now()
  WHERE id = v_account_id;

  -- 3. Insert into universal_wallet_ledger
  v_base_amount := p_amount * COALESCE(p_exchange_rate, 1.000000);

  INSERT INTO public.universal_wallet_ledger (
    tenant_id,
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
    metadata
  )
  VALUES (
    p_tenant_id,
    p_entity_type,
    p_entity_id,
    p_type,
    p_amount,
    COALESCE(p_currency_code, 'BDT'),
    COALESCE(p_exchange_rate, 1.000000),
    v_base_amount,
    v_new_balance,
    COALESCE(p_source_type, 'adjustment'),
    p_source_id,
    COALESCE(p_metadata, '{}'::jsonb) || jsonb_build_object('target_bucket', p_target_bucket)
  )
  RETURNING id INTO v_ledger_id;

  -- Return created ledger entry
  SELECT jsonb_build_object(
    'id', id,
    'tenant_id', tenant_id,
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
    'created_at', created_at
  ) INTO v_ledger_entry
  FROM public.universal_wallet_ledger
  WHERE id = v_ledger_id;

  RETURN v_ledger_entry;
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_ledger_transaction(BIGINT, TEXT, BIGINT, TEXT, NUMERIC, TEXT, NUMERIC, TEXT, TEXT, JSONB, TEXT, BOOLEAN) TO authenticated, service_role;


-- 2. settle_shipment_payee RPC
DROP FUNCTION IF EXISTS public.settle_shipment_payee(BIGINT, TEXT, BIGINT, TEXT, NUMERIC, NUMERIC);

CREATE OR REPLACE FUNCTION public.settle_shipment_payee(
  p_shipment_id BIGINT,
  p_entity_type TEXT,
  p_entity_id BIGINT,
  p_action TEXT,
  p_amount NUMERIC,
  p_exchange_rate NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
  v_rate NUMERIC(12,6);
  v_bdt_amount NUMERIC(18,4);
  v_ledger JSONB;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero.';
  END IF;

  IF p_entity_type NOT IN ('vendor', 'cargo_company') THEN
    RAISE EXCEPTION 'Entity type must be vendor or cargo_company.';
  END IF;

  IF p_action NOT IN ('pay', 'record_credit', 'use_credit') THEN
    RAISE EXCEPTION 'Action must be pay, record_credit, or use_credit.';
  END IF;

  -- Lock shipment row
  SELECT * INTO v_ship
  FROM public.global_shipments
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF v_ship.status IS DISTINCT FROM 'received' THEN
    RAISE EXCEPTION 'shipment must be received before settlement';
  END IF;

  IF NOT public.has_active_tenant_membership(v_ship.parent_tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  -- Payee header validation
  IF p_entity_type = 'vendor' THEN
    IF v_ship.vendor_id IS NULL OR v_ship.vendor_id <> p_entity_id THEN
      RAISE EXCEPTION 'vendor_id does not match shipment header';
    END IF;
  ELSIF p_entity_type = 'cargo_company' THEN
    IF v_ship.cargo_company_id IS NULL OR v_ship.cargo_company_id <> p_entity_id THEN
      RAISE EXCEPTION 'cargo_company_id does not match shipment header';
    END IF;
  END IF;

  -- Determine exchange rate
  IF p_exchange_rate IS NOT NULL AND p_exchange_rate > 0 THEN
    v_rate := p_exchange_rate;
  ELSE
    IF p_entity_type = 'vendor' THEN
      SELECT COALESCE(exchange_rate, 1.000000) INTO v_rate
      FROM public.global_shipment_cost_entries
      WHERE shipment_id = p_shipment_id
        AND cost_category = 'product'
      ORDER BY id ASC
      LIMIT 1;
    ELSIF p_entity_type = 'cargo_company' THEN
      SELECT COALESCE(exchange_rate, 1.000000) INTO v_rate
      FROM public.global_shipment_cost_entries
      WHERE shipment_id = p_shipment_id
        AND cost_category = 'cargo'
      ORDER BY id ASC
      LIMIT 1;
    END IF;
  END IF;

  v_rate := COALESCE(v_rate, 1.000000);
  IF v_rate <= 0 THEN
    v_rate := 1.000000;
  END IF;

  v_bdt_amount := ROUND(p_amount * v_rate, 4);

  IF p_action = 'pay' THEN
    -- Action: pay — debit tenant available (overdraft allowed). Payee available untouched.
    v_ledger := public.record_ledger_transaction(
      p_tenant_id => v_ship.parent_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_ship.parent_tenant_id,
      p_type => 'debit',
      p_amount => v_bdt_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'shipment',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object(
        'action', 'pay',
        'payee_type', p_entity_type,
        'payee_id', p_entity_id,
        'amount_input', p_amount,
        'exchange_rate', v_rate
      ),
      p_target_bucket => 'available',
      p_allow_overdraft => true
    );
  ELSIF p_action = 'record_credit' THEN
    -- Action: record_credit — credit payee available. Tenant unchanged.
    v_ledger := public.record_ledger_transaction(
      p_tenant_id => v_ship.parent_tenant_id,
      p_entity_type => p_entity_type,
      p_entity_id => p_entity_id,
      p_type => 'credit',
      p_amount => v_bdt_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'shipment',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object(
        'action', 'record_credit',
        'payee_type', p_entity_type,
        'payee_id', p_entity_id,
        'amount_input', p_amount,
        'exchange_rate', v_rate
      ),
      p_target_bucket => 'available',
      p_allow_overdraft => false
    );
  ELSIF p_action = 'use_credit' THEN
    -- Action: use_credit — debit payee available (strict check). Tenant unchanged.
    v_ledger := public.record_ledger_transaction(
      p_tenant_id => v_ship.parent_tenant_id,
      p_entity_type => p_entity_type,
      p_entity_id => p_entity_id,
      p_type => 'debit',
      p_amount => v_bdt_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'shipment',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object(
        'action', 'use_credit',
        'payee_type', p_entity_type,
        'payee_id', p_entity_id,
        'amount_input', p_amount,
        'exchange_rate', v_rate
      ),
      p_target_bucket => 'available',
      p_allow_overdraft => false
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'action', p_action,
    'amount_bdt', v_bdt_amount,
    'ledger', v_ledger
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.settle_shipment_payee(BIGINT, TEXT, BIGINT, TEXT, NUMERIC, NUMERIC) TO authenticated;


-- 3. Helper and list_shipment_payee_settlements RPC
CREATE OR REPLACE FUNCTION public.get_payee_settlement_summary(
  p_tenant_id BIGINT,
  p_shipment_id BIGINT,
  p_entity_type TEXT,
  p_entity_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_avail NUMERIC(18,4) := 0;
  v_paid NUMERIC(18,4) := 0;
  v_credited NUMERIC(18,4) := 0;
  v_used NUMERIC(18,4) := 0;
  v_events JSONB := '[]'::jsonb;
BEGIN
  IF p_entity_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT COALESCE(available_balance, 0) INTO v_avail
  FROM public.wallet_accounts
  WHERE tenant_id = p_tenant_id
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id
    AND currency_code = 'BDT';

  SELECT COALESCE(SUM(base_amount), 0) INTO v_paid
  FROM public.universal_wallet_ledger
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND metadata->>'action' = 'pay'
    AND metadata->>'payee_type' = p_entity_type
    AND (metadata->>'payee_id')::bigint = p_entity_id;

  SELECT COALESCE(SUM(base_amount), 0) INTO v_credited
  FROM public.universal_wallet_ledger
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND metadata->>'action' = 'record_credit'
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id;

  SELECT COALESCE(SUM(base_amount), 0) INTO v_used
  FROM public.universal_wallet_ledger
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND metadata->>'action' = 'use_credit'
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', id,
      'created_at', created_at,
      'type', type,
      'action', metadata->>'action',
      'amount_input', COALESCE((metadata->>'amount_input')::numeric, amount),
      'exchange_rate', COALESCE((metadata->>'exchange_rate')::numeric, exchange_rate),
      'base_amount', base_amount
    ) ORDER BY created_at DESC
  ), '[]'::jsonb) INTO v_events
  FROM public.universal_wallet_ledger
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND (
      (entity_type = p_entity_type AND entity_id = p_entity_id)
      OR
      (metadata->>'payee_type' = p_entity_type AND (metadata->>'payee_id')::bigint = p_entity_id)
    );

  RETURN jsonb_build_object(
    'entity_type', p_entity_type,
    'entity_id', p_entity_id,
    'available_bdt', v_avail,
    'paid_bdt', v_paid,
    'credited_bdt', v_credited,
    'used_bdt', v_used,
    'recent_events', v_events
  );
END;
$$;

DROP FUNCTION IF EXISTS public.list_shipment_payee_settlements(BIGINT);

CREATE OR REPLACE FUNCTION public.list_shipment_payee_settlements(
  p_shipment_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
BEGIN
  SELECT * INTO v_ship
  FROM public.global_shipments
  WHERE id = p_shipment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.has_active_tenant_membership(v_ship.parent_tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  RETURN jsonb_build_object(
    'vendor', public.get_payee_settlement_summary(v_ship.parent_tenant_id, p_shipment_id, 'vendor', v_ship.vendor_id),
    'cargo_company', public.get_payee_settlement_summary(v_ship.parent_tenant_id, p_shipment_id, 'cargo_company', v_ship.cargo_company_id)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_shipment_payee_settlements(BIGINT) TO authenticated;

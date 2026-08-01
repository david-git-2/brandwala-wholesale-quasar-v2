-- 20270203000000_create_wallet_accounts_and_rpcs.sql
-- Materialized 3-Bucket Wallet Accounts and Atomic PostgreSQL Accounting RPCs

CREATE TABLE IF NOT EXISTS wallet_accounts (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id         BIGINT NOT NULL REFERENCES tenants(id),
  entity_type       TEXT NOT NULL, -- 'tenant', 'customer', 'vendor', 'courier', 'middleman'
  entity_id         BIGINT NOT NULL,
  currency_code     TEXT NOT NULL DEFAULT 'BDT',
  
  -- Three-Bucket Financial Model
  available_balance NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  pending_balance   NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  locked_balance    NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  CONSTRAINT wallet_accounts_entity_currency_key UNIQUE (tenant_id, entity_type, entity_id, currency_code),
  CONSTRAINT wallet_accounts_available_non_negative CHECK (available_balance >= 0)
);

-- Index for fast balance lookups
CREATE INDEX IF NOT EXISTS idx_wallet_accounts_tenant_entity 
  ON wallet_accounts (tenant_id, entity_type, entity_id);

-- Enable RLS & Grants
ALTER TABLE wallet_accounts ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'wallet_accounts' AND policyname = 'wallet_accounts_authenticated_policy'
  ) THEN
    CREATE POLICY wallet_accounts_authenticated_policy ON wallet_accounts
      FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
END $$;

GRANT ALL ON wallet_accounts TO authenticated;
GRANT ALL ON wallet_accounts TO service_role;

-- =============================================================================
-- RPC 1: record_ledger_transaction
-- Record an immutable ledger entry and atomically update target wallet account bucket
-- =============================================================================
DROP FUNCTION IF EXISTS record_ledger_transaction(BIGINT, TEXT, BIGINT, TEXT, NUMERIC, TEXT, NUMERIC, TEXT, TEXT, JSONB);
DROP FUNCTION IF EXISTS record_ledger_transaction(BIGINT, TEXT, BIGINT, TEXT, NUMERIC, TEXT, NUMERIC, TEXT, TEXT, JSONB, TEXT);

CREATE OR REPLACE FUNCTION record_ledger_transaction(
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
  p_target_bucket TEXT DEFAULT 'available' -- 'available', 'pending', 'locked'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
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
  INSERT INTO wallet_accounts (tenant_id, entity_type, entity_id, currency_code, available_balance, pending_balance, locked_balance)
  VALUES (p_tenant_id, p_entity_type, p_entity_id, COALESCE(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000)
  ON CONFLICT (tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  -- Lock row FOR UPDATE
  SELECT available_balance, pending_balance, locked_balance
  INTO v_avail, v_pend, v_lock
  FROM wallet_accounts
  WHERE id = v_account_id
  FOR UPDATE;

  -- 2. Apply delta to target bucket
  IF p_target_bucket = 'available' THEN
    IF p_type = 'credit' THEN
      v_avail := v_avail + p_amount;
    ELSE
      IF v_avail < p_amount THEN
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
  UPDATE wallet_accounts
  SET 
    available_balance = v_avail,
    pending_balance = v_pend,
    locked_balance = v_lock,
    updated_at = now()
  WHERE id = v_account_id;

  -- 3. Insert into universal_wallet_ledger
  v_base_amount := p_amount * COALESCE(p_exchange_rate, 1.000000);

  INSERT INTO universal_wallet_ledger (
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
  FROM universal_wallet_ledger
  WHERE id = v_ledger_id;

  RETURN v_ledger_entry;
END;
$$;

-- =============================================================================
-- RPC 2: transfer_wallet_balance
-- Shift funds between buckets (pending -> available, available -> locked)
-- =============================================================================
DROP FUNCTION IF EXISTS transfer_wallet_balance(BIGINT, TEXT, BIGINT, TEXT, TEXT, NUMERIC, TEXT, TEXT, JSONB);

CREATE OR REPLACE FUNCTION transfer_wallet_balance(
  p_tenant_id BIGINT,
  p_entity_type TEXT,
  p_entity_id BIGINT,
  p_from_bucket TEXT, -- 'pending', 'available', 'locked'
  p_to_bucket TEXT,   -- 'pending', 'available', 'locked'
  p_amount NUMERIC(18,4),
  p_currency_code TEXT DEFAULT 'BDT',
  p_notes TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_account_id BIGINT;
  v_avail NUMERIC(18,4);
  v_pend NUMERIC(18,4);
  v_lock NUMERIC(18,4);
  v_result JSONB;
BEGIN
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transfer amount must be greater than zero.';
  END IF;

  IF p_from_bucket = p_to_bucket THEN
    RAISE EXCEPTION 'Source and target buckets cannot be identical.';
  END IF;

  IF p_from_bucket NOT IN ('available', 'pending', 'locked') OR p_to_bucket NOT IN ('available', 'pending', 'locked') THEN
    RAISE EXCEPTION 'Invalid bucket specifiers. Must be available, pending, or locked.';
  END IF;

  -- 1. Lock row
  INSERT INTO wallet_accounts (tenant_id, entity_type, entity_id, currency_code, available_balance, pending_balance, locked_balance)
  VALUES (p_tenant_id, p_entity_type, p_entity_id, COALESCE(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000)
  ON CONFLICT (tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  SELECT available_balance, pending_balance, locked_balance
  INTO v_avail, v_pend, v_lock
  FROM wallet_accounts
  WHERE id = v_account_id
  FOR UPDATE;

  -- 2. Deduct from source bucket
  IF p_from_bucket = 'pending' THEN
    IF v_pend < p_amount THEN
      RAISE EXCEPTION 'Insufficient pending balance (Pending: %, Requested: %).', v_pend, p_amount;
    END IF;
    v_pend := v_pend - p_amount;
  ELSIF p_from_bucket = 'available' THEN
    IF v_avail < p_amount THEN
      RAISE EXCEPTION 'Insufficient available balance (Available: %, Requested: %).', v_avail, p_amount;
    END IF;
    v_avail := v_avail - p_amount;
  ELSIF p_from_bucket = 'locked' THEN
    IF v_lock < p_amount THEN
      RAISE EXCEPTION 'Insufficient locked balance (Locked: %, Requested: %).', v_lock, p_amount;
    END IF;
    v_lock := v_lock - p_amount;
  END IF;

  -- 3. Add to target bucket
  IF p_to_bucket = 'pending' THEN
    v_pend := v_pend + p_amount;
  ELSIF p_to_bucket = 'available' THEN
    v_avail := v_avail + p_amount;
  ELSIF p_to_bucket = 'locked' THEN
    v_lock := v_lock + p_amount;
  END IF;

  UPDATE wallet_accounts
  SET 
    available_balance = v_avail,
    pending_balance = v_pend,
    locked_balance = v_lock,
    updated_at = now()
  WHERE id = v_account_id;

  -- 4. Record ledger transaction
  INSERT INTO universal_wallet_ledger (
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
    'credit',
    p_amount,
    COALESCE(p_currency_code, 'BDT'),
    1.000000,
    p_amount,
    v_avail,
    'bucket_transfer',
    NULL,
    COALESCE(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'from_bucket', p_from_bucket,
      'to_bucket', p_to_bucket,
      'notes', p_notes
    )
  );

  SELECT jsonb_build_object(
    'account_id', v_account_id,
    'tenant_id', p_tenant_id,
    'entity_type', p_entity_type,
    'entity_id', p_entity_id,
    'currency_code', COALESCE(p_currency_code, 'BDT'),
    'available_balance', v_avail,
    'pending_balance', v_pend,
    'locked_balance', v_lock
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- =============================================================================
-- RPC 3: get_wallet_account_balances
-- Fetch 3-bucket materialized balance for a specific entity
-- =============================================================================
DROP FUNCTION IF EXISTS get_wallet_account_balances(BIGINT, TEXT, BIGINT, TEXT);

CREATE OR REPLACE FUNCTION get_wallet_account_balances(
  p_tenant_id BIGINT,
  p_entity_type TEXT,
  p_entity_id BIGINT,
  p_currency_code TEXT DEFAULT 'BDT'
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'tenant_id', p_tenant_id,
    'entity_type', p_entity_type,
    'entity_id', p_entity_id,
    'currency_code', COALESCE(w.currency_code, p_currency_code),
    'available_balance', COALESCE(w.available_balance, 0.0000),
    'pending_balance', COALESCE(w.pending_balance, 0.0000),
    'locked_balance', COALESCE(w.locked_balance, 0.0000),
    'total_balance', (COALESCE(w.available_balance, 0.0000) + COALESCE(w.pending_balance, 0.0000) + COALESCE(w.locked_balance, 0.0000))
  )
  INTO v_result
  FROM (SELECT 1) dummy
  LEFT JOIN wallet_accounts w
    ON w.tenant_id = p_tenant_id
   AND w.entity_type = p_entity_type
   AND w.entity_id = p_entity_id
   AND w.currency_code = COALESCE(p_currency_code, 'BDT');

  RETURN v_result;
END;
$$;

-- =============================================================================
-- RPC 4: get_wallet_dashboard_summary
-- Aggregate financial metrics for platform dashboard
-- =============================================================================
DROP FUNCTION IF EXISTS get_wallet_dashboard_summary(BIGINT);

CREATE OR REPLACE FUNCTION get_wallet_dashboard_summary(
  p_tenant_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_tenant_cash NUMERIC(18,4) := 0.0000;
  v_courier_cod_holding NUMERIC(18,4) := 0.0000;
  v_merchant_pending NUMERIC(18,4) := 0.0000;
  v_merchant_available NUMERIC(18,4) := 0.0000;
  v_vendor_payables NUMERIC(18,4) := 0.0000;
  v_customer_deposits NUMERIC(18,4) := 0.0000;
BEGIN
  SELECT 
    COALESCE(SUM(CASE WHEN entity_type = 'tenant' THEN available_balance ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN entity_type = 'courier' THEN pending_balance + available_balance ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN entity_type IN ('customer', 'middleman') THEN pending_balance ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN entity_type IN ('customer', 'middleman') THEN available_balance ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN entity_type = 'vendor' THEN available_balance ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN entity_type = 'customer' THEN available_balance ELSE 0 END), 0)
  INTO 
    v_tenant_cash,
    v_courier_cod_holding,
    v_merchant_pending,
    v_merchant_available,
    v_vendor_payables,
    v_customer_deposits
  FROM wallet_accounts
  WHERE tenant_id = p_tenant_id;

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'tenant_cash_total', v_tenant_cash,
    'courier_cod_holding_total', v_courier_cod_holding,
    'merchant_pending_total', v_merchant_pending,
    'merchant_available_total', v_merchant_available,
    'vendor_payables_total', v_vendor_payables,
    'customer_deposits_total', v_customer_deposits
  );
END;
$$;

-- =============================================================================
-- RPC 5: get_wallet_entity_statement
-- Formatted date-ranged account statement
-- =============================================================================
DROP FUNCTION IF EXISTS get_wallet_entity_statement(BIGINT, TEXT, BIGINT, TIMESTAMPTZ, TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION get_wallet_entity_statement(
  p_tenant_id BIGINT,
  p_entity_type TEXT,
  p_entity_id BIGINT,
  p_start_date TIMESTAMPTZ DEFAULT NULL,
  p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_opening_balance NUMERIC(18,4) := 0.0000;
  v_total_credits NUMERIC(18,4) := 0.0000;
  v_total_debits NUMERIC(18,4) := 0.0000;
  v_closing_balance NUMERIC(18,4) := 0.0000;
  v_entries JSONB;
BEGIN
  IF p_start_date IS NOT NULL THEN
    SELECT COALESCE(
      SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount END),
      0.0000
    )
    INTO v_opening_balance
    FROM universal_wallet_ledger
    WHERE tenant_id = p_tenant_id
      AND entity_type = p_entity_type
      AND entity_id = p_entity_id
      AND created_at < p_start_date;
  END IF;

  SELECT 
    COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE 0 END), 0.0000),
    COALESCE(SUM(CASE WHEN type = 'debit' THEN amount ELSE 0 END), 0.0000)
  INTO v_total_credits, v_total_debits
  FROM universal_wallet_ledger
  WHERE tenant_id = p_tenant_id
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date);

  v_closing_balance := v_opening_balance + v_total_credits - v_total_debits;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
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
    ) ORDER BY created_at ASC, id ASC
  ), '[]'::jsonb)
  INTO v_entries
  FROM universal_wallet_ledger
  WHERE tenant_id = p_tenant_id
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date);

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'entity_type', p_entity_type,
    'entity_id', p_entity_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'opening_balance', v_opening_balance,
    'total_credits', v_total_credits,
    'total_debits', v_total_debits,
    'closing_balance', v_closing_balance,
    'entries', v_entries
  );
END;
$$;

GRANT EXECUTE ON FUNCTION record_ledger_transaction(BIGINT, TEXT, BIGINT, TEXT, NUMERIC, TEXT, NUMERIC, TEXT, TEXT, JSONB, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION transfer_wallet_balance(BIGINT, TEXT, BIGINT, TEXT, TEXT, NUMERIC, TEXT, TEXT, JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_wallet_account_balances(BIGINT, TEXT, BIGINT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_wallet_dashboard_summary(BIGINT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_wallet_entity_statement(BIGINT, TEXT, BIGINT, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;

-- Ledger entries may tag a cash point; deleting a point clears the tag then removes the row.

ALTER TABLE public.cashbook_entries
  DROP CONSTRAINT IF EXISTS cashbook_entries_cashbook_point_id_fkey;

ALTER TABLE public.cashbook_entries
  ADD CONSTRAINT cashbook_entries_cashbook_point_id_fkey
  FOREIGN KEY (cashbook_point_id) REFERENCES public.cashbook_points (id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.delete_cashbook_point_for_staff(
  p_tenant_id bigint,
  p_point_id bigint
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_point public.cashbook_points;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  IF NOT public.wallet_staff_can_edit(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  SELECT * INTO v_point
  FROM public.cashbook_points cp
  WHERE cp.id = p_point_id
    AND cp.parent_tenant_id = v_books_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'cash point not found');
  END IF;

  UPDATE public.cashbook_entries
  SET cashbook_point_id = NULL
  WHERE cashbook_point_id = p_point_id;

  DELETE FROM public.cashbook_points
  WHERE id = p_point_id;

  RETURN jsonb_build_object('success', true, 'id', p_point_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_cashbook_point_for_staff(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_cashbook_point_for_staff(bigint, bigint) TO service_role;

DROP FUNCTION IF EXISTS public.record_ledger_transaction(
  bigint, bigint, text, bigint, text, numeric, text, numeric, text, text, jsonb, text, boolean
);

CREATE OR REPLACE FUNCTION public.record_ledger_transaction(
  p_parent_tenant_id bigint,
  p_operating_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_type text,
  p_amount numeric,
  p_currency_code text DEFAULT 'BDT',
  p_exchange_rate numeric DEFAULT 1.000000,
  p_source_type text DEFAULT 'adjustment',
  p_source_id text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_target_bucket text DEFAULT 'available',
  p_allow_overdraft boolean DEFAULT false,
  p_cashbook_point_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
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
      IF v_avail < p_amount AND NOT coalesce(p_allow_overdraft, false) THEN
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

GRANT EXECUTE ON FUNCTION public.record_ledger_transaction(
  bigint, bigint, text, bigint, text, numeric, text, numeric, text, text, jsonb, text, boolean, bigint
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_ledger_transaction(
  bigint, bigint, text, bigint, text, numeric, text, numeric, text, text, jsonb, text, boolean, bigint
) TO service_role;

DROP FUNCTION IF EXISTS public.list_wallet_ledger_for_staff(
  bigint, text, bigint, text, bigint, integer, integer
);

CREATE OR REPLACE FUNCTION public.list_wallet_ledger_for_staff(
  p_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_search text DEFAULT NULL,
  p_operating_tenant_id bigint DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
) RETURNS TABLE(
  id uuid,
  parent_tenant_id bigint,
  operating_tenant_id bigint,
  entity_type text,
  entity_id bigint,
  type text,
  amount numeric,
  currency_code text,
  exchange_rate numeric,
  base_amount numeric,
  balance_after numeric,
  source_type text,
  source_id text,
  metadata jsonb,
  created_at timestamptz,
  is_reversal boolean,
  reversed_entry_id uuid,
  cashbook_point_id bigint,
  cashbook_point_name text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
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
    CASE WHEN l.metadata ? 'reversal_of' THEN (l.metadata->>'reversal_of')::uuid ELSE NULL END,
    l.cashbook_point_id,
    cp.name
  FROM public.cashbook_entries l
  LEFT JOIN public.cashbook_points cp ON cp.id = l.cashbook_point_id
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
      OR coalesce(cp.name, '') ILIKE '%' || v_search || '%'
    )
  ORDER BY l.created_at DESC, l.id DESC
  LIMIT greatest(least(coalesce(p_limit, 50), 200), 1)
  OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_wallet_ledger_for_staff(
  bigint, text, bigint, text, bigint, integer, integer
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_wallet_ledger_for_staff(
  bigint, text, bigint, text, bigint, integer, integer
) TO service_role;

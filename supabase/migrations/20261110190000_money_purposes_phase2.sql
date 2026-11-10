-- BP27 money purposes phase 2-3
-- BP27–BP29: money purpose registry + pay/bill plug columns + tenant deposit/withdraw.

ALTER TYPE public.profile_party_type ADD VALUE IF NOT EXISTS 'staff';

CREATE TABLE IF NOT EXISTS public.money_purposes (
  code text PRIMARY KEY,
  direction text NOT NULL CHECK (direction IN ('in', 'out')),
  party_rule text NOT NULL CHECK (party_rule IN ('required', 'none', 'optional')),
  allowed_profile_types public.profile_party_type[],
  custody_effect text NOT NULL CHECK (custody_effect IN ('credit', 'debit', 'none')),
  group_code text NOT NULL,
  module_key text NOT NULL DEFAULT 'bills_pays',
  label text NOT NULL,
  legacy_source text,
  is_active boolean NOT NULL DEFAULT true
);

ALTER TABLE public.money_purposes ENABLE ROW LEVEL SECURITY;

CREATE POLICY money_purposes_read ON public.money_purposes
  FOR SELECT TO authenticated USING (true);

GRANT SELECT ON public.money_purposes TO authenticated;
GRANT ALL ON public.money_purposes TO service_role;

INSERT INTO public.money_purposes (code, direction, party_rule, allowed_profile_types, custody_effect, group_code, module_key, label, legacy_source)
VALUES
  ('customer_collect', 'in', 'required', ARRAY['customer']::public.profile_party_type[], 'credit', 'sales', 'bills_pays', 'Customer payment', 'customer_cash'),
  ('bank_collect', 'in', 'required', NULL, 'credit', 'sales', 'bills_pays', 'Bank collect', 'bank'),
  ('store_credit', 'in', 'required', NULL, 'credit', 'sales', 'bills_pays', 'Store credit', 'store_credit'),
  ('courier_remittance', 'in', 'optional', ARRAY['courier']::public.profile_party_type[], 'credit', 'sales', 'bills_pays', 'Courier remittance', 'courier_remittance'),
  ('ap_payout', 'out', 'required', ARRAY['vendor', 'courier']::public.profile_party_type[], 'none', 'purchase', 'bills_pays', 'AP payout', 'ap_payout'),
  ('commission', 'out', 'required', ARRAY['customer']::public.profile_party_type[], 'debit', 'sales', 'bills_pays', 'Commission / profit payout', 'commission'),
  ('advance', 'in', 'optional', NULL, 'credit', 'sales', 'bills_pays', 'Advance / unallocated pay in', 'customer_cash'),
  ('courier_payout', 'out', 'required', ARRAY['courier']::public.profile_party_type[], 'debit', 'purchase', 'bills_pays', 'Pay courier', 'ap_payout'),
  ('vendor_refund', 'in', 'required', ARRAY['vendor']::public.profile_party_type[], 'none', 'purchase', 'bills_pays', 'Vendor refund', 'bank'),
  ('deposit', 'in', 'none', NULL, 'none', 'owner', 'bills_pays', 'Owner deposit', 'deposit'),
  ('owner_withdraw', 'out', 'none', NULL, 'none', 'owner', 'bills_pays', 'Owner withdraw', 'owner_withdraw'),
  ('capital_in', 'in', 'required', ARRAY['investor']::public.profile_party_type[], 'credit', 'capital', 'investor_capital', 'Capital in', 'bank'),
  ('capital_out', 'out', 'required', ARRAY['investor']::public.profile_party_type[], 'debit', 'capital', 'investor_capital', 'Capital withdraw', 'ap_payout'),
  ('salary', 'out', 'optional', NULL, 'none', 'expense', 'bills_pays', 'Salary expense', 'ap_payout'),
  ('rent', 'out', 'optional', NULL, 'none', 'expense', 'bills_pays', 'Rent expense', 'ap_payout'),
  ('utilities', 'out', 'optional', NULL, 'none', 'expense', 'bills_pays', 'Utilities expense', 'ap_payout'),
  ('transport', 'out', 'optional', NULL, 'none', 'expense', 'bills_pays', 'Transport expense', 'ap_payout'),
  ('marketing', 'out', 'optional', NULL, 'none', 'expense', 'bills_pays', 'Marketing expense', 'ap_payout')
ON CONFLICT (code) DO UPDATE SET
  direction = EXCLUDED.direction,
  party_rule = EXCLUDED.party_rule,
  allowed_profile_types = EXCLUDED.allowed_profile_types,
  custody_effect = EXCLUDED.custody_effect,
  group_code = EXCLUDED.group_code,
  module_key = EXCLUDED.module_key,
  label = EXCLUDED.label,
  legacy_source = EXCLUDED.legacy_source,
  is_active = EXCLUDED.is_active;

ALTER TABLE public.pays
  ADD COLUMN IF NOT EXISTS purpose_code text REFERENCES public.money_purposes (code),
  ADD COLUMN IF NOT EXISTS source_type text,
  ADD COLUMN IF NOT EXISTS source_id text,
  ADD COLUMN IF NOT EXISTS counterparty_name text;

ALTER TABLE public.bills
  ADD COLUMN IF NOT EXISTS purpose_code text REFERENCES public.money_purposes (code);

CREATE INDEX IF NOT EXISTS pays_tenant_source_idx
  ON public.pays (tenant_id, source_type, source_id)
  WHERE source_type IS NOT NULL AND btrim(source_type) <> '';

UPDATE public.pays py
SET purpose_code = mp.code
FROM public.money_purposes mp
WHERE py.purpose_code IS NULL
  AND mp.legacy_source IS NOT NULL
  AND py.source = mp.legacy_source;

ALTER TABLE public.pays DROP CONSTRAINT IF EXISTS pays_source_check;
ALTER TABLE public.pays ADD CONSTRAINT pays_source_check CHECK (
  source = ANY (ARRAY[
    'customer_cash'::text,
    'bank'::text,
    'store_credit'::text,
    'courier_remittance'::text,
    'ap_payout'::text,
    'commission'::text,
    'deposit'::text,
    'owner_withdraw'::text
  ])
);

CREATE OR REPLACE FUNCTION public._kernel_purpose_from_source(p_source text)
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT mp.code
  FROM public.money_purposes mp
  WHERE mp.legacy_source = p_source
  ORDER BY mp.code
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public._kernel_assert_purpose(
  p_purpose_code text,
  p_profile_id bigint,
  p_profile_type public.profile_party_type DEFAULT NULL
) RETURNS public.money_purposes
LANGUAGE plpgsql
STABLE
SET search_path TO public
AS $$
DECLARE
  v_purpose public.money_purposes;
BEGIN
  IF p_purpose_code IS NULL OR btrim(p_purpose_code) = '' THEN
    RAISE EXCEPTION 'purpose_code is required';
  END IF;

  SELECT * INTO v_purpose
  FROM public.money_purposes mp
  WHERE mp.code = p_purpose_code AND mp.is_active;

  IF v_purpose.code IS NULL THEN
    RAISE EXCEPTION 'Unknown purpose %', p_purpose_code;
  END IF;

  IF v_purpose.party_rule = 'required' AND p_profile_id IS NULL THEN
    RAISE EXCEPTION 'Purpose % requires a profile', p_purpose_code;
  END IF;

  IF v_purpose.party_rule = 'none' AND p_profile_id IS NOT NULL THEN
    RAISE EXCEPTION 'Purpose % does not allow a profile', p_purpose_code;
  END IF;

  IF v_purpose.allowed_profile_types IS NOT NULL
     AND p_profile_type IS NOT NULL
     AND NOT (p_profile_type = ANY (v_purpose.allowed_profile_types)) THEN
    RAISE EXCEPTION 'Purpose % not allowed for profile type %', p_purpose_code, p_profile_type;
  END IF;

  RETURN v_purpose;
END;
$$;

CREATE OR REPLACE FUNCTION public._kernel_post_tenant_deposit(
  p_tenant_id bigint,
  p_received_on date,
  p_amount numeric,
  p_cashbook_point_id bigint,
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_pay public.pays;
  v_existing public.pays;
BEGIN
  IF NOT (
    public.cashbook_staff_can_view(p_tenant_id)
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'create')
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;
  PERFORM public._kernel_assert_purpose('deposit', NULL, NULL)::public.money_purposes;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'amount must be positive';
  END IF;
  IF p_cashbook_point_id IS NULL THEN
    RAISE EXCEPTION 'cashbook_point_id required';
  END IF;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);

  IF p_idempotency_key IS NOT NULL AND btrim(p_idempotency_key) <> '' THEN
    SELECT * INTO v_existing
    FROM public.pays
    WHERE tenant_id = v_books_id AND idempotency_key = p_idempotency_key;
    IF v_existing.id IS NOT NULL THEN
      RETURN v_existing;
    END IF;
  END IF;

  PERFORM public._kernel_lock_cashbook_point_pots(p_cashbook_point_id);

  INSERT INTO public.pays (
    tenant_id, profile_id, source, purpose_code, amount, unallocated_amount,
    payment_date, method, reference, note, cashbook_point_id, idempotency_key
  ) VALUES (
    v_books_id, NULL, 'deposit', 'deposit', p_amount, 0,
    coalesce(p_received_on, current_date), 'cash', p_reference, p_note,
    p_cashbook_point_id, p_idempotency_key
  ) RETURNING * INTO v_pay;

  PERFORM public.record_ledger_transaction(
    p_tenant_id => v_books_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_books_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1,
    p_source_type => 'pay',
    p_source_id => v_pay.id::text,
    p_metadata => jsonb_build_object('purpose', 'deposit'),
    p_target_bucket => 'available',
    p_allow_overdraft => false,
    p_cashbook_point_id => p_cashbook_point_id
  );

  RETURN v_pay;
END;
$$;

CREATE OR REPLACE FUNCTION public._kernel_post_owner_withdraw(
  p_tenant_id bigint,
  p_paid_on date,
  p_amount numeric,
  p_cashbook_point_id bigint,
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_pay public.pays;
  v_existing public.pays;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'payments', 'create');
  PERFORM public._kernel_assert_purpose('owner_withdraw', NULL, NULL)::public.money_purposes;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'amount must be positive';
  END IF;
  IF p_cashbook_point_id IS NULL THEN
    RAISE EXCEPTION 'cashbook_point_id required';
  END IF;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);

  IF p_idempotency_key IS NOT NULL AND btrim(p_idempotency_key) <> '' THEN
    SELECT * INTO v_existing
    FROM public.pays
    WHERE tenant_id = v_books_id AND idempotency_key = p_idempotency_key;
    IF v_existing.id IS NOT NULL THEN
      RETURN v_existing;
    END IF;
  END IF;

  PERFORM public._kernel_lock_cashbook_point_pots(p_cashbook_point_id);

  INSERT INTO public.pays (
    tenant_id, profile_id, source, purpose_code, amount, unallocated_amount,
    payment_date, method, reference, note, cashbook_point_id, idempotency_key
  ) VALUES (
    v_books_id, NULL, 'owner_withdraw', 'owner_withdraw', p_amount, 0,
    coalesce(p_paid_on, current_date), 'cash', p_reference, p_note,
    p_cashbook_point_id, p_idempotency_key
  ) RETURNING * INTO v_pay;

  PERFORM public.record_ledger_transaction(
    p_tenant_id => v_books_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_books_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1,
    p_source_type => 'pay',
    p_source_id => v_pay.id::text,
    p_metadata => jsonb_build_object('purpose', 'owner_withdraw'),
    p_target_bucket => 'available',
    p_allow_overdraft => false,
    p_cashbook_point_id => p_cashbook_point_id
  );

  RETURN v_pay;
END;
$$;

-- Extend post_money_in with purpose routing (new overload-compatible replace).
CREATE OR REPLACE FUNCTION public.post_money_in(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_received_on date,
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_source text DEFAULT 'customer_cash',
  p_instruments jsonb DEFAULT '[]'::jsonb,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_shop_order_id bigint DEFAULT NULL,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL,
  p_source_currency_code text DEFAULT NULL,
  p_transaction_rate numeric DEFAULT NULL,
  p_purpose_code text DEFAULT NULL,
  p_source_type text DEFAULT NULL,
  p_source_id text DEFAULT NULL,
  p_counterparty_name text DEFAULT NULL,
  p_amount numeric DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_pay public.pays;
  v_purpose text := coalesce(nullif(btrim(p_purpose_code), ''), public._kernel_purpose_from_source(p_source));
BEGIN
  IF v_purpose = 'deposit' THEN
  RETURN public._kernel_post_tenant_deposit(
      p_tenant_id,
      p_received_on,
      coalesce(p_amount, (p_instruments -> 0 ->> 'amount')::numeric, 0),
      p_cashbook_point_id,
      p_note,
      p_reference,
      p_idempotency_key
    );
  END IF;

  v_pay := public.post_customer_receipt_with_allocations(
    p_tenant_id,
    p_profile_id,
    p_received_on,
    p_note,
    p_reference,
    p_source,
    p_instruments,
    p_allocations,
    p_shop_order_id,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    true,
    p_idempotency_key,
    p_cashbook_point_id,
    p_cashbook_point_pot_id,
    p_source_currency_code,
    p_transaction_rate
  );

  UPDATE public.pays
  SET
    purpose_code = coalesce(v_purpose, purpose_code),
    source_type = coalesce(p_source_type, source_type),
    source_id = coalesce(p_source_id, source_id),
    counterparty_name = coalesce(p_counterparty_name, counterparty_name)
  WHERE id = v_pay.id;

  SELECT * INTO v_pay FROM public.pays WHERE id = v_pay.id;
  RETURN v_pay;
END;
$$;

CREATE OR REPLACE FUNCTION public.post_money_out(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_paid_on date,
  p_amount numeric,
  p_source text DEFAULT 'ap_payout',
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_instruments jsonb DEFAULT '[]'::jsonb,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_source_type text DEFAULT NULL,
  p_source_id text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL,
  p_payout_method text DEFAULT 'bank_transfer',
  p_purpose_code text DEFAULT NULL,
  p_counterparty_name text DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_pay public.pays;
  v_purpose text := coalesce(nullif(btrim(p_purpose_code), ''), public._kernel_purpose_from_source(p_source));
BEGIN
  IF v_purpose = 'owner_withdraw' THEN
    RETURN public._kernel_post_owner_withdraw(
      p_tenant_id,
      p_paid_on,
      p_amount,
      p_cashbook_point_id,
      p_note,
      p_reference,
      p_idempotency_key
    );
  END IF;

  IF coalesce(p_source_type, '') = 'commission' OR p_source = 'commission' THEN
    v_pay := public._kernel_post_commission_payout(
      p_tenant_id,
      p_profile_id,
      p_paid_on,
      p_amount,
      p_note,
      p_reference,
      p_payout_method,
      p_cashbook_point_id,
      p_cashbook_point_pot_id,
      p_source_id,
      p_idempotency_key
    );
  ELSE
    IF p_cashbook_point_id IS NULL THEN
      RAISE EXCEPTION 'cashbook_point_id required for pay out';
    END IF;

    v_pay := public.post_ap_payout_with_allocations(
      p_tenant_id,
      p_profile_id,
      p_paid_on,
      p_cashbook_point_id,
      p_note,
      p_reference,
      p_instruments,
      p_allocations,
      p_settlement_currency_code,
      p_foreign_amount,
      p_exchange_rate,
      null,
      null,
      null,
      p_idempotency_key
    );
  END IF;

  UPDATE public.pays
  SET
    purpose_code = coalesce(v_purpose, purpose_code),
    source_type = coalesce(p_source_type, source_type),
    source_id = coalesce(p_source_id, source_id),
    counterparty_name = coalesce(p_counterparty_name, counterparty_name)
  WHERE id = v_pay.id;

  SELECT * INTO v_pay FROM public.pays WHERE id = v_pay.id;
  RETURN v_pay;
END;
$$;

GRANT EXECUTE ON FUNCTION public._kernel_post_tenant_deposit TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._kernel_post_owner_withdraw TO authenticated, service_role;

-- Payments profile page: one round-trip for header, due, ledger, and pays.
-- Profile activity list (BP26): two-sided pay reads.

CREATE OR REPLACE FUNCTION public._kernel_pay_direction_tenant(p_source text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_source = ANY (ARRAY[
      'customer_cash'::text,
      'bank'::text,
      'store_credit'::text,
      'courier_remittance'::text
    ]) THEN 'in'
    WHEN p_source = ANY (ARRAY['ap_payout'::text, 'commission'::text, 'owner_withdraw'::text]) THEN 'out'
    WHEN p_source = 'deposit'::text THEN 'in'
    ELSE 'in'
  END;
$$;

CREATE OR REPLACE FUNCTION public._kernel_pay_direction_party(
  p_source text,
  p_entity_type text
) RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN public._kernel_pay_direction_tenant(p_source) = 'in' THEN 'out'
    ELSE 'in'
  END;
$$;

CREATE OR REPLACE FUNCTION public._kernel_pay_row_json(
  py public.pays,
  p_direction text,
  p_counterparty_name text DEFAULT NULL,
  p_perspective text DEFAULT 'party'
) RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
    'id', py.id,
    'payment_date', py.payment_date,
    'amount', py.amount,
    'unallocated_amount', coalesce(py.unallocated_amount, 0),
    'source', py.source,
    'direction', p_direction,
    'method', py.method,
    'reference', py.reference,
    'note', py.note,
    'voided_at', py.voided_at,
    'profile_id', py.profile_id,
    'profile_name', (SELECT pr.name FROM public.profiles pr WHERE pr.id = py.profile_id),
    'counterparty_name', coalesce(
      nullif(btrim(p_counterparty_name), ''),
      (SELECT pr.name FROM public.profiles pr WHERE pr.id = py.profile_id)
    ),
    'shop_order_id', py.shop_order_id,
    'settlement_currency_code', coalesce(py.settlement_currency_code, 'BDT'),
    'foreign_amount', py.foreign_amount,
    'exchange_rate', coalesce(py.exchange_rate, 1),
    'cashbook_point_id', py.cashbook_point_id,
    'cashbook_point_name', (
      SELECT cp.name FROM public.cashbook_points cp WHERE cp.id = py.cashbook_point_id
    ),
    'perspective', p_perspective
  );
$$;

CREATE OR REPLACE FUNCTION public.get_payment_profile_for_staff(
  p_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_currency_code text DEFAULT 'BDT'::text,
  p_ledger_limit integer DEFAULT 50,
  p_pays_limit integer DEFAULT 50
) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO public
    AS $$
DECLARE
  v_books_id bigint;
  v_detail jsonb;
  v_ledger_entity_id bigint;
  v_ledger jsonb := '[]'::jsonb;
  v_pays jsonb := '[]'::jsonb;
  v_due_total numeric(18, 4) := 0;
  v_ledger_lim integer;
  v_pays_lim integer;
BEGIN
  IF p_entity_type NOT IN ('tenant', 'customer', 'vendor', 'courier', 'investor') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid entity_type');
  END IF;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);

  IF NOT (
    public.cashbook_staff_can_view(p_tenant_id)
    OR public.membership_has_module_action(v_books_id, 'payments', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'view')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  v_detail := public.get_cashbook_detail_for_staff(
    p_tenant_id, p_entity_type, p_entity_id, p_currency_code
  );
  IF coalesce((v_detail->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN v_detail;
  END IF;

  v_ledger_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_ledger_entity_id := v_books_id;
  END IF;

  v_ledger_lim := greatest(least(coalesce(p_ledger_limit, 50), 200), 1);
  v_pays_lim := greatest(least(coalesce(p_pays_limit, 50), 200), 1);

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_created DESC, sort_id DESC), '[]'::jsonb)
  INTO v_ledger
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
    ORDER BY l.created_at DESC, l.id DESC
    LIMIT v_ledger_lim
  ) ledger_rows;

  IF p_entity_type <> 'tenant' THEN
    SELECT coalesce(sum(b.due_amount), 0::numeric)
    INTO v_due_total
    FROM public.bills b
    WHERE b.tenant_id = v_books_id
      AND b.profile_id = p_entity_id
      AND b.invoice_status = 'issued'
      AND coalesce(b.payment_status, '') <> 'paid';
  END IF;

  IF p_entity_type = 'tenant' THEN
    SELECT coalesce(jsonb_agg(row_data ORDER BY sort_payment_date DESC, sort_id DESC), '[]'::jsonb)
    INTO v_pays
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
      ORDER BY py.payment_date DESC, py.id DESC
      LIMIT v_pays_lim
    ) pay_rows;

  ELSIF p_entity_type IN ('customer', 'vendor', 'courier', 'investor') THEN
    SELECT coalesce(jsonb_agg(row_data ORDER BY sort_payment_date DESC, sort_id DESC), '[]'::jsonb)
    INTO v_pays
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
        AND py.profile_id = p_entity_id
        AND py.voided_at IS NULL
      ORDER BY py.payment_date DESC, py.id DESC
      LIMIT v_pays_lim
    ) pay_rows;
  END IF;

  RETURN v_detail
    || jsonb_build_object(
      'due_total', v_due_total,
      'ledger', v_ledger,
      'pays', v_pays
    );
END;
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
BEGIN
  IF p_kind NOT IN ('payments', 'custody', 'bills') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid kind');
  END IF;

  IF p_entity_type NOT IN ('tenant', 'customer', 'vendor', 'courier', 'investor') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid entity_type');
  END IF;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);

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

    IF p_entity_type = 'tenant' THEN
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
          AND py.profile_id = p_entity_id
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
              s.profile_id = p_entity_id
              OR s.from_profile_id = p_entity_id
              OR s.to_profile_id = p_entity_id
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

GRANT EXECUTE ON FUNCTION public.get_payment_profile_for_staff(
  bigint, text, bigint, text, integer, integer
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.get_payment_profile_for_staff(
  bigint, text, bigint, text, integer, integer
) TO service_role;

GRANT EXECUTE ON FUNCTION public.list_profile_activity_for_staff(
  bigint, text, bigint, text, integer, text
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.list_profile_activity_for_staff(
  bigint, text, bigint, text, integer, text
) TO service_role;

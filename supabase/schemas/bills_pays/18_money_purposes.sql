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
  IF NOT (
    public.cashbook_staff_can_view(p_tenant_id)
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'create')
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;
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
    p_allow_overdraft => true,
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

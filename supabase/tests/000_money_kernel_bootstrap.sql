-- Install pgTAP money kernel helpers (runs first alphabetically)

CREATE OR REPLACE FUNCTION public._test_pgtap_auth()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth
AS $$
BEGIN
  PERFORM set_config(
    'request.jwt.claims',
    '{"email":"pgtap+money@kernel.test","sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._test_money_kernel_bootstrap()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
  v_slug text := 'pgtap-' || substr(md5(random()::text), 1, 10);
  v_tenant_id bigint;
  v_customer_subject bigint;
  v_customer_profile_id bigint;
  v_tenant_profile_id bigint;
  v_account_id bigint;
  v_point_id bigint;
  v_pot_id bigint;
BEGIN
  ALTER TABLE public.tenants DISABLE TRIGGER USER;

  INSERT INTO public.tenants (name, slug, is_active, parent_id)
  VALUES ('pgTAP Money Kernel', v_slug, true, NULL)
  RETURNING id INTO v_tenant_id;

  ALTER TABLE public.tenants ENABLE TRIGGER USER;

  INSERT INTO public.memberships (tenant_id, role, is_active, email)
  VALUES (v_tenant_id, 'owner'::public.app_role, true, 'pgtap+money@kernel.test');

  PERFORM public._test_pgtap_auth();

  INSERT INTO public.payment_methods (code, name, category, scope, is_active, sort_order)
  VALUES ('CASH', 'Cash', 'bd_cash', 'bd', true, 0)
  ON CONFLICT (code) DO UPDATE SET is_active = true;

  INSERT INTO public.payment_methods (code, name, category, scope, is_active, sort_order)
  VALUES ('BANK', 'Bank', 'bd_bank', 'bd', true, 1)
  ON CONFLICT (code) DO UPDATE SET is_active = true;

  v_customer_subject := v_tenant_id * 1000 + 7;
  v_customer_profile_id := public.upsert_profile_for_party(
    v_tenant_id,
    'customer'::public.profile_party_type,
    v_customer_subject,
    'pgTAP Customer',
    NULL,
    NULL,
    '+880',
    NULL,
    false,
    NULL,
    true,
    NULL
  );

  v_tenant_profile_id := public.upsert_profile_for_party(
    v_tenant_id,
    'tenant'::public.profile_party_type,
    v_tenant_id,
    'pgTAP Tenant Book',
    NULL,
    NULL,
    '+880',
    NULL,
    false,
    NULL,
    true,
    NULL
  );

  INSERT INTO public.cashbook_accounts (
    tenant_id, parent_tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance, account_class
  )
  VALUES (
    v_tenant_id, v_tenant_id, 'tenant', v_tenant_id, 'BDT',
    0, 0, 0, 'tenant_asset'::public.cashbook_account_class
  )
  ON CONFLICT (parent_tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id INTO v_account_id;

  INSERT INTO public.cashbook_points (
    parent_tenant_id, cashbook_account_id, code, name, kind, is_active, sort_order
  )
  VALUES (
    v_tenant_id, v_account_id, 'TILL1', 'pgTAP Till', 'drawer'::public.cashbook_point_kind, true, 0
  )
  RETURNING id INTO v_point_id;

  v_pot_id := public._kernel_ensure_cashbook_point_pot(v_tenant_id, v_point_id, 'BDT');

  RETURN jsonb_build_object(
    'tenant_id', v_tenant_id,
    'parent_tenant_id', v_tenant_id,
    'customer_profile_id', v_customer_profile_id,
    'tenant_profile_id', v_tenant_profile_id,
    'cashbook_account_id', v_account_id,
    'cashbook_point_id', v_point_id,
    'cashbook_point_pot_id', v_pot_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._test_issue_ar_bill(
  p_tenant_id bigint,
  p_customer_profile_id bigint,
  p_amount numeric,
  p_invoice_no text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_bill public.bills;
  v_no text := coalesce(nullif(trim(p_invoice_no), ''), 'PGTAP-' || substr(md5(random()::text), 1, 8));
  v_amt numeric(12, 2) := round(coalesce(p_amount, 0), 2);
BEGIN
  PERFORM public._test_pgtap_auth();

  IF v_amt <= 0 THEN
    RAISE EXCEPTION 'amount must be positive';
  END IF;

  v_bill := public.create_sales_invoice(
    p_tenant_id,
    v_no,
    'wholesale'::public.global_invoice_type,
    p_customer_profile_id
  );

  INSERT INTO public.bill_lines (
    parent_tenant_id,
    invoice_id,
    line_kind,
    name_snapshot,
    quantity,
    sell_price_amount,
    line_discount_amount,
    line_total_amount
  )
  VALUES (
    v_bill.parent_tenant_id,
    v_bill.id,
    'description',
    'pgTAP line',
    1,
    v_amt,
    0,
    v_amt
  );

  UPDATE public.bills
  SET
    subtotal_amount = v_amt,
    total_amount = v_amt,
    due_amount = v_amt,
    channel_meta = coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('delivery_kind', 'take'),
    settlement_kind = 'take'::public.bill_settlement_kind,
    updated_at = now()
  WHERE id = v_bill.id;

  PERFORM public.stamp_bill_kernel_fields(v_bill.id);
  PERFORM public.issue_bill(v_bill.id);

  RETURN v_bill.id;
END;
$$;

CREATE OR REPLACE FUNCTION public._test_fund_cashbook_pot(
  p_tenant_id bigint,
  p_point_id bigint,
  p_amount numeric,
  p_currency_code text DEFAULT 'BDT'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_parent_id bigint := public.resolve_parent_tenant_id(p_tenant_id);
  v_pot_id bigint;
  v_amt numeric(12, 2) := round(coalesce(p_amount, 0), 2);
BEGIN
  IF v_amt <= 0 THEN
    RETURN;
  END IF;
  v_pot_id := public._kernel_ensure_cashbook_point_pot(v_parent_id, p_point_id, upper(p_currency_code));
  PERFORM public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_parent_id,
    p_type => 'credit',
    p_amount => v_amt,
    p_currency_code => upper(p_currency_code),
    p_exchange_rate => 1.000000,
    p_source_type => 'pgtap_seed',
    p_source_id => gen_random_uuid()::text,
    p_metadata => jsonb_build_object(
      'section', 'cashbook',
      'purpose', 'pgtap_fund',
      'cashbook_point_pot_id', v_pot_id
    ),
    p_cashbook_point_id => p_point_id
  );
END;
$$;

BEGIN;
SELECT plan(3);

SELECT has_function('public', '_test_money_kernel_bootstrap', ARRAY[]::text[]);
SELECT has_function('public', '_test_issue_ar_bill', ARRAY['bigint', 'bigint', 'numeric', 'text']);
SELECT has_function('public', '_test_fund_cashbook_pot', ARRAY['bigint', 'bigint', 'numeric', 'text']);

SELECT finish();
ROLLBACK;

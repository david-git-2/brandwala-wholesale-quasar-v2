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
    tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance,
    account_class
  )
  VALUES (
    v_tenant_id, 'tenant', v_tenant_id, 'BDT',
    0, 0, 0,
    'tenant_asset'::public.cashbook_account_class
  )
  ON CONFLICT (tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id INTO v_account_id;

  INSERT INTO public.cashbook_points (
    tenant_id, cashbook_account_id, code, name, is_active
  )
  VALUES (
    v_tenant_id, v_account_id, 'TILL1', 'pgTAP Till', true
  )
  RETURNING id INTO v_point_id;

  v_pot_id := public._kernel_ensure_cashbook_point_pot(v_tenant_id, v_point_id, 'BDT');

  RETURN jsonb_build_object(
    'tenant_id', v_tenant_id,
    'customer_profile_id', v_customer_profile_id,
    'tenant_profile_id', v_tenant_profile_id,
    'cashbook_account_id', v_account_id,
    'cashbook_point_id', v_point_id,
    'cashbook_point_pot_id', v_pot_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._test_kernel_service_role()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
END;
$$;

CREATE OR REPLACE FUNCTION public._test_set_workspace_tenant(p_tenant_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  PERFORM set_config(
    'request.headers',
    json_build_object('x-selected-tenant-id', p_tenant_id::text)::text,
    true
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
SET search_path TO money_kernel, public, pg_temp
AS $$
DECLARE
  v_no text := coalesce(nullif(trim(p_invoice_no), ''), 'PGTAP-' || substr(md5(random()::text), 1, 8));
  v_amt numeric(12, 2) := round(coalesce(p_amount, 0), 2);
  v_books bigint;
  v_self bigint;
  v_rpc jsonb;
  v_bill_id bigint;
BEGIN
  PERFORM public._test_pgtap_auth();
  PERFORM public._test_set_workspace_tenant(p_tenant_id);

  IF v_amt <= 0 THEN
    RAISE EXCEPTION 'amount must be positive';
  END IF;

  v_books := public.resolve_books_tenant_id(p_tenant_id);
  v_self := public._kernel_tenant_mirror_profile_id(v_books);
  IF v_self IS NULL THEN
    RAISE EXCEPTION 'tenant billing profile missing';
  END IF;

  v_rpc := public.rpc_create_bill(jsonb_build_object(
    'tenant_id', v_books,
    'kind', 'sales_invoice_wholesale',
    'currency_code', 'BDT',
    'from_profile_id', p_customer_profile_id,
    'to_profile_id', v_self,
    'counterparty_profile_id', p_customer_profile_id,
    'note', v_no,
    'auto_issue', true,
    'meta', jsonb_build_object(
      'delivery_kind', 'take',
      'subtotal_amount', v_amt,
      'requested_invoice_no', v_no
    ),
    'lines', jsonb_build_array(jsonb_build_object(
      'item_kind', 'charge',
      'description', 'pgTAP line',
      'quantity', 1,
      'unit_price', v_amt,
      'line_total', v_amt
    ))
  ));

  v_bill_id := nullif(v_rpc->>'bill_id', '')::bigint;
  IF v_bill_id IS NULL THEN
    RAISE EXCEPTION 'kernel AR create failed: %', v_rpc;
  END IF;

  RETURN v_bill_id;
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
      p_tenant_id => v_parent_id,
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

DROP FUNCTION IF EXISTS public._test_bootstrap_shipment_ap_fx(bigint);

REVOKE ALL ON FUNCTION public._test_pgtap_auth() FROM PUBLIC;
REVOKE ALL ON FUNCTION public._test_pgtap_auth() FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._test_pgtap_auth() TO postgres, service_role;

REVOKE ALL ON FUNCTION public._test_money_kernel_bootstrap() FROM PUBLIC;
REVOKE ALL ON FUNCTION public._test_money_kernel_bootstrap() FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._test_money_kernel_bootstrap() TO postgres, service_role;

REVOKE ALL ON FUNCTION public._test_kernel_service_role() FROM PUBLIC;
REVOKE ALL ON FUNCTION public._test_kernel_service_role() FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._test_kernel_service_role() TO postgres, service_role;

REVOKE ALL ON FUNCTION public._test_set_workspace_tenant(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._test_set_workspace_tenant(bigint) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._test_set_workspace_tenant(bigint) TO postgres, service_role;

REVOKE ALL ON FUNCTION public._test_issue_ar_bill(bigint, bigint, numeric, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._test_issue_ar_bill(bigint, bigint, numeric, text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._test_issue_ar_bill(bigint, bigint, numeric, text) TO postgres, service_role;

REVOKE ALL ON FUNCTION public._test_fund_cashbook_pot(bigint, bigint, numeric, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._test_fund_cashbook_pot(bigint, bigint, numeric, text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._test_fund_cashbook_pot(bigint, bigint, numeric, text) TO postgres, service_role;

BEGIN;
SELECT plan(5);

SELECT has_function('public', '_test_money_kernel_bootstrap', ARRAY[]::text[]);
SELECT has_function('public', '_test_issue_ar_bill', ARRAY['bigint', 'bigint', 'numeric', 'text']);
SELECT has_function('public', '_test_fund_cashbook_pot', ARRAY['bigint', 'bigint', 'numeric', 'text']);
SELECT has_function('public', '_test_kernel_service_role', ARRAY[]::text[]);
SELECT has_function('public', '_test_set_workspace_tenant', ARRAY['bigint']);

SELECT finish();
ROLLBACK;

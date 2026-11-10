CREATE FUNCTION public._test_money_kernel_bootstrap()
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'auth'
  AS $function$
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
    parent_tenant_id, cashbook_account_id, code, name, is_active
  )
  VALUES (
    v_tenant_id, v_account_id, 'TILL1', 'pgTAP Till', true
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
$function$;

GRANT ALL ON FUNCTION public._test_money_kernel_bootstrap() TO anon;

GRANT ALL ON FUNCTION public._test_money_kernel_bootstrap() TO authenticated;

GRANT ALL ON FUNCTION public._test_money_kernel_bootstrap() TO service_role;
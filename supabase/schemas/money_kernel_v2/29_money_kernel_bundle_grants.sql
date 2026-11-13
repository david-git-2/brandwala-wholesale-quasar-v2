-- cash_bundles is created in 27_* after 26_grants — explicit grants + RLS here.

GRANT SELECT ON money_kernel.cash_bundles TO authenticated, service_role;
GRANT SELECT ON money_kernel.pay_bundle_lines TO authenticated, service_role;

DROP POLICY IF EXISTS mk_cash_bundles_select ON money_kernel.cash_bundles;
CREATE POLICY mk_cash_bundles_select ON money_kernel.cash_bundles
  FOR SELECT TO authenticated
  USING (tenant_id = (SELECT public.auth_tenant_id()));

DROP POLICY IF EXISTS mk_pay_bundle_lines_select ON money_kernel.pay_bundle_lines;
CREATE POLICY mk_pay_bundle_lines_select ON money_kernel.pay_bundle_lines
  FOR SELECT TO authenticated
  USING (tenant_id = (SELECT public.auth_tenant_id()));

CREATE OR REPLACE FUNCTION money_kernel.assert_kernel_money_read(
  p_tenant_id bigint
) RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'access_denied: invalid_arguments';
  END IF;
  IF v_uid IS NULL THEN
    IF current_setting('request.jwt.claim.role', true) = 'service_role' THEN
      RETURN;
    END IF;
    RAISE EXCEPTION 'access_denied: not_authenticated';
  END IF;
  IF money_kernel.membership_has_money_action(v_uid, p_tenant_id, 'pay')
     OR money_kernel.membership_has_money_action(v_uid, p_tenant_id, 'deposit')
     OR public.membership_has_module_action(p_tenant_id, 'global_invoice', 'view')
     OR public.membership_has_module_action(p_tenant_id, 'payments', 'view') THEN
    RETURN;
  END IF;
  RAISE EXCEPTION 'access_denied: tenant %', p_tenant_id;
END;
$$;

GRANT EXECUTE ON FUNCTION money_kernel.assert_kernel_money_read(bigint) TO authenticated, service_role;

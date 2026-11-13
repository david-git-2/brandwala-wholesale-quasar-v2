-- Money spine v2 — RLS and grants (kernel tables; new rpc_* only).

ALTER TABLE money_kernel.cashbooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE money_kernel.cash_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE money_kernel.cash_bundles ENABLE ROW LEVEL SECURITY;
ALTER TABLE money_kernel.bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE money_kernel.bill_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE money_kernel.bill_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE money_kernel.bill_kind_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE money_kernel.pays ENABLE ROW LEVEL SECURITY;
ALTER TABLE money_kernel.pay_bundle_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE money_kernel.bill_settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE money_kernel.invoice_no_counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE money_kernel.money_outbox ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS mk_cashbooks_select ON money_kernel.cashbooks;
DROP POLICY IF EXISTS mk_cash_locations_select ON money_kernel.cash_locations;
DROP POLICY IF EXISTS mk_cash_bundles_select ON money_kernel.cash_bundles;
DROP POLICY IF EXISTS mk_bills_select ON money_kernel.bills;
DROP POLICY IF EXISTS mk_bill_lines_select ON money_kernel.bill_lines;
DROP POLICY IF EXISTS mk_bill_events_select ON money_kernel.bill_events;
DROP POLICY IF EXISTS mk_bill_kind_registry_select ON money_kernel.bill_kind_registry;
CREATE POLICY mk_cashbooks_select ON money_kernel.cashbooks
  FOR SELECT TO authenticated
  USING (tenant_id = (SELECT public.auth_tenant_id()));

CREATE POLICY mk_cash_locations_select ON money_kernel.cash_locations
  FOR SELECT TO authenticated
  USING (tenant_id = (SELECT public.auth_tenant_id()));

CREATE POLICY mk_cash_bundles_select ON money_kernel.cash_bundles
  FOR SELECT TO authenticated
  USING (tenant_id = (SELECT public.auth_tenant_id()));

CREATE POLICY mk_pay_bundle_lines_select ON money_kernel.pay_bundle_lines
  FOR SELECT TO authenticated
  USING (tenant_id = (SELECT public.auth_tenant_id()));

CREATE POLICY mk_bills_select ON money_kernel.bills
  FOR SELECT TO authenticated
  USING (tenant_id = (SELECT public.auth_tenant_id()));

CREATE POLICY mk_bill_lines_select ON money_kernel.bill_lines
  FOR SELECT TO authenticated
  USING (tenant_id = (SELECT public.auth_tenant_id()));

CREATE POLICY mk_bill_events_select ON money_kernel.bill_events
  FOR SELECT TO authenticated
  USING (tenant_id = (SELECT public.auth_tenant_id()));

CREATE POLICY mk_bill_kind_registry_select ON money_kernel.bill_kind_registry
  FOR SELECT TO authenticated
  USING (true);

REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA money_kernel FROM authenticated;

GRANT SELECT ON ALL TABLES IN SCHEMA money_kernel TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA money_kernel TO service_role;

REVOKE EXECUTE ON FUNCTION public.rpc_allocate_invoice_no(bigint, text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.assert_kernel_money_access(bigint, text, bigint) TO authenticated, service_role;

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) AS args
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN (
         'rpc_deposit', 'rpc_withdraw', 'rpc_transfer_same_profile', 'rpc_transfer_p2p',
         'rpc_pay_bills', 'rpc_pay_bill', 'rpc_apply_document_settlement',
         'rpc_void_document_settlement', 'rpc_void_pays', 'rpc_revert_pays', 'rpc_update_pays',
         'rpc_create_bill', 'rpc_update_draft_bill_v2',
         'rpc_issue_bill', 'rpc_void_bill', 'rpc_write_off_bill',
         'rpc_provision_cashbook_currency', 'rpc_provision_tenant_cashbook',
         'rpc_close_cash_bundle', 'rpc_list_profile_cashbook_bundles',
         'rpc_get_bill', 'rpc_query_bills', 'rpc_get_pot_balance', 'rpc_get_pot_balances',
         'rpc_profile_transactions', 'rpc_list_bill_kinds',
         'list_money_kernel_currencies'
       )
  LOOP
    EXECUTE format(
      'GRANT EXECUTE ON FUNCTION public.%I(%s) TO authenticated, service_role',
      r.proname,
      r.args
    );
  END LOOP;
END;
$$;

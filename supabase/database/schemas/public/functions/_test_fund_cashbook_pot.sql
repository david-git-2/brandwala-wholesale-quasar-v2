CREATE FUNCTION public._test_fund_cashbook_pot (
  p_tenant_id     bigint,
  p_point_id      bigint,
  p_amount        numeric,
  p_currency_code text    DEFAULT 'BDT'::text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public._test_fund_cashbook_pot(bigint, bigint, numeric, text) TO anon;

GRANT ALL ON FUNCTION public._test_fund_cashbook_pot(bigint, bigint, numeric, text) TO authenticated;

GRANT ALL ON FUNCTION public._test_fund_cashbook_pot(bigint, bigint, numeric, text) TO service_role;
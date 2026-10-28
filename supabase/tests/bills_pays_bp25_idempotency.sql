-- BP25: duplicate idempotency_key returns same pay (pgTAP + bootstrap)
BEGIN;

SELECT plan(1);

DO $$
DECLARE
  v_ctx jsonb := public._test_money_kernel_bootstrap();
  v_tenant bigint := (v_ctx ->> 'tenant_id')::bigint;
  v_profile bigint := (v_ctx ->> 'customer_profile_id')::bigint;
  v_point bigint := (v_ctx ->> 'cashbook_point_id')::bigint;
  v_key text := 'bp25-pgtap-' || gen_random_uuid()::text;
  v_pay1 public.pays;
  v_pay2 public.pays;
  v_ledger_count int;
BEGIN
  PERFORM public._test_pgtap_auth();

  v_pay1 := public.post_money_in(
    v_tenant,
    v_profile,
    current_date,
    null,
    null,
    'customer_cash',
    jsonb_build_array(
      jsonb_build_object(
        'payment_method_code', 'cash',
        'amount', 1.00,
        'cashbook_point_id', v_point
      )
    ),
    '[]'::jsonb,
    null,
    'BDT',
    null,
    null,
    v_key,
    v_point
  );

  v_pay2 := public.post_money_in(
    v_tenant,
    v_profile,
    current_date,
    null,
    null,
    'customer_cash',
    jsonb_build_array(
      jsonb_build_object(
        'payment_method_code', 'cash',
        'amount', 1.00,
        'cashbook_point_id', v_point
      )
    ),
    '[]'::jsonb,
    null,
    'BDT',
    null,
    null,
    v_key,
    v_point
  );

  IF v_pay1.id IS DISTINCT FROM v_pay2.id THEN
    RAISE EXCEPTION 'BP25 failed: expected same pays.id';
  END IF;
END;
$$;

SELECT ok(true, 'duplicate idempotency_key returns same pay');

SELECT finish();
ROLLBACK;

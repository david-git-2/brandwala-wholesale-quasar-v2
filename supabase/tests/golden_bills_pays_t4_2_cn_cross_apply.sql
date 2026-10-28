-- T4-2 — credit note applied to second bill; parent_bill_id on CN unchanged
BEGIN;

SELECT plan(2);

DO $$
DECLARE
  v_ctx jsonb;
  v_tenant bigint;
  v_profile bigint;
  v_b1 bigint;
  v_b2 bigint;
  v_cn public.bills;
  v_cn_parent bigint;
  v_due2 numeric;
BEGIN
  v_ctx := public._test_money_kernel_bootstrap();
  v_tenant := (v_ctx ->> 'tenant_id')::bigint;
  v_profile := (v_ctx ->> 'customer_profile_id')::bigint;

  v_b1 := public._test_issue_ar_bill(v_tenant, v_profile, 1000.00);
  v_b2 := public._test_issue_ar_bill(v_tenant, v_profile, 600.00);

  PERFORM public._test_pgtap_auth();

  v_cn := public.create_bill_adjustment(
    v_b1,
    'credit_note',
    400.00,
    'pgTAP CN cross-apply',
    true,
    null,
    null,
    '[]'::jsonb
  );

  v_cn_parent := v_cn.parent_bill_id;

  PERFORM public.apply_settlement_to_bill(v_tenant, v_b2, 'credit_note', v_cn.id, 400.00);

  IF v_cn.parent_bill_id IS DISTINCT FROM v_cn_parent THEN
    RAISE EXCEPTION 'T4-2: CN parent_bill_id must not change';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.bill_settlements bs
    WHERE bs.bill_id = v_b2
      AND bs.allocator_kind = 'credit_note'
      AND bs.allocator_id = v_cn.id
      AND bs.allocated_books_amount = 400.00
  ) THEN
    RAISE EXCEPTION 'T4-2: missing credit_note settlement on B2';
  END IF;

  v_due2 := (public.get_bill_net_balances(v_b2) ->> 'due_amount')::numeric;
  IF v_due2 <> 200.00 THEN
    RAISE EXCEPTION 'T4-2: B2 due expected 200, got %', v_due2;
  END IF;
END;
$$;

SELECT ok(true, 'T4-2 CN cross-apply settlement row');
SELECT ok(true, 'T4-2 CN parent_bill_id unchanged');

SELECT finish();
ROLLBACK;

-- Tier 1 — allocation invariants (raises)
BEGIN;

SELECT plan(3);

DO $$
DECLARE
  v_ctx jsonb;
  v_tenant bigint;
  v_profile bigint;
  v_point bigint;
  v_bill_id bigint;
BEGIN
  v_ctx := public._test_money_kernel_bootstrap();
  v_tenant := (v_ctx ->> 'tenant_id')::bigint;
  v_profile := (v_ctx ->> 'customer_profile_id')::bigint;
  v_point := (v_ctx ->> 'cashbook_point_id')::bigint;
  v_bill_id := public._test_issue_ar_bill(v_tenant, v_profile, 500.00);

  PERFORM public._test_pgtap_auth();

  BEGIN
    PERFORM public.post_money_in(
      v_tenant,
      v_profile,
      current_date,
      null,
      null,
      'customer_cash',
      jsonb_build_array(
        jsonb_build_object('payment_method_code', 'cash', 'amount', 100.00, 'cashbook_point_id', v_point)
      ),
      jsonb_build_array(jsonb_build_object('bill_id', v_bill_id, 'amount', 200.00)),
      null,
      'BDT',
      null,
      null,
      null,
      v_point
    );
    RAISE EXCEPTION 'tier1: alloc > pay should have failed';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT ILIKE '%alloc%' AND SQLERRM NOT ILIKE '%exceed%' AND SQLERRM NOT ILIKE '%greater%' THEN
        RAISE;
      END IF;
  END;

  BEGIN
    PERFORM public.post_money_in(
      v_tenant,
      v_profile,
      current_date,
      null,
      null,
      'customer_cash',
      jsonb_build_array(
        jsonb_build_object('payment_method_code', 'cash', 'amount', 1000.00, 'cashbook_point_id', v_point)
      ),
      jsonb_build_array(jsonb_build_object('bill_id', v_bill_id, 'amount', 900.00)),
      null,
      'BDT',
      null,
      null,
      null,
      v_point
    );
    RAISE EXCEPTION 'tier1: alloc > due should have failed';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT ILIKE '%due%' AND SQLERRM NOT ILIKE '%exceed%' AND SQLERRM NOT ILIKE '%balance%' THEN
        RAISE;
      END IF;
  END;

  BEGIN
    PERFORM public.create_bill_adjustment(
      999999999,
      'credit_note',
      10.00,
      'no parent',
      true
    );
    RAISE EXCEPTION 'tier1: CN without parent should fail';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT ILIKE '%not found%' AND SQLERRM NOT ILIKE '%parent%' THEN
        RAISE;
      END IF;
  END;
END;
$$;

SELECT ok(true, 'tier1 alloc greater than pay rejected');
SELECT ok(true, 'tier1 alloc greater than due rejected');
SELECT ok(true, 'tier1 credit note without valid parent rejected');

SELECT finish();
ROLLBACK;

-- rpc_void_* must set money.allow_kernel_delete before deleting bill_settlements (G1 trigger).

CREATE OR REPLACE FUNCTION public.rpc_void_document_settlement(
  p_tenant_id     bigint,
  p_settlement_id bigint,
  p_reason        text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_settle money_kernel.bill_settlements;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'void');

  SELECT * INTO v_settle FROM money_kernel.bill_settlements
   WHERE id = p_settlement_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: settlement %', p_settlement_id;
  END IF;
  IF v_settle.settlement_kind <> 'document' THEN
    RAISE EXCEPTION 'invalid_arguments: settlement % is not document; use rpc_void_pays', p_settlement_id;
  END IF;

  PERFORM 1 FROM money_kernel.bills
   WHERE id = ANY(ARRAY[v_settle.bill_id, v_settle.source_bill_id])
   ORDER BY id
   FOR UPDATE;

  PERFORM money_kernel.fn_kernel_settlement_delete_allowed();
  DELETE FROM money_kernel.bill_settlements WHERE id = p_settlement_id;

  RETURN jsonb_build_object(
    'settlement_id', p_settlement_id,
    'target_bill_id', v_settle.bill_id,
    'source_bill_id', v_settle.source_bill_id,
    'voided', true,
    'reason', p_reason
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_void_pays(
  p_tenant_id bigint,
  p_pays_id   bigint,
  p_reason    text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_pays money_kernel.pays;
  v_from_bal  numeric(18,4);
  v_to_bal    numeric(18,4);
  v_bill_ids  bigint[];
  v_impacts   jsonb := '[]'::jsonb;
  v_lot_ids   bigint[];
  v_to_credit numeric(18,4);
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'void');

  SELECT * INTO v_pays FROM money_kernel.pays
    WHERE id = p_pays_id AND tenant_id = p_tenant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: pays % in tenant %', p_pays_id, p_tenant_id;
  END IF;

  IF v_pays.status = 'voided' THEN
    SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = v_pays.from_cash_bundle_id;
    SELECT amount INTO v_to_bal   FROM money_kernel.cash_bundles WHERE id = v_pays.to_cash_bundle_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'status', 'voided', 'kind', v_pays.kind,
      'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
      'bill_impacts', '[]'::jsonb, 'idempotent', true
    );
  END IF;

  SELECT COALESCE(array_agg(bill_id ORDER BY bill_id), '{}')
    INTO v_bill_ids
    FROM (SELECT DISTINCT bill_id FROM money_kernel.bill_settlements WHERE pays_id = p_pays_id) s;

  SELECT COALESCE(array_agg(x ORDER BY x), '{}')
    INTO v_lot_ids
    FROM unnest(ARRAY[v_pays.from_cash_bundle_id, v_pays.to_cash_bundle_id]) AS x
   WHERE x IS NOT NULL;

  IF cardinality(v_bill_ids) > 0 THEN
    PERFORM 1 FROM money_kernel.bills WHERE id = ANY(v_bill_ids) ORDER BY id FOR UPDATE;
  END IF;
  IF cardinality(v_lot_ids) > 0 THEN
    PERFORM 1 FROM money_kernel.cash_bundles WHERE id = ANY(v_lot_ids) ORDER BY id FOR UPDATE;
  END IF;

  SELECT * INTO v_pays FROM money_kernel.pays
    WHERE id = p_pays_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF v_pays.status = 'voided' THEN
    SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = v_pays.from_cash_bundle_id;
    SELECT amount INTO v_to_bal   FROM money_kernel.cash_bundles WHERE id = v_pays.to_cash_bundle_id;
    RETURN jsonb_build_object(
      'pays_id', v_pays.id, 'status', 'voided', 'kind', v_pays.kind,
      'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
      'bill_impacts', '[]'::jsonb, 'idempotent', true
    );
  END IF;

  v_to_credit := CASE
    WHEN v_pays.kind = 'transfer' THEN round(v_pays.amount * v_pays.exchange_rate, 4)
    ELSE v_pays.amount
  END;
  IF v_pays.to_cash_bundle_id IS NOT NULL THEN
    SELECT amount INTO v_to_bal FROM money_kernel.cash_bundles WHERE id = v_pays.to_cash_bundle_id;
    IF v_to_bal < v_to_credit THEN
      RAISE EXCEPTION
        'insufficient_balance: cannot void pays %; to_pot % has % but reverse needs %',
        p_pays_id, v_pays.to_cash_bundle_id, v_to_bal, v_to_credit;
    END IF;
  END IF;

  PERFORM money_kernel.fn_kernel_settlement_delete_allowed();
  DELETE FROM money_kernel.bill_settlements
   WHERE pays_id = p_pays_id AND settlement_kind = 'pay';

  UPDATE money_kernel.pays
     SET status = 'voided',
         voided_at = now(),
         updated_at = now(),
         meta = COALESCE(meta, '{}'::jsonb)
                || jsonb_build_object('void_reason', p_reason)
   WHERE id = p_pays_id;

  SELECT COALESCE(
           jsonb_agg(
             jsonb_build_object('bill_id', id, 'due_after', due_amount)
             ORDER BY id
           ),
           '[]'::jsonb
         )
    INTO v_impacts
    FROM money_kernel.bills
   WHERE id = ANY(v_bill_ids);

  IF v_pays.from_cash_bundle_id IS NOT NULL THEN
    SELECT amount INTO v_from_bal FROM money_kernel.cash_bundles WHERE id = v_pays.from_cash_bundle_id;
  END IF;
  IF v_pays.to_cash_bundle_id IS NOT NULL THEN
    SELECT amount INTO v_to_bal FROM money_kernel.cash_bundles WHERE id = v_pays.to_cash_bundle_id;
  END IF;

  RETURN jsonb_build_object(
    'pays_id', v_pays.id, 'kind', v_pays.kind, 'amount', v_pays.amount,
    'status', 'voided',
    'from_cash_bundle_id', v_pays.from_cash_bundle_id, 'to_cash_bundle_id', v_pays.to_cash_bundle_id,
    'from_balance_after', v_from_bal, 'to_balance_after', v_to_bal,
    'bill_impacts', v_impacts, 'idempotent', false
  );
END;
$$;
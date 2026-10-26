-- Bill detail pay-out: one RPC runs payout + returns bill balances/history (same transaction).

CREATE OR REPLACE FUNCTION public.post_ap_payout_with_allocations_snapshot(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_paid_on date,
  p_cashbook_point_id bigint,
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_instruments jsonb DEFAULT '[]'::jsonb,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_source_currency_code text DEFAULT NULL,
  p_transaction_rate numeric DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_pay public.pays;
  v_bill_id bigint;
BEGIN
  v_pay := public.post_ap_payout_with_allocations(
    p_tenant_id,
    p_profile_id,
    p_paid_on,
    p_cashbook_point_id,
    p_note,
    p_reference,
    p_instruments,
    p_allocations,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    p_source_currency_code,
    p_transaction_rate,
    p_cashbook_point_pot_id
  );

  v_bill_id := NULL;
  IF p_allocations IS NOT NULL AND jsonb_typeof(p_allocations) = 'array' THEN
    SELECT (elem->>'bill_id')::bigint
    INTO v_bill_id
    FROM jsonb_array_elements(p_allocations) AS elem
    WHERE nullif(trim(elem->>'bill_id'), '') IS NOT NULL
    LIMIT 1;
  END IF;

  IF v_bill_id IS NULL THEN
    RETURN jsonb_build_object('pay', to_jsonb(v_pay));
  END IF;

  RETURN jsonb_build_object(
    'pay', to_jsonb(v_pay),
    'bill', (SELECT to_jsonb(b) FROM public.bills b WHERE b.id = v_bill_id),
    'net_balances', public.get_bill_net_balances(v_bill_id),
    'payment_history', public.list_invoice_payment_history(p_tenant_id, v_bill_id)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.post_ap_payout_with_allocations_snapshot(
  bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint
) FROM PUBLIC;

GRANT ALL ON FUNCTION public.post_ap_payout_with_allocations_snapshot(
  bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint
) TO authenticated, service_role;

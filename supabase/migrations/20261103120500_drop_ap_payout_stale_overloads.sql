-- BP25 left 14- and 15-arg overloads; 14-arg internal calls raise SQLSTATE 42725.

DROP FUNCTION IF EXISTS public.post_ap_payout_with_allocations_snapshot(
  bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint
);

DROP FUNCTION IF EXISTS public.post_ap_payout_with_allocations(
  bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint
);

DROP FUNCTION IF EXISTS public.post_shipment_ap_money_out_snapshot(
  bigint[], bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint
);

CREATE OR REPLACE FUNCTION public.post_shipment_ap_money_out_snapshot(
  p_shipment_ids bigint[],
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
  p_cashbook_point_pot_id bigint DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  if p_shipment_ids is null or coalesce(array_length(p_shipment_ids, 1), 0) = 0 then
    raise exception 'shipment_ids is required';
  end if;

  perform public._shipment_money_lock_shipment_ids(p_shipment_ids);

  return public.post_ap_payout_with_allocations_snapshot(
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
    p_cashbook_point_pot_id,
    p_idempotency_key
  );
end;
$$;

REVOKE ALL ON FUNCTION public.post_ap_payout_with_allocations_snapshot(
  bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint, text
) FROM PUBLIC;

GRANT ALL ON FUNCTION public.post_ap_payout_with_allocations_snapshot(
  bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint, text
) TO authenticated;

GRANT ALL ON FUNCTION public.post_ap_payout_with_allocations_snapshot(
  bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint, text
) TO service_role;

GRANT EXECUTE ON FUNCTION public.post_shipment_ap_money_out_snapshot(
  bigint[], bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint, text
) TO authenticated, service_role;

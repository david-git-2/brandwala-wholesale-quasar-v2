CREATE FUNCTION public.post_shipment_ap_money_out_snapshot (
  p_shipment_ids             bigint[],
  p_tenant_id                bigint,
  p_profile_id               bigint,
  p_paid_on                  date,
  p_cashbook_point_id        bigint,
  p_note                     text     DEFAULT NULL::text,
  p_reference                text     DEFAULT NULL::text,
  p_instruments              jsonb    DEFAULT '[]'::jsonb,
  p_allocations              jsonb    DEFAULT '[]'::jsonb,
  p_settlement_currency_code text     DEFAULT 'BDT'::text,
  p_foreign_amount           numeric  DEFAULT NULL::numeric,
  p_exchange_rate            numeric  DEFAULT NULL::numeric,
  p_source_currency_code     text     DEFAULT NULL::text,
  p_transaction_rate         numeric  DEFAULT NULL::numeric,
  p_cashbook_point_pot_id    bigint   DEFAULT NULL::bigint,
  p_idempotency_key          text     DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_sid_loop bigint;
begin
  if p_shipment_ids is null or coalesce(array_length(p_shipment_ids, 1), 0) = 0 then
    raise exception 'shipment_ids is required';
  end if;

  perform public._shipment_money_lock_shipment_ids(p_shipment_ids);

  for v_sid_loop in
    select distinct x.id
    from unnest(p_shipment_ids) as x(id)
    where x.id is not null
  loop
    perform public._assert_shipment_ap_payable(v_sid_loop);
  end loop;

  perform public._assert_shipment_ap_allocations_payable(p_allocations);

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
$function$;

GRANT ALL ON FUNCTION
  public.post_shipment_ap_money_out_snapshot(bigint[], bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint, text) TO anon;

GRANT ALL ON FUNCTION
  public.post_shipment_ap_money_out_snapshot(bigint[], bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION
  public.post_shipment_ap_money_out_snapshot(bigint[], bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint, text) TO service_role;
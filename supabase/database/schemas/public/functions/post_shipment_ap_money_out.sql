CREATE FUNCTION public.post_shipment_ap_money_out (
  p_shipment_ids             bigint[],
  p_tenant_id                bigint,
  p_profile_id               bigint,
  p_paid_on                  date,
  p_amount                   numeric,
  p_source                   text     DEFAULT 'ap_payout'::text,
  p_note                     text     DEFAULT NULL::text,
  p_reference                text     DEFAULT NULL::text,
  p_cashbook_point_id        bigint   DEFAULT NULL::bigint,
  p_instruments              jsonb    DEFAULT '[]'::jsonb,
  p_allocations              jsonb    DEFAULT '[]'::jsonb,
  p_settlement_currency_code text     DEFAULT 'BDT'::text,
  p_foreign_amount           numeric  DEFAULT NULL::numeric,
  p_exchange_rate            numeric  DEFAULT NULL::numeric,
  p_source_type              text     DEFAULT 'shipment_cost'::text,
  p_source_id                text     DEFAULT NULL::text,
  p_idempotency_key          text     DEFAULT NULL::text
)
  RETURNS public.pays
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_pay public.pays;
  v_sid text;
  v_primary bigint;
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

  select min(x.id) into v_primary from unnest(p_shipment_ids) as x(id) where x.id is not null;
  v_sid := coalesce(nullif(trim(p_source_id), ''), v_primary::text);

  v_pay := public.post_money_out(
    p_tenant_id,
    p_profile_id,
    p_paid_on,
    p_amount,
    p_source,
    p_note,
    p_reference,
    p_cashbook_point_id,
    p_instruments,
    p_allocations,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    coalesce(nullif(trim(p_source_type), ''), 'shipment_cost'),
    v_sid,
    p_idempotency_key
  );

  return v_pay;
end;
$function$;

GRANT ALL ON FUNCTION public.post_shipment_ap_money_out(bigint[], bigint, bigint, date, numeric, text, text, text, bigint, jsonb, jsonb, text, numeric, numeric, text, text, text)
  TO anon;

GRANT ALL ON FUNCTION public.post_shipment_ap_money_out(bigint[], bigint, bigint, date, numeric, text, text, text, bigint, jsonb, jsonb, text, numeric, numeric, text, text, text)
  TO authenticated;

GRANT ALL ON FUNCTION public.post_shipment_ap_money_out(bigint[], bigint, bigint, date, numeric, text, text, text, bigint, jsonb, jsonb, text, numeric, numeric, text, text, text)
  TO service_role;
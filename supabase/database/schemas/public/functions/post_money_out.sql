CREATE FUNCTION public.post_money_out (
  p_tenant_id                bigint,
  p_profile_id               bigint,
  p_paid_on                  date,
  p_amount                   numeric,
  p_source                   text    DEFAULT 'ap_payout'::text,
  p_note                     text    DEFAULT NULL::text,
  p_reference                text    DEFAULT NULL::text,
  p_cashbook_point_id        bigint  DEFAULT NULL::bigint,
  p_instruments              jsonb   DEFAULT '[]'::jsonb,
  p_allocations              jsonb   DEFAULT '[]'::jsonb,
  p_settlement_currency_code text    DEFAULT 'BDT'::text,
  p_foreign_amount           numeric DEFAULT NULL::numeric,
  p_exchange_rate            numeric DEFAULT NULL::numeric,
  p_source_type              text    DEFAULT NULL::text,
  p_source_id                text    DEFAULT NULL::text,
  p_idempotency_key          text    DEFAULT NULL::text,
  p_cashbook_point_pot_id    bigint  DEFAULT NULL::bigint,
  p_payout_method            text    DEFAULT 'bank_transfer'::text
)
  RETURNS public.pays
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_pay public.pays;
begin
  if coalesce(p_source_type, '') = 'commission' or p_source = 'commission' then
    return public._kernel_post_commission_payout(
      p_tenant_id,
      p_profile_id,
      p_paid_on,
      p_amount,
      p_note,
      p_reference,
      p_payout_method,
      p_cashbook_point_id,
      p_cashbook_point_pot_id,
      p_source_id,
      p_idempotency_key
    );
  end if;

  if p_cashbook_point_id is null then
    raise exception 'cashbook_point_id required for pay out';
  end if;

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
    null,
    null,
    null,
    p_idempotency_key
  );

  return v_pay;
end;
$function$;

CREATE FUNCTION public.post_money_out (
  p_tenant_id                bigint,
  p_profile_id               bigint,
  p_paid_on                  date,
  p_amount                   numeric,
  p_source                   text    DEFAULT 'ap_payout'::text,
  p_note                     text    DEFAULT NULL::text,
  p_reference                text    DEFAULT NULL::text,
  p_cashbook_point_id        bigint  DEFAULT NULL::bigint,
  p_instruments              jsonb   DEFAULT '[]'::jsonb,
  p_allocations              jsonb   DEFAULT '[]'::jsonb,
  p_settlement_currency_code text    DEFAULT 'BDT'::text,
  p_foreign_amount           numeric DEFAULT NULL::numeric,
  p_exchange_rate            numeric DEFAULT NULL::numeric,
  p_source_type              text    DEFAULT NULL::text,
  p_source_id                text    DEFAULT NULL::text,
  p_idempotency_key          text    DEFAULT NULL::text
)
  RETURNS public.pays
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_pay public.pays;
  v_disp jsonb;
begin
  if coalesce(p_source_type, '') = 'commission' or p_source = 'commission' then
    v_disp := public.dispense_middleman_payout_from_tenant(
      p_tenant_id, p_profile_id, p_amount, 'bank_transfer', p_note, p_cashbook_point_id, null
    );
    if coalesce(v_disp->>'success', 'false') <> 'true' then
      raise exception '%', coalesce(v_disp->>'error', 'commission payout failed');
    end if;
    return null;
  end if;

  if p_cashbook_point_id is null then
    raise exception 'cashbook_point_id required for pay out';
  end if;

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
    null,
    null,
    null,
    p_idempotency_key
  );

  return v_pay;
end;
$function$;

GRANT ALL ON FUNCTION public.post_money_out(bigint, bigint, date, numeric, text, text, text, bigint, jsonb, jsonb, text, numeric, numeric, text, text, text, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.post_money_out(bigint, bigint, date, numeric, text, text, text, bigint, jsonb, jsonb, text, numeric, numeric, text, text, text, bigint, text) TO
  authenticated;

GRANT ALL ON FUNCTION public.post_money_out(bigint, bigint, date, numeric, text, text, text, bigint, jsonb, jsonb, text, numeric, numeric, text, text, text, bigint, text) TO
  service_role;

GRANT ALL ON FUNCTION public.post_money_out(bigint, bigint, date, numeric, text, text, text, bigint, jsonb, jsonb, text, numeric, numeric, text, text, text) TO anon;

GRANT ALL ON FUNCTION public.post_money_out(bigint, bigint, date, numeric, text, text, text, bigint, jsonb, jsonb, text, numeric, numeric, text, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.post_money_out(bigint, bigint, date, numeric, text, text, text, bigint, jsonb, jsonb, text, numeric, numeric, text, text, text) TO service_role;
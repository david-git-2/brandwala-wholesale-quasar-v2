CREATE FUNCTION public.post_money_in (
  p_tenant_id                bigint,
  p_profile_id               bigint,
  p_received_on              date,
  p_note                     text    DEFAULT NULL::text,
  p_reference                text    DEFAULT NULL::text,
  p_source                   text    DEFAULT 'customer_cash'::text,
  p_instruments              jsonb   DEFAULT '[]'::jsonb,
  p_allocations              jsonb   DEFAULT '[]'::jsonb,
  p_shop_order_id            bigint  DEFAULT NULL::bigint,
  p_settlement_currency_code text    DEFAULT 'BDT'::text,
  p_foreign_amount           numeric DEFAULT NULL::numeric,
  p_exchange_rate            numeric DEFAULT NULL::numeric,
  p_idempotency_key          text    DEFAULT NULL::text,
  p_cashbook_point_id        bigint  DEFAULT NULL::bigint,
  p_cashbook_point_pot_id    bigint  DEFAULT NULL::bigint,
  p_source_currency_code     text    DEFAULT NULL::text,
  p_transaction_rate         numeric DEFAULT NULL::numeric
)
  RETURNS public.pays
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_pay public.pays;
begin
  v_pay := public.post_customer_receipt_with_allocations(
    p_tenant_id,
    p_profile_id,
    p_received_on,
    p_note,
    p_reference,
    p_source,
    p_instruments,
    p_allocations,
    p_shop_order_id,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    true,
    p_idempotency_key,
    p_cashbook_point_id,
    p_cashbook_point_pot_id,
    p_source_currency_code,
    p_transaction_rate
  );

  return v_pay;
end;
$function$;

CREATE FUNCTION public.post_money_in (
  p_tenant_id                bigint,
  p_profile_id               bigint,
  p_received_on              date,
  p_note                     text    DEFAULT NULL::text,
  p_reference                text    DEFAULT NULL::text,
  p_source                   text    DEFAULT 'customer_cash'::text,
  p_instruments              jsonb   DEFAULT '[]'::jsonb,
  p_allocations              jsonb   DEFAULT '[]'::jsonb,
  p_shop_order_id            bigint  DEFAULT NULL::bigint,
  p_settlement_currency_code text    DEFAULT 'BDT'::text,
  p_foreign_amount           numeric DEFAULT NULL::numeric,
  p_exchange_rate            numeric DEFAULT NULL::numeric,
  p_idempotency_key          text    DEFAULT NULL::text
)
  RETURNS public.pays
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_pay public.pays;
begin
  v_pay := public.post_customer_receipt_with_allocations(
    p_tenant_id,
    p_profile_id,
    p_received_on,
    p_note,
    p_reference,
    p_source,
    p_instruments,
    p_allocations,
    p_shop_order_id,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    true,
    p_idempotency_key
  );

  return v_pay;
end;
$function$;

GRANT ALL ON FUNCTION public.post_money_in(bigint, bigint, date, text, text, text, jsonb, jsonb, bigint, text, numeric, numeric, text, bigint, bigint, text, numeric) TO anon;

GRANT ALL ON FUNCTION public.post_money_in(bigint, bigint, date, text, text, text, jsonb, jsonb, bigint, text, numeric, numeric, text, bigint, bigint, text, numeric) TO
  authenticated;

GRANT ALL ON FUNCTION public.post_money_in(bigint, bigint, date, text, text, text, jsonb, jsonb, bigint, text, numeric, numeric, text, bigint, bigint, text, numeric) TO
  service_role;

GRANT ALL ON FUNCTION public.post_money_in(bigint, bigint, date, text, text, text, jsonb, jsonb, bigint, text, numeric, numeric, text) TO anon;

GRANT ALL ON FUNCTION public.post_money_in(bigint, bigint, date, text, text, text, jsonb, jsonb, bigint, text, numeric, numeric, text) TO authenticated;

GRANT ALL ON FUNCTION public.post_money_in(bigint, bigint, date, text, text, text, jsonb, jsonb, bigint, text, numeric, numeric, text) TO service_role;
CREATE FUNCTION public.normalize_pay_settlement_fx (
  p_instrument_total_bdt     numeric,
  p_settlement_currency_code text    DEFAULT 'BDT'::text,
  p_foreign_amount           numeric DEFAULT NULL::numeric,
  p_exchange_rate            numeric DEFAULT NULL::numeric,
  p_base_currency_code       text    DEFAULT 'BDT'::text
)
  RETURNS TABLE (
    settlement_currency_code text,
    foreign_amount           numeric,
    exchange_rate            numeric,
    amount_bdt               numeric
  )
  LANGUAGE plpgsql
  IMMUTABLE
  AS $function$
declare
  v_cur text;
  v_base text;
  v_for numeric;
  v_rate numeric;
  v_bdt numeric;
begin
  v_base := upper(trim(coalesce(p_base_currency_code, 'BDT')));
  v_cur := upper(trim(coalesce(p_settlement_currency_code, v_base)));
  v_for := p_foreign_amount;

  if v_for is not null and v_for > 0 then
    if v_cur in ('', v_base) then
      raise exception 'foreign_amount requires a settlement currency other than base (%)', v_base;
    end if;
    v_rate := coalesce(p_exchange_rate, 0);
    if v_rate <= 0 then
      raise exception 'exchange_rate must be positive when foreign_amount is set';
    end if;
    v_bdt := round(v_for * v_rate, 2);
    if coalesce(p_instrument_total_bdt, 0) > 0 and round(p_instrument_total_bdt, 2) <> v_bdt then
      raise exception 'Payment instruments total (%) must match books amount from foreign settlement (%)',
        p_instrument_total_bdt, v_bdt;
    end if;
    settlement_currency_code := v_cur;
    foreign_amount := round(v_for, 2);
    exchange_rate := v_rate;
    amount_bdt := v_bdt;
    return next;
    return;
  end if;

  v_bdt := round(coalesce(p_instrument_total_bdt, 0), 2);
  settlement_currency_code := v_base;
  foreign_amount := null;
  exchange_rate := 1.000000;
  amount_bdt := v_bdt;
  return next;
end;
$function$;

GRANT ALL ON FUNCTION public.normalize_pay_settlement_fx(numeric, text, numeric, numeric, text) TO anon;

GRANT ALL ON FUNCTION public.normalize_pay_settlement_fx(numeric, text, numeric, numeric, text) TO authenticated;

GRANT ALL ON FUNCTION public.normalize_pay_settlement_fx(numeric, text, numeric, numeric, text) TO service_role;
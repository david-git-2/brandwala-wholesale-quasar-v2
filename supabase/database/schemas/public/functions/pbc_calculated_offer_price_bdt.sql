CREATE FUNCTION public.pbc_calculated_offer_price_bdt (
  p_price_gbp          numeric,
  p_product_weight     numeric,
  p_package_weight     numeric,
  p_cargo_rate         numeric,
  p_conversion_rate    numeric,
  p_profit_rate        numeric,
  p_vat_rate           numeric,
  p_offer_pricing_mode text
)
  RETURNS numeric
  LANGUAGE plpgsql
  IMMUTABLE
  AS $function$
declare
  v_mode text := coalesce(p_offer_pricing_mode, 'landed_cost_plus');
  v_fx numeric := coalesce(p_conversion_rate, 140);
  v_profit numeric := coalesce(p_profit_rate, 0);
  v_vat numeric := coalesce(p_vat_rate, 0);
  v_unit_cost_bdt numeric;
  v_marked_gbp numeric;
begin
  if v_mode = 'gbp_vat_then_profit' then
    v_marked_gbp := round(
      coalesce(p_price_gbp, 0) * (1 + v_vat / 100.0) * (1 + v_profit / 100.0),
      2
    );
    return public.round_bdt_up_to_zero_or_five(ceil(v_marked_gbp * v_fx - 1e-9));
  end if;

  v_unit_cost_bdt := ceil(
    round(
      (coalesce(p_price_gbp, 0) + ((coalesce(p_product_weight, 0) + coalesce(p_package_weight, 0)) / 1000.0) * coalesce(p_cargo_rate, 0)),
      2
    ) * v_fx - 1e-9
  );
  return public.round_bdt_up_to_zero_or_five(v_unit_cost_bdt + (v_unit_cost_bdt * v_profit / 100.0));
end;
$function$;

GRANT ALL ON FUNCTION public.pbc_calculated_offer_price_bdt(numeric, numeric, numeric, numeric, numeric, numeric, numeric, text) TO anon;

GRANT ALL ON FUNCTION public.pbc_calculated_offer_price_bdt(numeric, numeric, numeric, numeric, numeric, numeric, numeric, text) TO authenticated;

GRANT ALL ON FUNCTION public.pbc_calculated_offer_price_bdt(numeric, numeric, numeric, numeric, numeric, numeric, numeric, text) TO service_role;
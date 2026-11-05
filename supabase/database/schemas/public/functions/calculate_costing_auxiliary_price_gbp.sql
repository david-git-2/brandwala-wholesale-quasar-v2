CREATE FUNCTION public.calculate_costing_auxiliary_price_gbp (
  p_price_in_web_gbp   numeric,
  p_delivery_price_gbp numeric
)
  RETURNS numeric
  LANGUAGE plpgsql
  IMMUTABLE
  AS $function$
declare
  v_base_price_gbp numeric(12,2);
begin
  v_base_price_gbp := round((coalesce(p_price_in_web_gbp, 0) + coalesce(p_delivery_price_gbp, 0))::numeric, 2);

  if v_base_price_gbp <= 10 then
    return 0;
  end if;

  if v_base_price_gbp <= 100 then
    return 2;
  end if;

  return round((2 + ceil((v_base_price_gbp - 100) / 50.0))::numeric, 2);
end;
$function$;

GRANT ALL ON FUNCTION public.calculate_costing_auxiliary_price_gbp(numeric, numeric) TO anon;

GRANT ALL ON FUNCTION public.calculate_costing_auxiliary_price_gbp(numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.calculate_costing_auxiliary_price_gbp(numeric, numeric) TO service_role;
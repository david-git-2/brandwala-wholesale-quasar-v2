CREATE FUNCTION public.round_bdt_up_to_zero_or_five (
  p_value numeric
)
  RETURNS integer
  LANGUAGE plpgsql
  IMMUTABLE
  AS $function$
declare
  v_rounded_up integer;
  v_remainder integer;
begin
  v_rounded_up := ceil(coalesce(p_value, 0))::integer;
  v_remainder := mod(v_rounded_up, 5);

  if v_remainder = 0 then
    return v_rounded_up;
  end if;

  return v_rounded_up + (5 - v_remainder);
end;
$function$;

GRANT ALL ON FUNCTION public.round_bdt_up_to_zero_or_five(numeric) TO anon;

GRANT ALL ON FUNCTION public.round_bdt_up_to_zero_or_five(numeric) TO authenticated;

GRANT ALL ON FUNCTION public.round_bdt_up_to_zero_or_five(numeric) TO service_role;
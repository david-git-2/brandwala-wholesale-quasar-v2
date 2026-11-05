CREATE FUNCTION public.calculate_costing_item_type_surcharge_gbp (
  p_item_type text
)
  RETURNS numeric
  LANGUAGE plpgsql
  IMMUTABLE
  AS $function$
declare
  v_normalized_type text;
begin
  v_normalized_type := lower(trim(coalesce(p_item_type, '')));

  if v_normalized_type in ('watch', 'perfume') then
    return 3;
  end if;

  return 0;
end;
$function$;

GRANT ALL ON FUNCTION public.calculate_costing_item_type_surcharge_gbp(text) TO anon;

GRANT ALL ON FUNCTION public.calculate_costing_item_type_surcharge_gbp(text) TO authenticated;

GRANT ALL ON FUNCTION public.calculate_costing_item_type_surcharge_gbp(text) TO service_role;
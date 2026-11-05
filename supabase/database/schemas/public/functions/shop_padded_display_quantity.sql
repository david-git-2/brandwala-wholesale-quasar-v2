CREATE FUNCTION public.shop_padded_display_quantity (
  p_real integer,
  p_add  integer DEFAULT 6
)
  RETURNS integer
  LANGUAGE sql
  IMMUTABLE
  SET search_path TO 'public'
  AS $function$
  select case
    when coalesce(p_real, 0) <= 0 then 0
    when p_real <= 2 then p_real
    else p_real + greatest(coalesce(p_add, 6), 0)
  end;
$function$;

GRANT ALL ON FUNCTION public.shop_padded_display_quantity(integer, integer) TO anon;

GRANT ALL ON FUNCTION public.shop_padded_display_quantity(integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.shop_padded_display_quantity(integer, integer) TO service_role;
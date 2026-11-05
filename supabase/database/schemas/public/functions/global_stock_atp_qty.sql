CREATE FUNCTION public.global_stock_atp_qty (
  p_global_stock_id bigint
)
  RETURNS numeric
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select greatest(
    coalesce((
      select sum(gs.quantity)
      from public.global_stocks gs
      left join public.stock_locations sl on sl.id = gs.location_id
      where gs.id = p_global_stock_id
        and gs.is_archived = false
        and gs.availability = 'sellable'::public.stock_availability
        and (gs.location_id is null or sl.is_pickable = true)
    ), 0) - public.global_stock_hold_qty(p_global_stock_id),
    0
  );
$function$;

GRANT ALL ON FUNCTION public.global_stock_atp_qty(bigint) TO anon;

GRANT ALL ON FUNCTION public.global_stock_atp_qty(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.global_stock_atp_qty(bigint) TO service_role;
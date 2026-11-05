CREATE FUNCTION public.default_putaway_stock_location_id (
  p_tenant_id bigint
)
  RETURNS bigint
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_loc bigint;
begin
  select sl.id into v_loc
  from public.stock_locations sl
  where sl.parent_tenant_id = p_tenant_id
    and sl.is_active = true
    and public._stock_location_is_leaf(sl.id)
  order by sl.is_default desc, sl.is_pickable desc, sl.sort_order, sl.id
  limit 1;

  if v_loc is null then
    v_loc := public.ensure_default_stock_location(p_tenant_id);
  end if;

  return v_loc;
end;
$function$;

GRANT ALL ON FUNCTION public.default_putaway_stock_location_id(bigint) TO anon;

GRANT ALL ON FUNCTION public.default_putaway_stock_location_id(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.default_putaway_stock_location_id(bigint) TO service_role;
CREATE FUNCTION public.list_stock_locations (
  p_parent_tenant_id bigint,
  p_include_inactive boolean DEFAULT false
)
  RETURNS SETOF public.stock_locations
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  perform public._assert_parent_warehouse_tenant(p_parent_tenant_id);

  if not public._can_view_stock_locations(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  select l.*
  from public.stock_locations l
  where l.parent_tenant_id = p_parent_tenant_id
    and (p_include_inactive or l.is_active = true)
  order by l.sort_order asc, l.code asc, l.id asc;
end;
$function$;

GRANT ALL ON FUNCTION public.list_stock_locations(bigint, boolean) TO anon;

GRANT ALL ON FUNCTION public.list_stock_locations(bigint, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.list_stock_locations(bigint, boolean) TO service_role;
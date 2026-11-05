CREATE FUNCTION public.set_default_stock_location (
  p_id bigint
)
  RETURNS public.stock_locations
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.stock_locations%rowtype;
begin
  select * into v_row
  from public.stock_locations
  where id = p_id
  for update;

  if not found then
    raise exception 'location not found';
  end if;

  perform public._assert_parent_warehouse_tenant(v_row.parent_tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_row.parent_tenant_id)
    or public.membership_has_module_action(v_row.parent_tenant_id, 'global_stock_location', 'edit')
  ) then
    raise exception 'not allowed';
  end if;

  if not v_row.is_active then
    raise exception 'cannot set inactive location as default';
  end if;

  if not public._stock_location_is_leaf(v_row.id) then
    raise exception 'only leaf locations can be the default put-away';
  end if;

  update public.stock_locations
  set is_default = false
  where parent_tenant_id = v_row.parent_tenant_id
    and is_default = true
    and id <> p_id;

  update public.stock_locations
  set is_default = true
  where id = p_id
  returning * into v_row;

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.set_default_stock_location(bigint) TO anon;

GRANT ALL ON FUNCTION public.set_default_stock_location(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.set_default_stock_location(bigint) TO service_role;
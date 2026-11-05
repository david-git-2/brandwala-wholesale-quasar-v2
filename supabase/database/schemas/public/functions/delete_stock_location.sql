CREATE FUNCTION public.delete_stock_location (
  p_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.stock_locations%rowtype;
  v_parent bigint;
begin
  select * into v_row
  from public.stock_locations
  where id = p_id
  for update;

  if not found then
    raise exception 'location not found';
  end if;

  v_parent := v_row.parent_tenant_id;
  perform public._assert_parent_warehouse_tenant(v_parent);

  if not (
    public.user_can_manage_parent_tenant(v_parent)
    or public.membership_has_module_action(v_parent, 'global_stock_location', 'delete')
    or public.membership_has_module_action(v_parent, 'global_stock_location', 'edit')
  ) then
    raise exception 'not allowed';
  end if;

  delete from public.stock_locations where id = p_id;

  -- Promote another leaf default if needed
  if not exists (
    select 1 from public.stock_locations l
    where l.parent_tenant_id = v_parent
      and l.is_default = true
      and l.is_active = true
      and public._stock_location_is_leaf(l.id)
  ) then
    update public.stock_locations
    set is_default = true
    where id = (
      select l.id from public.stock_locations l
      where l.parent_tenant_id = v_parent
        and l.is_active = true
        and public._stock_location_is_leaf(l.id)
      order by l.sort_order, l.id
      limit 1
    );
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public.delete_stock_location(bigint) TO anon;

GRANT ALL ON FUNCTION public.delete_stock_location(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delete_stock_location(bigint) TO service_role;
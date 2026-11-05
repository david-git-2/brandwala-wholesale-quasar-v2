CREATE FUNCTION public.ensure_default_stock_location (
  p_tenant_id bigint
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant public.tenants%rowtype;
  v_loc_id bigint;
  v_wh bigint;
  v_zone bigint;
  v_shelf bigint;
  v_level bigint;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  select * into v_tenant from public.tenants where id = p_tenant_id;
  if not found then
    raise exception 'tenant % not found', p_tenant_id;
  end if;

  if v_tenant.parent_id is not null then
    return public.ensure_default_stock_location(v_tenant.parent_id);
  end if;

  select sl.id into v_loc_id
  from public.stock_locations sl
  where sl.parent_tenant_id = p_tenant_id
    and sl.is_active = true
    and public._stock_location_is_leaf(sl.id)
  order by sl.is_default desc, sl.is_pickable desc, sl.sort_order, sl.id
  limit 1;

  if v_loc_id is not null then
    return v_loc_id;
  end if;

  insert into public.stock_locations (
    parent_tenant_id, parent_location_id, code, name, kind,
    is_pickable, is_default, is_active, sort_order
  ) values (
    p_tenant_id, null, 'MAIN', 'Main warehouse', 'warehouse',
    false, false, true, 10
  )
  on conflict (parent_tenant_id, code) do update
    set kind = 'warehouse'::public.stock_location_kind,
        name = excluded.name,
        is_active = true
  returning id into v_wh;

  if v_wh is null then
    select id into v_wh from public.stock_locations
    where parent_tenant_id = p_tenant_id and code = 'MAIN';
  end if;

  insert into public.stock_locations (
    parent_tenant_id, parent_location_id, code, name, kind,
    is_pickable, is_default, is_active, sort_order
  ) values (
    p_tenant_id, v_wh, 'MAIN-ZONE', 'Default zone', 'zone',
    false, false, true, 20
  )
  on conflict (parent_tenant_id, code) do update
    set parent_location_id = v_wh,
        kind = 'zone'::public.stock_location_kind,
        is_active = true
  returning id into v_zone;

  if v_zone is null then
    select id into v_zone from public.stock_locations
    where parent_tenant_id = p_tenant_id and code = 'MAIN-ZONE';
  end if;

  insert into public.stock_locations (
    parent_tenant_id, parent_location_id, code, name, kind,
    is_pickable, is_default, is_active, sort_order
  ) values (
    p_tenant_id, v_zone, 'MAIN-SHELF', 'Default shelf', 'shelf',
    false, false, true, 30
  )
  on conflict (parent_tenant_id, code) do update
    set parent_location_id = v_zone,
        kind = 'shelf'::public.stock_location_kind,
        is_active = true
  returning id into v_shelf;

  if v_shelf is null then
    select id into v_shelf from public.stock_locations
    where parent_tenant_id = p_tenant_id and code = 'MAIN-SHELF';
  end if;

  insert into public.stock_locations (
    parent_tenant_id, parent_location_id, code, name, kind,
    is_pickable, is_default, is_active, sort_order
  ) values (
    p_tenant_id, v_shelf, 'MAIN-LEVEL', 'Default level', 'level',
    false, false, true, 40
  )
  on conflict (parent_tenant_id, code) do update
    set parent_location_id = v_shelf,
        kind = 'level'::public.stock_location_kind,
        is_active = true
  returning id into v_level;

  if v_level is null then
    select id into v_level from public.stock_locations
    where parent_tenant_id = p_tenant_id and code = 'MAIN-LEVEL';
  end if;

  insert into public.stock_locations (
    parent_tenant_id, parent_location_id, code, name, kind,
    is_pickable, is_default, is_active, sort_order
  ) values (
    p_tenant_id, v_level, 'MAIN-BIN', 'Default bin', 'bin',
    true, true, true, 50
  )
  on conflict (parent_tenant_id, code) do update
    set parent_location_id = v_level,
        kind = 'bin'::public.stock_location_kind,
        is_pickable = true,
        is_default = true,
        is_active = true
  returning id into v_loc_id;

  if v_loc_id is null then
    select id into v_loc_id from public.stock_locations
    where parent_tenant_id = p_tenant_id and code = 'MAIN-BIN';
  end if;

  return v_loc_id;
end;
$function$;

GRANT ALL ON FUNCTION public.ensure_default_stock_location(bigint) TO anon;

GRANT ALL ON FUNCTION public.ensure_default_stock_location(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.ensure_default_stock_location(bigint) TO service_role;
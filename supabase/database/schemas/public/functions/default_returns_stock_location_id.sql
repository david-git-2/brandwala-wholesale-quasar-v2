CREATE FUNCTION public.default_returns_stock_location_id (
  p_tenant_id bigint
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant public.tenants%rowtype;
  v_loc bigint;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  select * into v_tenant from public.tenants where id = p_tenant_id;
  if not found then
    raise exception 'tenant % not found', p_tenant_id;
  end if;

  if v_tenant.parent_id is not null then
    return public.default_returns_stock_location_id(v_tenant.parent_id);
  end if;

  select sl.id into v_loc
  from public.stock_locations sl
  where sl.parent_tenant_id = p_tenant_id
    and sl.is_active = true
    and sl.kind = 'returns'::public.stock_location_kind
  order by sl.sort_order, sl.id
  limit 1;

  if v_loc is not null then
    return v_loc;
  end if;

  insert into public.stock_locations (
    parent_tenant_id, parent_location_id, code, name, kind,
    is_default, is_pickable, sort_order, is_active
  ) values (
    p_tenant_id, null, 'RETURNS', 'Returns', 'returns',
    false, false, 100, true
  )
  on conflict (parent_tenant_id, code) do update
    set kind = 'returns'::public.stock_location_kind,
        is_active = true,
        is_pickable = false
  returning id into v_loc;

  return v_loc;
end;
$function$;

GRANT ALL ON FUNCTION public.default_returns_stock_location_id(bigint) TO anon;

GRANT ALL ON FUNCTION public.default_returns_stock_location_id(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.default_returns_stock_location_id(bigint) TO service_role;
-- Per-tenant default stock location mechanism (ensure_default_stock_location + auto-create in default_putaway_stock_location_id + backfill)

begin;

-- 1. ensure_default_stock_location(p_tenant_id)
create or replace function public.ensure_default_stock_location(p_tenant_id bigint)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant public.tenants%rowtype;
  v_loc_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  select * into v_tenant
  from public.tenants
  where id = p_tenant_id;

  if not found then
    raise exception 'tenant % not found', p_tenant_id;
  end if;

  -- Stock locations live on parent (stock-owning) tenants only
  if v_tenant.parent_id is not null then
    return public.ensure_default_stock_location(v_tenant.parent_id);
  end if;

  -- Check if an active leaf location already exists for this parent tenant
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

  -- Create default leaf stock location for tenant
  insert into public.stock_locations (
    parent_tenant_id,
    name,
    code,
    kind,
    parent_location_id,
    is_pickable,
    is_default,
    is_active,
    sort_order
  ) values (
    p_tenant_id,
    'Main Warehouse',
    'MAIN',
    'shelf',
    null,
    true,
    true,
    true,
    10
  )
  returning id into v_loc_id;

  return v_loc_id;
end;
$$;

revoke all on function public.ensure_default_stock_location(bigint) from public;
grant execute on function public.ensure_default_stock_location(bigint) to authenticated;
grant execute on function public.ensure_default_stock_location(bigint) to service_role;

-- 2. Update default_putaway_stock_location_id to auto-create default location if none exists
create or replace function public.default_putaway_stock_location_id(p_tenant_id bigint)
returns bigint
language plpgsql
stable
security definer
set search_path = public
as $$
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
$$;

grant execute on function public.default_putaway_stock_location_id(bigint) to authenticated;
grant execute on function public.default_putaway_stock_location_id(bigint) to service_role;

-- 3. Backfill: ensure every existing parent tenant has a default stock location
do $$
declare
  r record;
begin
  for r in
    select t.id
    from public.tenants t
    where t.parent_id is null
    order by t.id
  loop
    perform public.ensure_default_stock_location(r.id);
  end loop;
end;
$$;

commit;

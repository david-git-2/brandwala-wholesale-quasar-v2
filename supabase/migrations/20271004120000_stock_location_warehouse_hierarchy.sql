-- Warehouse location hierarchy: warehouse → zone → shelf → level → bin (+ returns root)

begin;

drop function if exists public.upsert_stock_location(
  bigint, text, text, public.stock_location_kind, boolean, integer, boolean, boolean, bigint, bigint
);

drop function if exists public._validate_stock_location_nesting(
  public.stock_location_kind, bigint, bigint
);
drop function if exists public.ensure_default_stock_location(bigint);
drop function if exists public.default_returns_stock_location_id(bigint);

alter table public.stock_locations alter column kind drop default;

alter table public.stock_locations
  alter column kind type text using kind::text;

update public.stock_locations
set kind = case kind
  when 'box' then 'bin'
  when 'slot' then 'level'
  when 'shelf' then case when parent_location_id is null then 'warehouse' else 'shelf' end
  else kind
end;

update public.stock_locations
set name = case
  when code = 'MAIN' and kind = 'warehouse' then 'Main warehouse'
  else name
end;

-- Reparent levels that sit directly under warehouse/returns (old shelf → slot model)
do $$
declare
  r record;
  v_zone_id bigint;
  v_shelf_id bigint;
  v_zone_code text;
  v_shelf_code text;
begin
  for r in
    select l.id as level_id,
           l.parent_tenant_id,
           p.id as root_id,
           p.kind as root_kind
    from public.stock_locations l
    join public.stock_locations p on p.id = l.parent_location_id
    where l.kind = 'level'
      and p.kind in ('warehouse', 'returns')
  loop
    v_zone_code := 'MIG-ZONE-' || r.root_id;
    v_shelf_code := 'MIG-SHELF-' || r.root_id;

    insert into public.stock_locations (
      parent_tenant_id, parent_location_id, code, name, kind,
      is_pickable, is_default, is_active, sort_order
    ) values (
      r.parent_tenant_id, r.root_id, v_zone_code, 'Migration zone', 'zone',
      false, false, true, 90
    )
    on conflict (parent_tenant_id, code) do update
      set parent_location_id = r.root_id,
          kind = 'zone',
          is_active = true
    returning id into v_zone_id;

    if v_zone_id is null then
      select id into v_zone_id
      from public.stock_locations
      where parent_tenant_id = r.parent_tenant_id
        and code = v_zone_code;
    end if;

    insert into public.stock_locations (
      parent_tenant_id, parent_location_id, code, name, kind,
      is_pickable, is_default, is_active, sort_order
    ) values (
      r.parent_tenant_id, v_zone_id, v_shelf_code, 'Migration shelf', 'shelf',
      false, false, true, 91
    )
    on conflict (parent_tenant_id, code) do update
      set parent_location_id = v_zone_id,
          kind = 'shelf',
          is_active = true
    returning id into v_shelf_id;

    if v_shelf_id is null then
      select id into v_shelf_id
      from public.stock_locations
      where parent_tenant_id = r.parent_tenant_id
        and code = v_shelf_code;
    end if;

    update public.stock_locations
    set parent_location_id = v_shelf_id
    where id = r.level_id;
  end loop;
end $$;

drop type if exists public.stock_location_kind;

create type public.stock_location_kind as enum (
  'warehouse',
  'zone',
  'shelf',
  'level',
  'bin',
  'returns'
);

alter table public.stock_locations
  alter column kind type public.stock_location_kind
  using kind::public.stock_location_kind;

alter table public.stock_locations
  alter column kind set default 'bin'::public.stock_location_kind;

create or replace function public._validate_stock_location_nesting(
  p_kind public.stock_location_kind,
  p_parent_location_id bigint,
  p_parent_tenant_id bigint
)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_parent public.stock_locations%rowtype;
begin
  if p_kind in ('warehouse', 'returns') then
    if p_parent_location_id is not null then
      raise exception 'warehouse and returns must be top-level (no parent)';
    end if;
    return;
  end if;

  if p_parent_location_id is null then
    raise exception '% requires a parent location', p_kind;
  end if;

  select * into v_parent
  from public.stock_locations
  where id = p_parent_location_id;

  if not found then
    raise exception 'parent location not found';
  end if;

  if v_parent.parent_tenant_id <> p_parent_tenant_id then
    raise exception 'parent location belongs to another tenant';
  end if;

  if p_kind = 'zone' then
    if v_parent.kind not in ('warehouse', 'returns') then
      raise exception 'zone parent must be a warehouse or returns area';
    end if;
  elsif p_kind = 'shelf' then
    if v_parent.kind <> 'zone' then
      raise exception 'shelf parent must be a zone';
    end if;
  elsif p_kind = 'level' then
    if v_parent.kind <> 'shelf' then
      raise exception 'level parent must be a shelf';
    end if;
  elsif p_kind = 'bin' then
    if v_parent.kind <> 'level' then
      raise exception 'bin parent must be a level';
    end if;
  end if;
end;
$$;

create or replace function public.ensure_default_stock_location(p_tenant_id bigint)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
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
$$;

create or replace function public.default_returns_stock_location_id(p_tenant_id bigint)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
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
$$;

create or replace function public.upsert_stock_location(
  p_parent_tenant_id bigint,
  p_code text,
  p_name text,
  p_kind public.stock_location_kind default 'bin'::public.stock_location_kind,
  p_is_pickable boolean default true,
  p_sort_order integer default 0,
  p_is_active boolean default true,
  p_is_default boolean default false,
  p_id bigint default null,
  p_parent_location_id bigint default null
)
returns public.stock_locations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_name text;
  v_row public.stock_locations%rowtype;
  v_action text;
  v_is_leaf boolean;
  v_want_default boolean;
begin
  perform public._assert_parent_warehouse_tenant(p_parent_tenant_id);

  v_action := case when p_id is null then 'create' else 'edit' end;

  if not (
    public.user_can_manage_parent_tenant(p_parent_tenant_id)
    or public.membership_has_module_action(p_parent_tenant_id, 'global_stock_location', v_action)
  ) then
    raise exception 'not allowed';
  end if;

  v_code := upper(trim(coalesce(p_code, '')));
  v_name := trim(coalesce(p_name, ''));

  if length(v_code) = 0 then
    raise exception 'code is required';
  end if;
  if length(v_name) = 0 then
    raise exception 'name is required';
  end if;
  if p_kind is null then
    raise exception 'kind is required';
  end if;

  perform public._validate_stock_location_nesting(
    p_kind, p_parent_location_id, p_parent_tenant_id
  );

  if p_id is not null and p_parent_location_id = p_id then
    raise exception 'location cannot be its own parent';
  end if;

  v_want_default := coalesce(p_is_default, false) and coalesce(p_is_active, true);

  if p_id is null then
    if v_want_default then
      update public.stock_locations
      set is_default = false
      where parent_tenant_id = p_parent_tenant_id
        and is_default = true;
    end if;

    insert into public.stock_locations (
      parent_tenant_id,
      parent_location_id,
      code,
      name,
      kind,
      is_default,
      is_pickable,
      sort_order,
      is_active
    )
    values (
      p_parent_tenant_id,
      p_parent_location_id,
      v_code,
      v_name,
      p_kind,
      v_want_default,
      coalesce(p_is_pickable, true),
      coalesce(p_sort_order, 0),
      coalesce(p_is_active, true)
    )
    returning * into v_row;

    if p_parent_location_id is not null then
      update public.stock_locations
      set is_default = false
      where id = p_parent_location_id
        and is_default = true;
    end if;
  else
    update public.stock_locations
    set
      parent_location_id = p_parent_location_id,
      code = v_code,
      name = v_name,
      kind = p_kind,
      is_pickable = coalesce(p_is_pickable, is_pickable),
      sort_order = coalesce(p_sort_order, sort_order),
      is_active = coalesce(p_is_active, is_active)
    where id = p_id
      and parent_tenant_id = p_parent_tenant_id
    returning * into v_row;

    if not found then
      raise exception 'location not found';
    end if;

    v_is_leaf := public._stock_location_is_leaf(v_row.id);

    if v_want_default and not v_is_leaf then
      raise exception 'only leaf locations can be the default put-away';
    end if;

    if v_want_default then
      update public.stock_locations
      set is_default = false
      where parent_tenant_id = p_parent_tenant_id
        and is_default = true
        and id <> p_id;

      update public.stock_locations
      set is_default = true
      where id = p_id;
    elsif coalesce(p_is_default, false) = false and coalesce(p_is_active, true) = false then
      update public.stock_locations
      set is_default = false
      where id = p_id;
    elsif p_is_default is not null and p_is_default = false then
      update public.stock_locations
      set is_default = false
      where id = p_id;
    end if;

    if p_parent_location_id is not null then
      update public.stock_locations
      set is_default = false
      where id = p_parent_location_id
        and is_default = true;
    end if;
  end if;

  if not exists (
    select 1 from public.stock_locations l
    where l.parent_tenant_id = p_parent_tenant_id
      and l.is_default = true
      and l.is_active = true
      and public._stock_location_is_leaf(l.id)
  ) then
    update public.stock_locations
    set is_default = true
    where id = (
      select l.id from public.stock_locations l
      where l.parent_tenant_id = p_parent_tenant_id
        and l.is_active = true
        and public._stock_location_is_leaf(l.id)
      order by l.sort_order, l.id
      limit 1
    );
  end if;

  select * into v_row from public.stock_locations where id = v_row.id;
  return v_row;
end;
$$;

commit;

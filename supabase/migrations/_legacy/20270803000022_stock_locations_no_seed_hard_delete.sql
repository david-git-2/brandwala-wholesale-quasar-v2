-- Remove location seeder; allow hard-delete of shelves/slots/boxes (cascade children)

begin;

-- ---------------------------------------------------------------------------
-- Parent FK: cascade so deleting a shelf removes slots/boxes under it
-- ---------------------------------------------------------------------------
alter table public.stock_locations
  drop constraint if exists stock_locations_parent_location_id_fkey;

alter table public.stock_locations
  add constraint stock_locations_parent_location_id_fkey
  foreign key (parent_location_id)
  references public.stock_locations(id)
  on delete cascade;

-- ---------------------------------------------------------------------------
-- Drop seeder; list no longer auto-creates MAIN/RETURNS
-- ---------------------------------------------------------------------------
drop function if exists public.ensure_default_stock_locations(bigint);

create or replace function public.list_stock_locations(
  p_parent_tenant_id bigint,
  p_include_inactive boolean default false
)
returns setof public.stock_locations
language plpgsql
security definer
set search_path = public
as $$
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
$$;

-- ---------------------------------------------------------------------------
-- Upsert: default fallback without MAIN seed preference
-- ---------------------------------------------------------------------------
create or replace function public.upsert_stock_location(
  p_parent_tenant_id bigint,
  p_code text,
  p_name text,
  p_kind public.stock_location_kind default 'box',
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

  -- Optional: keep one leaf default if any leaves remain
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

-- ---------------------------------------------------------------------------
-- delete_stock_location (cascades children via FK)
-- ---------------------------------------------------------------------------
create or replace function public.delete_stock_location(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
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
$$;

revoke all on function public.delete_stock_location(bigint) from public;
grant execute on function public.delete_stock_location(bigint) to authenticated;

insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values ('global_stock_location', 'delete', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true,
  tenant_configurable = true;

commit;

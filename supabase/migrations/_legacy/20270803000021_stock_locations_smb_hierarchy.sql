-- SMB hierarchy for stock_locations: shelf → slot → box (+ returns area)

begin;

-- ---------------------------------------------------------------------------
-- parent_location_id
-- ---------------------------------------------------------------------------
alter table public.stock_locations
  add column if not exists parent_location_id bigint
    references public.stock_locations(id) on delete restrict;

create index if not exists stock_locations_parent_location_idx
  on public.stock_locations (parent_location_id);

-- ---------------------------------------------------------------------------
-- Enum remap: zone/bin/staging/returns → shelf/slot/box/returns
-- Drop dependent RPCs first (signature uses enum)
-- ---------------------------------------------------------------------------
drop function if exists public.upsert_stock_location(
  bigint, text, text, public.stock_location_kind, boolean, integer, boolean, boolean, bigint
);

alter table public.stock_locations alter column kind drop default;

alter table public.stock_locations
  alter column kind type text using kind::text;

update public.stock_locations
set kind = case kind
  when 'zone' then 'shelf'
  when 'bin' then 'box'
  when 'staging' then 'slot'
  else kind
end;

-- Prefer MAIN as shelf after remap
update public.stock_locations
set kind = 'shelf',
    name = case when name in ('Main', 'MAIN') then 'Main shelf' else name end
where code = 'MAIN';

drop type if exists public.stock_location_kind;

create type public.stock_location_kind as enum (
  'shelf',
  'slot',
  'box',
  'returns'
);

alter table public.stock_locations
  alter column kind type public.stock_location_kind
  using kind::public.stock_location_kind;

alter table public.stock_locations
  alter column kind set default 'box'::public.stock_location_kind;

-- ---------------------------------------------------------------------------
-- Helpers: leaf + parent/kind validation
-- ---------------------------------------------------------------------------
create or replace function public._stock_location_is_leaf(p_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1 from public.stock_locations c
    where c.parent_location_id = p_id
      and c.is_active = true
  );
$$;

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
  if p_kind in ('shelf', 'returns') then
    if p_parent_location_id is not null then
      raise exception 'shelf and returns must be top-level (no parent)';
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

  if p_kind = 'slot' then
    if v_parent.kind not in ('shelf', 'returns') then
      raise exception 'slot parent must be a shelf or returns area';
    end if;
  elsif p_kind = 'box' then
    if v_parent.kind <> 'slot' then
      raise exception 'box parent must be a slot';
    end if;
  end if;
end;
$$;

revoke all on function public._stock_location_is_leaf(bigint) from public;
revoke all on function public._validate_stock_location_nesting(
  public.stock_location_kind, bigint, bigint
) from public;

-- ---------------------------------------------------------------------------
-- ensure_default_stock_locations
-- ---------------------------------------------------------------------------
create or replace function public.ensure_default_stock_locations(p_parent_tenant_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public._assert_parent_warehouse_tenant(p_parent_tenant_id);

  if not public._can_view_stock_locations(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  insert into public.stock_locations (
    parent_tenant_id, parent_location_id, code, name, kind,
    is_default, is_pickable, sort_order, is_active
  )
  values
    (p_parent_tenant_id, null, 'MAIN', 'Main shelf', 'shelf', true, true, 0, true),
    (p_parent_tenant_id, null, 'RETURNS', 'Returns', 'returns', false, false, 100, true)
  on conflict (parent_tenant_id, code) do nothing;

  update public.stock_locations
  set kind = 'shelf',
      name = case when name in ('Main', 'MAIN', 'Main shelf') then 'Main shelf' else name end,
      parent_location_id = null
  where parent_tenant_id = p_parent_tenant_id
    and code = 'MAIN';

  update public.stock_locations
  set kind = 'returns',
      parent_location_id = null
  where parent_tenant_id = p_parent_tenant_id
    and code = 'RETURNS';

  if not exists (
    select 1 from public.stock_locations
    where parent_tenant_id = p_parent_tenant_id
      and is_default = true
      and is_active = true
  ) then
    update public.stock_locations
    set is_default = true
    where parent_tenant_id = p_parent_tenant_id
      and code = 'MAIN'
      and is_active = true
      and public._stock_location_is_leaf(id);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- list_stock_locations (unchanged contract; includes parent_location_id via *)
-- ---------------------------------------------------------------------------
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

  perform public.ensure_default_stock_locations(p_parent_tenant_id);

  return query
  select l.*
  from public.stock_locations l
  where l.parent_tenant_id = p_parent_tenant_id
    and (p_include_inactive or l.is_active = true)
  order by l.sort_order asc, l.code asc, l.id asc;
end;
$$;

-- ---------------------------------------------------------------------------
-- upsert_stock_location (new signature with parent)
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

  -- After create/update, leaf status may change; compute intended default
  v_want_default := coalesce(p_is_default, false) and coalesce(p_is_active, true);

  if p_id is null then
    -- new row is always a leaf until children exist
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

    -- Parent is no longer a leaf — strip its default
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

  -- Ensure one active leaf default remains
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
      order by
        case when l.code = 'MAIN' then 0 else 1 end,
        l.sort_order,
        l.id
      limit 1
    );
  end if;

  select * into v_row from public.stock_locations where id = v_row.id;
  return v_row;
end;
$$;

revoke all on function public.upsert_stock_location(
  bigint, text, text, public.stock_location_kind, boolean, integer, boolean, boolean, bigint, bigint
) from public;
grant execute on function public.upsert_stock_location(
  bigint, text, text, public.stock_location_kind, boolean, integer, boolean, boolean, bigint, bigint
) to authenticated;

-- ---------------------------------------------------------------------------
-- set_default_stock_location — leaf only
-- ---------------------------------------------------------------------------
create or replace function public.set_default_stock_location(p_id bigint)
returns public.stock_locations
language plpgsql
security definer
set search_path = public
as $$
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
$$;

commit;

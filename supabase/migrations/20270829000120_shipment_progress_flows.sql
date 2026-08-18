-- Shipment Progress Flows
-- Replace the single tenant-wide shipment_progress ladder with multiple
-- selectable flows per parent tenant. Keep progress_tag_id as current stage.

begin;

-- ---------------------------------------------------------------------------
-- 1. Flow tables
-- ---------------------------------------------------------------------------

create table if not exists public.shipment_progress_flows (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  slug text not null,
  is_active boolean not null default true,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

create unique index if not exists shipment_progress_flows_tenant_slug_key
  on public.shipment_progress_flows(tenant_id, slug);

create unique index if not exists shipment_progress_flows_one_default_per_tenant
  on public.shipment_progress_flows(tenant_id)
  where is_default = true;

create table if not exists public.shipment_progress_flow_stages (
  id bigserial primary key,
  flow_id bigint not null references public.shipment_progress_flows(id) on delete cascade,
  tag_id bigint not null references public.tags(id) on delete restrict,
  sort_order integer not null default 1,
  created_at timestamptz not null default now()
);

create unique index if not exists shipment_progress_flow_stages_flow_tag_key
  on public.shipment_progress_flow_stages(flow_id, tag_id);

create unique index if not exists shipment_progress_flow_stages_flow_sort_key
  on public.shipment_progress_flow_stages(flow_id, sort_order);

alter table public.shipment_progress_flows enable row level security;
alter table public.shipment_progress_flow_stages enable row level security;

drop policy if exists shipment_progress_flows_all on public.shipment_progress_flows;
create policy shipment_progress_flows_all on public.shipment_progress_flows
  for all to authenticated
  using (public.user_can_manage_parent_tenant(tenant_id))
  with check (public.user_can_manage_parent_tenant(tenant_id));

drop policy if exists shipment_progress_flow_stages_all on public.shipment_progress_flow_stages;
create policy shipment_progress_flow_stages_all on public.shipment_progress_flow_stages
  for all to authenticated
  using (
    exists (
      select 1
      from public.shipment_progress_flows f
      where f.id = flow_id
        and public.user_can_manage_parent_tenant(f.tenant_id)
    )
  )
  with check (
    exists (
      select 1
      from public.shipment_progress_flows f
      where f.id = flow_id
        and public.user_can_manage_parent_tenant(f.tenant_id)
    )
  );

grant select, insert, update, delete on public.shipment_progress_flows to authenticated;
grant usage, select on sequence public.shipment_progress_flows_id_seq to authenticated;
grant select, insert, update, delete on public.shipment_progress_flow_stages to authenticated;
grant usage, select on sequence public.shipment_progress_flow_stages_id_seq to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Shipment FK -> chosen flow
-- ---------------------------------------------------------------------------

alter table public.global_shipments
  add column if not exists progress_flow_id bigint references public.shipment_progress_flows(id) on delete set null;

create index if not exists global_shipments_progress_flow_idx
  on public.global_shipments(progress_flow_id);

-- ---------------------------------------------------------------------------
-- 3. Backfill one default flow per tenant from existing shipment_progress tags
-- ---------------------------------------------------------------------------

insert into public.shipment_progress_flows (tenant_id, name, slug, is_active, is_default)
select distinct
  t.tenant_id,
  'Default flow',
  'default-flow',
  true,
  true
from public.tags t
where t.group_name = 'shipment_progress'
  and t.tenant_id is not null
on conflict (tenant_id, slug) do update set
  is_active = excluded.is_active,
  is_default = true;

insert into public.shipment_progress_flow_stages (flow_id, tag_id, sort_order)
select
  f.id,
  t.id,
  row_number() over (
    partition by f.id
    order by t.sort_order nulls last, t.name, t.id
  )::integer as sort_order
from public.shipment_progress_flows f
join public.tags t
  on t.tenant_id = f.tenant_id
 and t.group_name = 'shipment_progress'
where f.slug = 'default-flow'
on conflict (flow_id, tag_id) do update set
  sort_order = excluded.sort_order;

update public.global_shipments gs
set progress_flow_id = f.id
from public.shipment_progress_flows f
where f.tenant_id = gs.parent_tenant_id
  and f.slug = 'default-flow'
  and gs.progress_flow_id is null;

-- ---------------------------------------------------------------------------
-- 4. Flow listing / CRUD RPCs
-- ---------------------------------------------------------------------------

create or replace function public.list_shipment_progress_flows(
  p_tenant_id bigint,
  p_include_archived boolean default false
)
returns table (
  id bigint,
  tenant_id bigint,
  name text,
  slug text,
  is_active boolean,
  is_default boolean,
  created_at timestamptz,
  stage_count bigint
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  return query
  select
    f.id,
    f.tenant_id,
    f.name,
    f.slug,
    f.is_active,
    f.is_default,
    f.created_at,
    count(s.id) as stage_count
  from public.shipment_progress_flows f
  left join public.shipment_progress_flow_stages s on s.flow_id = f.id
  where f.tenant_id = p_tenant_id
    and (p_include_archived or f.is_active = true)
  group by f.id
  order by f.is_default desc, f.name asc;
end;
$$;

grant execute on function public.list_shipment_progress_flows(bigint, boolean) to authenticated;

create or replace function public.create_shipment_progress_flow(
  p_tenant_id bigint,
  p_name text
)
returns public.shipment_progress_flows
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slug text;
  v_result public.shipment_progress_flows;
  v_has_default boolean;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_name is null or trim(p_name) = '' then
    raise exception 'name is required';
  end if;

  v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));

  select exists(
    select 1
    from public.shipment_progress_flows
    where tenant_id = p_tenant_id
      and is_default = true
  ) into v_has_default;

  insert into public.shipment_progress_flows (
    tenant_id, name, slug, is_active, is_default
  )
  values (
    p_tenant_id,
    trim(p_name),
    v_slug,
    true,
    not v_has_default
  )
  returning * into v_result;

  return v_result;
end;
$$;

grant execute on function public.create_shipment_progress_flow(bigint, text) to authenticated;

create or replace function public.update_shipment_progress_flow(
  p_flow_id bigint,
  p_name text default null
)
returns public.shipment_progress_flows
language plpgsql
security definer
set search_path = public
as $$
declare
  v_flow public.shipment_progress_flows;
  v_slug text;
begin
  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id
  for update;

  if not found then
    raise exception 'flow not found';
  end if;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_name is null or trim(p_name) = '' then
    return v_flow;
  end if;

  v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));

  update public.shipment_progress_flows
  set
    name = trim(p_name),
    slug = v_slug
  where id = p_flow_id
  returning * into v_flow;

  return v_flow;
end;
$$;

grant execute on function public.update_shipment_progress_flow(bigint, text) to authenticated;

create or replace function public.archive_shipment_progress_flow(
  p_flow_id bigint,
  p_archive boolean default true
)
returns public.shipment_progress_flows
language plpgsql
security definer
set search_path = public
as $$
declare
  v_flow public.shipment_progress_flows;
begin
  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id
  for update;

  if not found then
    raise exception 'flow not found';
  end if;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_archive = true and exists (
    select 1 from public.global_shipments gs
    where gs.progress_flow_id = p_flow_id
  ) then
    raise exception 'flow is in use by one or more shipments and cannot be archived';
  end if;

  update public.shipment_progress_flows
  set
    is_active = not p_archive,
    is_default = case when p_archive then false else is_default end
  where id = p_flow_id
  returning * into v_flow;

  return v_flow;
end;
$$;

grant execute on function public.archive_shipment_progress_flow(bigint, boolean) to authenticated;

create or replace function public.set_default_shipment_progress_flow(
  p_flow_id bigint
)
returns public.shipment_progress_flows
language plpgsql
security definer
set search_path = public
as $$
declare
  v_flow public.shipment_progress_flows;
begin
  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id
  for update;

  if not found then
    raise exception 'flow not found';
  end if;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  update public.shipment_progress_flows
  set is_default = false
  where tenant_id = v_flow.tenant_id;

  update public.shipment_progress_flows
  set is_default = true, is_active = true
  where id = p_flow_id
  returning * into v_flow;

  return v_flow;
end;
$$;

grant execute on function public.set_default_shipment_progress_flow(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Stage listing / CRUD
-- ---------------------------------------------------------------------------

create or replace function public.list_shipment_progress_flow_stages(
  p_flow_id bigint,
  p_include_archived boolean default true
)
returns table (
  flow_stage_id bigint,
  flow_id bigint,
  tag_id bigint,
  sort_order integer,
  name text,
  slug text,
  color text,
  is_active boolean
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_flow public.shipment_progress_flows;
begin
  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id;

  if not found then
    raise exception 'flow not found';
  end if;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  return query
  select
    s.id as flow_stage_id,
    s.flow_id,
    t.id as tag_id,
    s.sort_order,
    t.name,
    t.slug,
    t.color,
    t.is_active
  from public.shipment_progress_flow_stages s
  join public.tags t on t.id = s.tag_id
  where s.flow_id = p_flow_id
    and (p_include_archived or t.is_active = true)
  order by s.sort_order asc, t.name asc;
end;
$$;

grant execute on function public.list_shipment_progress_flow_stages(bigint, boolean) to authenticated;

create or replace function public.create_shipment_progress_flow_stage(
  p_flow_id bigint,
  p_name text,
  p_color text default '#64748b',
  p_sort_order integer default null
)
returns table (
  flow_stage_id bigint,
  flow_id bigint,
  tag_id bigint,
  sort_order integer,
  name text,
  slug text,
  color text,
  is_active boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_flow public.shipment_progress_flows;
  v_slug text;
  v_tag public.tags;
  v_sort integer;
begin
  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id;

  if not found then
    raise exception 'flow not found';
  end if;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_name is null or trim(p_name) = '' then
    raise exception 'name is required';
  end if;

  v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));

  if p_sort_order is null then
    select coalesce(max(sort_order), 0) + 1
    into v_sort
    from public.shipment_progress_flow_stages
    where flow_id = p_flow_id;
  else
    v_sort := p_sort_order;
  end if;

  insert into public.tags (
    tenant_id, name, slug, color, type, group_name, sort_order, is_active, is_system, created_by_email
  )
  values (
    v_flow.tenant_id,
    trim(p_name),
    v_slug,
    coalesce(p_color, '#64748b'),
    'shipment_progress',
    'shipment_progress',
    v_sort,
    true,
    false,
    'tenant-settings'
  )
  returning * into v_tag;

  return query
  with inserted as (
    insert into public.shipment_progress_flow_stages(flow_id, tag_id, sort_order)
    values (p_flow_id, v_tag.id, v_sort)
    returning id, flow_id, tag_id, sort_order
  )
  select
    i.id,
    i.flow_id,
    i.tag_id,
    i.sort_order,
    v_tag.name,
    v_tag.slug,
    v_tag.color,
    v_tag.is_active
  from inserted i;
end;
$$;

grant execute on function public.create_shipment_progress_flow_stage(bigint, text, text, integer) to authenticated;

create or replace function public.update_shipment_progress_flow_stage(
  p_flow_stage_id bigint,
  p_name text default null,
  p_color text default null
)
returns table (
  flow_stage_id bigint,
  flow_id bigint,
  tag_id bigint,
  sort_order integer,
  name text,
  slug text,
  color text,
  is_active boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stage public.shipment_progress_flow_stages;
  v_flow public.shipment_progress_flows;
  v_tag public.tags;
  v_slug text;
begin
  select * into v_stage
  from public.shipment_progress_flow_stages
  where id = p_flow_stage_id
  for update;

  if not found then
    raise exception 'flow stage not found';
  end if;

  select * into v_flow
  from public.shipment_progress_flows
  where id = v_stage.flow_id;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  select * into v_tag
  from public.tags
  where id = v_stage.tag_id
  for update;

  if p_name is not null and trim(p_name) <> '' then
    v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));
  else
    v_slug := v_tag.slug;
  end if;

  update public.tags
  set
    name = coalesce(nullif(trim(p_name), ''), name),
    slug = v_slug,
    color = coalesce(p_color, color)
  where id = v_stage.tag_id
  returning * into v_tag;

  return query
  select
    v_stage.id,
    v_stage.flow_id,
    v_stage.tag_id,
    v_stage.sort_order,
    v_tag.name,
    v_tag.slug,
    v_tag.color,
    v_tag.is_active;
end;
$$;

grant execute on function public.update_shipment_progress_flow_stage(bigint, text, text) to authenticated;

create or replace function public.archive_shipment_progress_flow_stage(
  p_flow_stage_id bigint,
  p_archive boolean default true
)
returns table (
  flow_stage_id bigint,
  flow_id bigint,
  tag_id bigint,
  sort_order integer,
  name text,
  slug text,
  color text,
  is_active boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stage public.shipment_progress_flow_stages;
  v_flow public.shipment_progress_flows;
  v_tag public.tags;
begin
  select * into v_stage
  from public.shipment_progress_flow_stages
  where id = p_flow_stage_id
  for update;

  if not found then
    raise exception 'flow stage not found';
  end if;

  select * into v_flow
  from public.shipment_progress_flows
  where id = v_stage.flow_id;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_archive = true and exists (
    select 1
    from public.global_shipments gs
    where gs.progress_tag_id = v_stage.tag_id
  ) then
    raise exception 'stage is in use by one or more shipments and cannot be archived';
  end if;

  update public.tags
  set is_active = not p_archive
  where id = v_stage.tag_id
  returning * into v_tag;

  return query
  select
    v_stage.id,
    v_stage.flow_id,
    v_stage.tag_id,
    v_stage.sort_order,
    v_tag.name,
    v_tag.slug,
    v_tag.color,
    v_tag.is_active;
end;
$$;

grant execute on function public.archive_shipment_progress_flow_stage(bigint, boolean) to authenticated;

create or replace function public.reorder_shipment_progress_flow_stages(
  p_flow_id bigint,
  p_flow_stage_ids bigint[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_flow public.shipment_progress_flows;
  v_idx integer;
  v_stage_id bigint;
begin
  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id;

  if not found then
    raise exception 'flow not found';
  end if;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  for v_idx in 1..array_length(p_flow_stage_ids, 1) loop
    v_stage_id := p_flow_stage_ids[v_idx];

    update public.shipment_progress_flow_stages
    set sort_order = v_idx
    where id = v_stage_id
      and flow_id = p_flow_id;
  end loop;
end;
$$;

grant execute on function public.reorder_shipment_progress_flow_stages(bigint, bigint[]) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Shipment selection RPCs
-- ---------------------------------------------------------------------------

create or replace function public.set_shipment_progress_flow(
  p_shipment_id bigint,
  p_flow_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_flow public.shipment_progress_flows%rowtype;
  v_first_stage_tag_id bigint;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id;

  if not found then
    raise exception 'flow not found';
  end if;

  if v_flow.tenant_id <> v_ship.parent_tenant_id then
    raise exception 'flow tenant mismatch';
  end if;

  if not public.has_active_tenant_membership(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if v_ship.progress_tag_id is not null and not exists (
    select 1
    from public.shipment_progress_flow_stages s
    where s.flow_id = p_flow_id
      and s.tag_id = v_ship.progress_tag_id
  ) then
    select s.tag_id into v_first_stage_tag_id
    from public.shipment_progress_flow_stages s
    join public.tags t on t.id = s.tag_id
    where s.flow_id = p_flow_id
      and t.is_active = true
    order by s.sort_order asc
    limit 1;

    update public.global_shipments
    set
      progress_flow_id = p_flow_id,
      progress_tag_id = v_first_stage_tag_id,
      updated_at = now()
    where id = p_shipment_id;
  else
    update public.global_shipments
    set
      progress_flow_id = p_flow_id,
      updated_at = now()
    where id = p_shipment_id;
  end if;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'progress_flow_id', p_flow_id
  );
end;
$$;

grant execute on function public.set_shipment_progress_flow(bigint, bigint) to authenticated;

create or replace function public.set_shipment_progress_stage(
  p_shipment_id bigint,
  p_tag_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_tag public.tags%rowtype;
  v_progress jsonb := null;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.has_active_tenant_membership(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_tag_id is null then
    update public.global_shipments
    set progress_tag_id = null, updated_at = now()
    where id = p_shipment_id;

    return jsonb_build_object(
      'shipment_id', p_shipment_id,
      'progress_tag', null
    );
  end if;

  select * into v_tag from public.tags where id = p_tag_id;
  if not found then
    raise exception 'tag not found';
  end if;

  if v_tag.group_name is distinct from 'shipment_progress' then
    raise exception 'tag must be in group shipment_progress';
  end if;

  if not exists (
    select 1
    from public.shipment_progress_flow_stages s
    where s.flow_id = v_ship.progress_flow_id
      and s.tag_id = p_tag_id
  ) then
    raise exception 'tag does not belong to shipment flow';
  end if;

  update public.global_shipments
  set progress_tag_id = p_tag_id, updated_at = now()
  where id = p_shipment_id;

  v_progress := jsonb_build_object(
    'id', v_tag.id,
    'name', v_tag.name,
    'slug', v_tag.slug,
    'group_name', v_tag.group_name,
    'sort_order', v_tag.sort_order,
    'color', v_tag.color
  );

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'progress_tag', v_progress
  );
end;
$$;

grant execute on function public.set_shipment_progress_stage(bigint, bigint) to authenticated;

-- Compatibility wrapper for current frontend callers
create or replace function public.set_global_shipment_progress_tag(
  p_shipment_id bigint,
  p_tag_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.set_shipment_progress_stage(p_shipment_id, p_tag_id);
end;
$$;

grant execute on function public.set_global_shipment_progress_tag(bigint, bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Public tracking now returns shipment-selected flow only
-- ---------------------------------------------------------------------------

create or replace function public.get_shipment_public_status(
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_progress_tag jsonb := null;
  v_progress_list jsonb := '[]'::jsonb;
  v_flow jsonb := null;
  v_tag public.tags%rowtype;
begin
  if p_token is null or trim(p_token) = '' then
    return null;
  end if;

  select * into v_ship
  from public.global_shipments
  where public_tracking_token = p_token
  limit 1;

  if not found then
    return null;
  end if;

  select jsonb_build_object(
    'id', f.id,
    'name', f.name,
    'slug', f.slug,
    'is_default', f.is_default
  )
  into v_flow
  from public.shipment_progress_flows f
  where f.id = v_ship.progress_flow_id;

  if v_ship.progress_tag_id is not null then
    select * into v_tag
    from public.tags
    where id = v_ship.progress_tag_id
      and is_active = true
    limit 1;

    if found then
      v_progress_tag := jsonb_build_object(
        'id', v_tag.id,
        'name', v_tag.name,
        'color', v_tag.color,
        'sort_order', v_tag.sort_order
      );
    end if;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', t.id,
        'name', t.name,
        'color', t.color,
        'sort_order', s.sort_order
      )
      order by s.sort_order asc
    ),
    '[]'::jsonb
  )
  into v_progress_list
  from public.shipment_progress_flow_stages s
  join public.tags t on t.id = s.tag_id
  where s.flow_id = v_ship.progress_flow_id
    and t.is_active = true;

  return jsonb_build_object(
    'id', v_ship.id,
    'name', v_ship.name,
    'status', v_ship.status,
    'progress_flow', v_flow,
    'progress_tag', v_progress_tag,
    'progress_tags', v_progress_list,
    'updated_at', v_ship.updated_at
  );
end;
$$;

grant execute on function public.get_shipment_public_status(text) to anon, authenticated;

commit;

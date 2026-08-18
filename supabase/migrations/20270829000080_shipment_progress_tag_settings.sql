-- Shipment Progress Tag Settings
-- Harden ensure-once seeding and add tenant CRUD RPCs for shipment_progress tags.

-- ---------------------------------------------------------------------------
-- 1. Replace ensure RPC: seed defaults only for tags that don't exist yet.
--    Never overwrite user-customized name/color/sort_order.
-- ---------------------------------------------------------------------------

create or replace function public.ensure_shipment_progress_tags(p_tenant_id bigint)
returns setof public.tags
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email constant text := 'system@brandwala.local';
  v_slug text;
  v_name text;
  v_sort integer;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id required';
  end if;

  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  -- Seed defaults only if they don't already exist (never overwrite user customizations)
  for v_slug, v_name, v_sort in
    select *
    from (
      values
        ('uk-warehouse'::text, 'UK Warehouse'::text, 1),
        ('on-flight',          'On flight',          2),
        ('airport',            'Airport',            3),
        ('customs-clearance',  'Customs clearance',  4),
        ('bd-warehouse',       'BD Warehouse',       5)
    ) as s(slug, name, sort_order)
  loop
    if not exists (
      select 1 from public.tags t
      where t.tenant_id = p_tenant_id
        and t.slug = v_slug
        and t.group_name = 'shipment_progress'
    ) then
      insert into public.tags (
        tenant_id, name, slug, color, type, group_name, sort_order, created_by_email
      )
      values (
        p_tenant_id,
        v_name,
        v_slug,
        '#64748b',
        'shipment_progress',
        'shipment_progress',
        v_sort,
        v_email
      );
    end if;
  end loop;

  return query
    select t.*
    from public.tags t
    where t.tenant_id = p_tenant_id
      and t.group_name = 'shipment_progress'
    order by t.sort_order nulls last, t.name;
end;
$$;

grant execute on function public.ensure_shipment_progress_tags(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. List shipment_progress tags for a tenant (active + archived)
-- ---------------------------------------------------------------------------

create or replace function public.list_shipment_progress_tags(
  p_tenant_id bigint,
  p_include_archived boolean default false
)
returns setof public.tags
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
    select t.*
    from public.tags t
    where t.tenant_id = p_tenant_id
      and t.group_name = 'shipment_progress'
      and (p_include_archived or t.is_active = true)
    order by t.sort_order nulls last, t.name;
end;
$$;

grant execute on function public.list_shipment_progress_tags(bigint, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Create a new tenant shipment_progress tag
-- ---------------------------------------------------------------------------

create or replace function public.create_shipment_progress_tag(
  p_tenant_id bigint,
  p_name      text,
  p_color     text default '#64748b',
  p_sort_order integer default null
)
returns public.tags
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slug text;
  v_max_sort integer;
  v_result public.tags;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_name is null or trim(p_name) = '' then
    raise exception 'name is required';
  end if;

  -- Slugify name
  v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));

  -- Guard duplicate slug within tenant progress group
  if exists (
    select 1 from public.tags t
    where t.tenant_id = p_tenant_id
      and t.group_name = 'shipment_progress'
      and t.slug = v_slug
  ) then
    raise exception 'a progress tag with this name already exists';
  end if;

  -- Default sort_order to end of list
  if p_sort_order is null then
    select coalesce(max(t.sort_order), 0) + 1
    into v_max_sort
    from public.tags t
    where t.tenant_id = p_tenant_id
      and t.group_name = 'shipment_progress';
  else
    v_max_sort := p_sort_order;
  end if;

  insert into public.tags (
    tenant_id, name, slug, color, type, group_name, sort_order, is_active, is_system, created_by_email
  )
  values (
    p_tenant_id,
    trim(p_name),
    v_slug,
    coalesce(p_color, '#64748b'),
    'shipment_progress',
    'shipment_progress',
    v_max_sort,
    true,
    false,
    'tenant-settings'
  )
  returning * into v_result;

  return v_result;
end;
$$;

grant execute on function public.create_shipment_progress_tag(bigint, text, text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Update a shipment_progress tag (name, color, sort_order)
-- ---------------------------------------------------------------------------

create or replace function public.update_shipment_progress_tag(
  p_tag_id     bigint,
  p_name       text   default null,
  p_color      text   default null,
  p_sort_order integer default null
)
returns public.tags
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tag public.tags;
  v_result public.tags;
  v_new_slug text;
begin
  select * into v_tag
  from public.tags
  where id = p_tag_id
  for update;

  if not found then
    raise exception 'tag not found';
  end if;

  if v_tag.group_name is distinct from 'shipment_progress' then
    raise exception 'tag is not a shipment_progress tag';
  end if;

  if not public.has_active_tenant_membership(v_tag.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if v_tag.is_system then
    raise exception 'system tags cannot be updated via this RPC';
  end if;

  -- Compute new slug if name changed
  if p_name is not null and trim(p_name) <> '' then
    v_new_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));
    -- Guard duplicate slug (exclude self)
    if exists (
      select 1 from public.tags t
      where t.tenant_id = v_tag.tenant_id
        and t.group_name = 'shipment_progress'
        and t.slug = v_new_slug
        and t.id <> p_tag_id
    ) then
      raise exception 'a progress tag with this name already exists';
    end if;
  else
    v_new_slug := v_tag.slug;
  end if;

  update public.tags
  set
    name       = coalesce(nullif(trim(p_name), ''), name),
    slug       = v_new_slug,
    color      = coalesce(p_color, color),
    sort_order = coalesce(p_sort_order, sort_order),
    updated_at = now()
  where id = p_tag_id
  returning * into v_result;

  return v_result;
end;
$$;

grant execute on function public.update_shipment_progress_tag(bigint, text, text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Archive / restore a shipment_progress tag
--    Cannot archive a tag that is currently in use by at least one shipment.
-- ---------------------------------------------------------------------------

create or replace function public.archive_shipment_progress_tag(
  p_tag_id  bigint,
  p_archive boolean default true
)
returns public.tags
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tag public.tags;
  v_result public.tags;
begin
  select * into v_tag
  from public.tags
  where id = p_tag_id
  for update;

  if not found then
    raise exception 'tag not found';
  end if;

  if v_tag.group_name is distinct from 'shipment_progress' then
    raise exception 'tag is not a shipment_progress tag';
  end if;

  if not public.has_active_tenant_membership(v_tag.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  -- Block archive if currently assigned to any active shipment
  if p_archive = true then
    if exists (
      select 1 from public.global_shipments gs
      where gs.progress_tag_id = p_tag_id
        and gs.deleted_at is null
    ) then
      raise exception 'tag is in use by one or more shipments and cannot be archived';
    end if;
  end if;

  update public.tags
  set
    is_active  = not p_archive,
    updated_at = now()
  where id = p_tag_id
  returning * into v_result;

  return v_result;
end;
$$;

grant execute on function public.archive_shipment_progress_tag(bigint, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Bulk reorder: update sort_order for a list of tag ids
-- ---------------------------------------------------------------------------

create or replace function public.reorder_shipment_progress_tags(
  p_tenant_id bigint,
  p_tag_ids   bigint[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_idx integer;
  v_id  bigint;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  for v_idx in 1..array_length(p_tag_ids, 1) loop
    v_id := p_tag_ids[v_idx];

    update public.tags
    set
      sort_order = v_idx,
      updated_at = now()
    where id = v_id
      and tenant_id = p_tenant_id
      and group_name = 'shipment_progress';
  end loop;
end;
$$;

grant execute on function public.reorder_shipment_progress_tags(bigint, bigint[]) to authenticated;

-- ---------------------------------------------------------------------------
-- Module seed: shipment_progress_settings under procurement_stock
-- ---------------------------------------------------------------------------

insert into public.modules (key, name, description, is_active, parent_module_key)
values (
  'shipment_progress_settings',
  'Shipment Progress',
  'Configure journey stages shown on shipments and the public tracking page.',
  true,
  'procurement_stock'
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  ('shipment_progress_settings', 'view', 'app', true, true),
  ('shipment_progress_settings', 'create', 'app', true, true),
  ('shipment_progress_settings', 'edit', 'app', true, true),
  ('shipment_progress_settings', 'delete', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true,
  tenant_configurable = true;

-- Remove stale tenant_module rows so parent expansion takes over
delete from public.tenant_modules where module_key = 'shipment_progress_settings';

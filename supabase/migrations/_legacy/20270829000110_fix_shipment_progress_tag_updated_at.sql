-- Forward fix:
-- shipment progress tag RPCs updated public.tags.updated_at, but tags has no
-- updated_at column. Remove those writes.

begin;

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

  if p_name is not null and trim(p_name) <> '' then
    v_new_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));
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
    sort_order = coalesce(p_sort_order, sort_order)
  where id = p_tag_id
  returning * into v_result;

  return v_result;
end;
$$;

grant execute on function public.update_shipment_progress_tag(bigint, text, text, integer) to authenticated;

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

  if p_archive = true then
    if exists (
      select 1
      from public.global_shipments gs
      where gs.progress_tag_id = p_tag_id
    ) then
      raise exception 'tag is in use by one or more shipments and cannot be archived';
    end if;
  end if;

  update public.tags
  set is_active = not p_archive
  where id = p_tag_id
  returning * into v_result;

  return v_result;
end;
$$;

grant execute on function public.archive_shipment_progress_tag(bigint, boolean) to authenticated;

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
    set sort_order = v_idx
    where id = v_id
      and tenant_id = p_tenant_id
      and group_name = 'shipment_progress';
  end loop;
end;
$$;

grant execute on function public.reorder_shipment_progress_tags(bigint, bigint[]) to authenticated;

commit;

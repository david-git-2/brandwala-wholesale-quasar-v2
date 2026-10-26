-- Forward fix:
-- 1) Backfill shipment_progress_settings module seed because 20270829000080
--    was already applied before the seed block was appended locally.
-- 2) Fix shipment progress/public tracking RPCs that incorrectly referenced
--    global_shipments.deleted_at (column does not exist on this table).

begin;

-- ---------------------------------------------------------------------------
-- 1. Backfill module seed for Shipment Progress settings
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

delete from public.tenant_modules
where module_key = 'shipment_progress_settings';

-- ---------------------------------------------------------------------------
-- 2. Fix archive RPC: global_shipments has no deleted_at
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
  set
    is_active = not p_archive,
    updated_at = now()
  where id = p_tag_id
  returning * into v_result;

  return v_result;
end;
$$;

grant execute on function public.archive_shipment_progress_tag(bigint, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Fix public tracking RPC: global_shipments has no deleted_at
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

  if v_ship.progress_tag_id is not null then
    select * into v_tag
    from public.tags
    where id = v_ship.progress_tag_id
      and is_active = true
    limit 1;

    if found then
      v_progress_tag := jsonb_build_object(
        'id',         v_tag.id,
        'name',       v_tag.name,
        'color',      v_tag.color,
        'sort_order', v_tag.sort_order
      );
    end if;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',         t.id,
        'name',       t.name,
        'color',      t.color,
        'sort_order', t.sort_order
      )
      order by t.sort_order nulls last, t.name
    ),
    '[]'::jsonb
  )
  into v_progress_list
  from public.tags t
  where t.tenant_id = v_ship.parent_tenant_id
    and t.group_name = 'shipment_progress'
    and t.is_active = true;

  return jsonb_build_object(
    'id',            v_ship.id,
    'name',          v_ship.name,
    'status',        v_ship.status,
    'progress_tag',  v_progress_tag,
    'progress_tags', v_progress_list,
    'updated_at',    v_ship.updated_at
  );
end;
$$;

grant execute on function public.get_shipment_public_status(text) to anon, authenticated;

commit;

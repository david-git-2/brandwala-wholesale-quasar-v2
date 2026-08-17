-- Phase 6: header field aliases + shipment_progress tags via entity_tags
-- Spec: doc/procurement_stock/task.md Phase 6 · shipment/schema.md

begin;

-- ---------------------------------------------------------------------------
-- 1. Column aliases (dual-write with live received_weight / stock_ready)
-- ---------------------------------------------------------------------------

alter table public.global_shipments
  add column if not exists total_weight_kg numeric;

alter table public.global_shipments
  add column if not exists inventory_added boolean not null default false;

alter table public.global_shipments
  add column if not exists progress_tag_id bigint references public.tags(id) on delete set null;

comment on column public.global_shipments.total_weight_kg is
  'Cargo invoice weight (kg). Plan name for live received_weight — dual-written.';
comment on column public.global_shipments.inventory_added is
  'True after finalize posts stock. Plan name for live stock_ready — dual-written.';
comment on column public.global_shipments.progress_tag_id is
  'Denormalized current shipment_progress tag for list speed. SSOT remains entity_tags.';

update public.global_shipments
set
  total_weight_kg = coalesce(total_weight_kg, received_weight),
  inventory_added = coalesce(inventory_added, stock_ready, false)
where total_weight_kg is distinct from received_weight
   or inventory_added is distinct from coalesce(stock_ready, false);

create index if not exists global_shipments_progress_tag_id_idx
  on public.global_shipments (progress_tag_id);

create or replace function public.sync_global_shipment_header_aliases()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.total_weight_kg is null and new.received_weight is not null then
      new.total_weight_kg := new.received_weight;
    elsif new.received_weight is null and new.total_weight_kg is not null then
      new.received_weight := new.total_weight_kg;
    elsif new.total_weight_kg is distinct from new.received_weight then
      -- Prefer plan name when both provided
      if new.total_weight_kg is not null then
        new.received_weight := new.total_weight_kg;
      else
        new.total_weight_kg := new.received_weight;
      end if;
    end if;

    if new.inventory_added is null then
      new.inventory_added := coalesce(new.stock_ready, false);
    end if;
    new.stock_ready := new.inventory_added;
    return new;
  end if;

  -- UPDATE: whichever side changed wins
  if new.total_weight_kg is distinct from old.total_weight_kg then
    new.received_weight := new.total_weight_kg;
  elsif new.received_weight is distinct from old.received_weight then
    new.total_weight_kg := new.received_weight;
  end if;

  if new.inventory_added is distinct from old.inventory_added then
    new.stock_ready := new.inventory_added;
  elsif new.stock_ready is distinct from old.stock_ready then
    new.inventory_added := new.stock_ready;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sync_global_shipment_header_aliases on public.global_shipments;
create trigger trg_sync_global_shipment_header_aliases
  before insert or update on public.global_shipments
  for each row
  execute function public.sync_global_shipment_header_aliases();

-- ---------------------------------------------------------------------------
-- 2. tags: group_name + sort_order (shipment_progress steppers)
-- ---------------------------------------------------------------------------

alter table public.tags
  add column if not exists group_name text;

alter table public.tags
  add column if not exists sort_order integer;

create index if not exists tags_tenant_group_idx
  on public.tags (tenant_id, group_name);

-- ---------------------------------------------------------------------------
-- 3. entity_tags (polymorphic linker — SSOT for progress)
-- ---------------------------------------------------------------------------

create table if not exists public.entity_tags (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  tag_id bigint not null references public.tags(id) on delete cascade,
  entity_type text not null,
  entity_id text not null,
  created_at timestamptz not null default now(),
  unique (tenant_id, tag_id, entity_type, entity_id)
);

create index if not exists entity_tags_entity_idx
  on public.entity_tags (entity_type, entity_id);

create index if not exists entity_tags_tag_id_idx
  on public.entity_tags (tag_id);

create index if not exists entity_tags_tenant_idx
  on public.entity_tags (tenant_id);

alter table public.entity_tags enable row level security;

drop policy if exists entity_tags_select on public.entity_tags;
create policy entity_tags_select on public.entity_tags
  for select to authenticated
  using (
    public.user_can_manage_parent_tenant(tenant_id)
    or public.has_active_tenant_membership(tenant_id)
  );

drop policy if exists entity_tags_all on public.entity_tags;
create policy entity_tags_all on public.entity_tags
  for all to authenticated
  using (public.user_can_manage_parent_tenant(tenant_id))
  with check (public.user_can_manage_parent_tenant(tenant_id));

grant select, insert, update, delete on public.entity_tags to authenticated;
grant usage, select on sequence public.entity_tags_id_seq to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Seed / ensure tenant shipment_progress tags
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
  v_existing_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id required';
  end if;

  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  for v_slug, v_name, v_sort in
    select *
    from (
      values
        ('uk-warehouse'::text, 'UK Warehouse'::text, 1),
        ('on-flight', 'On flight', 2),
        ('airport', 'Airport', 3),
        ('customs-clearance', 'Customs clearance', 4),
        ('bd-warehouse', 'BD Warehouse', 5)
    ) as s(slug, name, sort_order)
  loop
    select t.id into v_existing_id
    from public.tags t
    where t.tenant_id = p_tenant_id
      and t.slug = v_slug
      and t.group_name = 'shipment_progress'
    limit 1;

    if v_existing_id is null then
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
    else
      update public.tags
      set
        name = v_name,
        type = 'shipment_progress',
        group_name = 'shipment_progress',
        sort_order = v_sort
      where id = v_existing_id;
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
-- 5. Set / clear current progress tag (at most one)
-- ---------------------------------------------------------------------------

create or replace function public.set_global_shipment_progress_tag(
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

  -- Remove existing shipment_progress links for this shipment
  delete from public.entity_tags et
  using public.tags t
  where et.tag_id = t.id
    and et.tenant_id = v_ship.parent_tenant_id
    and et.entity_type = 'shipment'
    and et.entity_id = p_shipment_id::text
    and t.group_name = 'shipment_progress';

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

  if v_tag.tenant_id is distinct from v_ship.parent_tenant_id then
    raise exception 'tag tenant mismatch';
  end if;

  insert into public.entity_tags (tenant_id, tag_id, entity_type, entity_id)
  values (v_ship.parent_tenant_id, p_tag_id, 'shipment', p_shipment_id::text);

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

grant execute on function public.set_global_shipment_progress_tag(bigint, bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. List RPC: expose status + progress_tag (+ alias columns via s.*)
-- ---------------------------------------------------------------------------

drop function if exists public.list_global_shipments_paginated(bigint, integer, integer, text, text);

create or replace function public.list_global_shipments_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null,
  p_status text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  select count(*)
  into v_total_count
  from public.global_shipments s
  where s.parent_tenant_id = p_tenant_id
    and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
    and (
      p_search is null or p_search = '' or (
        s.name ilike '%' || p_search || '%'
        or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
      )
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      s.id as sort_id,
      (
        to_jsonb(s)
        || jsonb_build_object(
          'progress_tag',
          case
            when t.id is null then null
            else jsonb_build_object(
              'id', t.id,
              'name', t.name,
              'slug', t.slug,
              'group_name', t.group_name,
              'sort_order', t.sort_order,
              'color', t.color
            )
          end
        )
      ) as row_json
    from public.global_shipments s
    left join public.tags t
      on t.id = s.progress_tag_id
     and t.group_name = 'shipment_progress'
    where s.parent_tenant_id = p_tenant_id
      and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
      and (
        p_search is null or p_search = '' or (
          s.name ilike '%' || p_search || '%'
          or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
        )
      )
    order by s.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) q;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;

grant execute on function public.list_global_shipments_paginated(bigint, integer, integer, text, text) to authenticated;

commit;

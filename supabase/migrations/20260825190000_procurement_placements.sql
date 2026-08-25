-- Procurement placements: vendor order log per demand line (shop order / PBC item)
begin;

create type public.procurement_placement_source_type as enum (
  'shop_order_item',
  'pbc_costing_item'
);

create table public.procurement_placements (
  id bigint generated always as identity primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  source_type public.procurement_placement_source_type not null,
  source_id bigint not null,
  vendor_id bigint references public.vendors(id) on delete set null,
  vendor_code text,
  quantity integer not null,
  notes text,
  placed_by_user_id uuid references auth.users(id) on delete set null,
  placed_at timestamptz not null default now(),
  status text not null default 'active' check (status in ('active', 'cancelled')),
  global_shipment_item_id bigint references public.global_shipment_items(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint procurement_placements_quantity_check check (quantity > 0),
  constraint procurement_placements_vendor_present_check check (
    vendor_id is not null or nullif(trim(vendor_code), '') is not null
  )
);

create index procurement_placements_source_active_idx
  on public.procurement_placements (source_type, source_id)
  where status = 'active';

create index procurement_placements_tenant_placed_at_idx
  on public.procurement_placements (tenant_id, placed_at desc);

create index procurement_placements_vendor_idx
  on public.procurement_placements (vendor_id)
  where vendor_id is not null;

create trigger trg_procurement_placements_set_updated_at
  before update on public.procurement_placements
  for each row execute function public.set_updated_at();

alter table public.procurement_placements enable row level security;

create policy procurement_placements_select on public.procurement_placements
  for select to authenticated
  using (
    public.is_tenant_staff(tenant_id)
    or exists (
      select 1 from public.tenants t
      where t.id = procurement_placements.tenant_id
        and t.parent_id is not null
        and public.user_can_manage_parent_tenant(t.parent_id)
    )
  );

grant select on table public.procurement_placements to authenticated;
grant all on table public.procurement_placements to service_role;
grant usage, select on sequence public.procurement_placements_id_seq to authenticated;
grant all on sequence public.procurement_placements_id_seq to service_role;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.can_access_procurement_placement_tenant(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    public.is_tenant_staff(p_tenant_id)
    or exists (
      select 1 from public.tenants t
      where t.id = p_tenant_id
        and t.parent_id is not null
        and public.user_can_manage_parent_tenant(t.parent_id)
    ),
    false
  );
$$;

create or replace function public.get_procurement_demand_open_qty(
  p_source_type public.procurement_placement_source_type,
  p_source_id bigint
)
returns table (
  tenant_id bigint,
  open_qty integer,
  document_status text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_source_type = 'shop_order_item' then
    return query
    select o.tenant_id,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer,
      o.status::text
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    where oi.id = p_source_id
      and o.shop_type_snapshot = 'vendor_catalog';
  elsif p_source_type = 'pbc_costing_item' then
    return query
    select f.tenant_id,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer,
      f.status
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    where pci.id = p_source_id
      and f.billing_profile_id is not null;
  end if;
end;
$$;

create or replace function public.record_procurement_placement(
  p_tenant_id bigint,
  p_source_type public.procurement_placement_source_type,
  p_source_id bigint,
  p_quantity integer,
  p_vendor_id bigint default null,
  p_vendor_code text default null,
  p_notes text default null
)
returns public.procurement_placements
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.procurement_placements;
  v_line_tenant_id bigint;
  v_open_qty integer;
  v_doc_status text;
  v_placed integer;
  v_vendor_code text;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;
  if p_source_id is null then
    raise exception 'source_id is required';
  end if;
  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be positive';
  end if;
  if p_vendor_id is null and nullif(trim(coalesce(p_vendor_code, '')), '') is null then
    raise exception 'vendor_id or vendor_code is required';
  end if;

  select g.tenant_id, g.open_qty, g.document_status
  into v_line_tenant_id, v_open_qty, v_doc_status
  from public.get_procurement_demand_open_qty(p_source_type, p_source_id) g;

  if v_line_tenant_id is null then
    raise exception 'demand line not found';
  end if;

  if not public.can_access_procurement_placement_tenant(p_tenant_id)
    and not public.can_access_procurement_placement_tenant(v_line_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_line_tenant_id <> p_tenant_id then
    if not exists (
      select 1 from public.tenants t
      where t.id = v_line_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_parent_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand line';
    end if;
  end if;
  if v_doc_status not in ('procuring', 'ready_for_shipment') then
    raise exception 'document is not open for placements';
  end if;

  select coalesce(sum(pp.quantity), 0)::integer into v_placed
  from public.procurement_placements pp
  where pp.source_type = p_source_type
    and pp.source_id = p_source_id
    and pp.status = 'active';

  if v_placed + p_quantity > v_open_qty then
    raise exception 'placement exceeds remaining demand (open %, already placed %, requested %)',
      v_open_qty, v_placed, p_quantity;
  end if;

  v_vendor_code := nullif(trim(coalesce(p_vendor_code, '')), '');
  if p_vendor_id is not null and v_vendor_code is null then
    select v.code into v_vendor_code from public.vendors v where v.id = p_vendor_id;
  end if;

  insert into public.procurement_placements (
    tenant_id,
    source_type,
    source_id,
    vendor_id,
    vendor_code,
    quantity,
    notes,
    placed_by_user_id
  ) values (
    v_line_tenant_id,
    p_source_type,
    p_source_id,
    p_vendor_id,
    v_vendor_code,
    p_quantity,
    nullif(trim(coalesce(p_notes, '')), ''),
    auth.uid()
  )
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.cancel_procurement_placement(
  p_tenant_id bigint,
  p_placement_id bigint
)
returns public.procurement_placements
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.procurement_placements;
begin
  if p_tenant_id is null or p_placement_id is null then
    raise exception 'tenant_id and placement_id are required';
  end if;

  if not public.can_access_procurement_placement_tenant(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_row
  from public.procurement_placements pp
  where pp.id = p_placement_id
    and (
      pp.tenant_id = p_tenant_id
      or exists (
        select 1 from public.tenants t
        where t.id = pp.tenant_id
          and t.parent_id = p_tenant_id
          and public.user_can_manage_parent_tenant(p_tenant_id)
      )
    );

  if not found then
    raise exception 'placement not found';
  end if;
  if v_row.status <> 'active' then
    raise exception 'placement is not active';
  end if;
  if v_row.global_shipment_item_id is not null then
    raise exception 'cannot cancel placement linked to a shipment item';
  end if;

  update public.procurement_placements
  set status = 'cancelled', updated_at = now()
  where id = p_placement_id
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.can_access_procurement_placement_tenant(bigint) to authenticated;
grant execute on function public.get_procurement_demand_open_qty(public.procurement_placement_source_type, bigint) to authenticated;
grant execute on function public.record_procurement_placement(
  bigint, public.procurement_placement_source_type, bigint, integer, bigint, text, text
) to authenticated;
grant execute on function public.cancel_procurement_placement(bigint, bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- Extend list_procurement_demand_groups with placement aggregates
-- ---------------------------------------------------------------------------

create or replace function public.list_procurement_demand_groups(
  p_tenant_id bigint,
  p_procurement_status text default 'procuring',
  p_search text default null,
  p_child_tenant_id bigint default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_is_parent boolean;
  v_allowed boolean := false;
  v_status text := lower(trim(coalesce(p_procurement_status, 'procuring')));
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(coalesce(p_limit, 50), 1);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_groups jsonb := '[]'::jsonb;
  v_group_count integer := 0;
  v_item_count integer := 0;
  v_has_shop boolean := false;
  v_has_pbc boolean := false;
  v_sources text[] := '{}'::text[];
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then raise exception 'tenant not found: %', p_tenant_id; end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then raise exception 'access denied'; end if;
  if v_status not in ('procuring', 'ready_for_shipment', 'delivered') then
    raise exception 'invalid procurement status: %', v_status;
  end if;

  with tenant_scope as (
    select t.id as tenant_id from public.tenants t
    where ((v_is_parent and t.parent_id = p_tenant_id) or (not v_is_parent and t.id = p_tenant_id))
      and (p_child_tenant_id is null or t.id = p_child_tenant_id)
  ),
  shop_lines as (
    select 'shop_order'::text as document_type, o.id as document_id, o.status::text as document_status,
      null::jsonb as vendor, oi.id as source_id, oi.product_id, oi.name, oi.image_url,
      coalesce(p.barcode, '') as barcode, coalesce(p.product_code, '') as product_code,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.products p on p.id = oi.product_id
    where o.shop_type_snapshot = 'vendor_catalog'
      and ((v_status = 'procuring' and o.status = 'procuring'::public.shop_order_status)
        or (v_status = 'ready_for_shipment' and o.status = 'ready_for_shipment'::public.shop_order_status)
        or (v_status = 'delivered' and o.status = 'delivered'::public.shop_order_status))
      and (v_search is null or oi.name ilike '%' || v_search || '%' or o.name ilike '%' || v_search || '%'
        or o.order_no ilike '%' || v_search || '%' or coalesce(p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(p.product_code, '') ilike '%' || v_search || '%')
  ),
  pbc_lines as (
    select 'pbc_costing_file'::text as document_type, f.id as document_id, f.status as document_status,
      case when v.id is not null then jsonb_build_object('id', v.id, 'code', coalesce(nullif(trim(f.vendor_code), ''), v.code), 'name', v.name)
        when nullif(trim(f.vendor_code), '') is not null then jsonb_build_object('id', f.vendor_id, 'code', trim(f.vendor_code), 'name', null)
        else null::jsonb end as vendor,
      pci.id as source_id, pci.product_id, coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url, coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      greatest(case when pci.assigned_shipment_id is not null then 0
        else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0) end, 0)::integer as quantity
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.products p on p.id = pci.product_id
    left join public.vendors v on v.id = f.vendor_id
    where f.billing_profile_id is not null
      and ((v_status = 'procuring' and f.status = 'procuring')
        or (v_status = 'ready_for_shipment' and f.status = 'ready_for_shipment')
        or (v_status = 'delivered' and f.status = 'delivered'))
      and (v_search is null or coalesce(pci.name, p.name, '') ilike '%' || v_search || '%'
        or coalesce(f.name, '') ilike '%' || v_search || '%'
        or coalesce(pci.barcode, p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(pci.product_code, p.product_code, '') ilike '%' || v_search || '%')
  ),
  all_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  placement_totals as (
    select
      pp.source_type::text as source_type,
      pp.source_id,
      coalesce(sum(pp.quantity), 0)::integer as placed_quantity,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', pp.id,
            'vendor_id', pp.vendor_id,
            'vendor_code', nullif(trim(pp.vendor_code), ''),
            'vendor_name', vn.name,
            'quantity', pp.quantity,
            'notes', pp.notes,
            'placed_at', pp.placed_at,
            'placed_by_user_id', pp.placed_by_user_id,
            'global_shipment_item_id', pp.global_shipment_item_id
          )
          order by pp.placed_at, pp.id
        ) filter (where pp.id is not null),
        '[]'::jsonb
      ) as placements
    from public.procurement_placements pp
    inner join tenant_scope ts on ts.tenant_id = pp.tenant_id
    left join public.vendors vn on vn.id = pp.vendor_id
    where pp.status = 'active'
    group by pp.source_type, pp.source_id
  ),
  enriched_lines as (
    select
      al.*,
      case when al.document_type = 'shop_order' then 'shop_order_item' else 'pbc_costing_item' end as source_type,
      coalesce(pt.placed_quantity, 0) as placed_quantity,
      coalesce(pt.placements, '[]'::jsonb) as placements
    from all_lines al
    left join placement_totals pt
      on pt.source_id = al.source_id
      and pt.source_type = case when al.document_type = 'shop_order' then 'shop_order_item' else 'pbc_costing_item' end
    where al.quantity > 0 or coalesce(pt.placed_quantity, 0) > 0
  ),
  grouped as (
    select el.document_type, el.document_id, max(el.document_status) as document_status,
      (array_agg(el.vendor) filter (where el.vendor is not null))[1] as vendor,
      jsonb_agg(jsonb_build_object(
        'source_type', el.source_type,
        'source_id', el.source_id,
        'product_id', el.product_id,
        'name', el.name,
        'image_url', el.image_url,
        'barcode', nullif(el.barcode, ''),
        'product_code', nullif(el.product_code, ''),
        'quantity', el.quantity,
        'need_quantity', el.quantity,
        'placed_quantity', el.placed_quantity,
        'remaining_quantity', greatest(el.quantity - el.placed_quantity, 0),
        'placements', el.placements
      ) order by el.source_id) as items,
      count(*)::integer as item_count
    from enriched_lines el
    group by el.document_type, el.document_id
  ),
  paged as (
    select g.*, count(*) over ()::integer as total_groups from grouped g
    order by g.document_type, g.document_id limit v_limit offset v_offset
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'document_type', p.document_type, 'document_id', p.document_id, 'document_status', p.document_status,
      'vendor', p.vendor, 'items', p.items) order by p.document_type, p.document_id), '[]'::jsonb),
    coalesce(max(p.total_groups), 0), coalesce(sum(p.item_count), 0),
    coalesce(bool_or(p.document_type = 'shop_order'), false), coalesce(bool_or(p.document_type = 'pbc_costing_file'), false)
  into v_groups, v_group_count, v_item_count, v_has_shop, v_has_pbc from paged p;

  if v_has_shop then v_sources := array_append(v_sources, 'shop_order'); end if;
  if v_has_pbc then v_sources := array_append(v_sources, 'pbc_costing'); end if;

  return jsonb_build_object(
    'meta', jsonb_build_object('tenant_id', p_tenant_id, 'procurement_status', v_status,
      'sources_included', to_jsonb(v_sources), 'group_count', coalesce(jsonb_array_length(v_groups), 0),
      'item_count', v_item_count, 'total_group_count', v_group_count, 'limit', v_limit, 'offset', v_offset,
      'has_more', v_group_count > (v_offset + v_limit)),
    'groups', v_groups);
end;
$$;

commit;

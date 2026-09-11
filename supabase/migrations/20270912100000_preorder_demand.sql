-- Replace procurement_placements (+ planned procurement_fulfillments) with preorder_demand
begin;

create type public.preorder_demand_source_type as enum (
  'shop_order_item',
  'pbc_costing_item'
);

create table public.preorder_demand (
  id bigint generated always as identity primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  source_type public.preorder_demand_source_type not null,
  source_id bigint not null,
  vendor_id bigint references public.vendors(id) on delete set null,
  placed_quantity integer not null default 0,
  delivered_quantity integer not null default 0,
  stock_picks jsonb not null default '[]'::jsonb,
  notes text,
  updated_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint preorder_demand_source_unique unique (source_type, source_id),
  constraint preorder_demand_placed_quantity_check check (placed_quantity >= 0),
  constraint preorder_demand_delivered_quantity_check check (delivered_quantity >= 0),
  constraint preorder_demand_delivered_lte_placed_check check (delivered_quantity <= placed_quantity),
  constraint preorder_demand_stock_picks_is_array check (jsonb_typeof(stock_picks) = 'array')
);

create index preorder_demand_tenant_updated_idx
  on public.preorder_demand (tenant_id, updated_at desc);

create index preorder_demand_source_idx
  on public.preorder_demand (source_type, source_id);

create trigger trg_preorder_demand_set_updated_at
  before update on public.preorder_demand
  for each row execute function public.set_updated_at();

alter table public.preorder_demand enable row level security;

create policy preorder_demand_select on public.preorder_demand
  for select to authenticated
  using (
    public.is_tenant_staff(tenant_id)
    or exists (
      select 1 from public.tenants t
      where t.id = preorder_demand.tenant_id
        and t.parent_id is not null
        and public.user_can_manage_parent_tenant(t.parent_id)
    )
  );

grant select on table public.preorder_demand to authenticated;
grant all on table public.preorder_demand to service_role;
grant usage, select on sequence public.preorder_demand_id_seq to authenticated;
grant all on sequence public.preorder_demand_id_seq to service_role;

-- Migrate active placement rows (one row per demand line)
insert into public.preorder_demand (
  tenant_id,
  source_type,
  source_id,
  vendor_id,
  placed_quantity,
  delivered_quantity,
  stock_picks,
  notes,
  updated_by_user_id,
  created_at,
  updated_at
)
select
  agg.tenant_id,
  agg.source_type::text::public.preorder_demand_source_type,
  agg.source_id,
  agg.vendor_id,
  agg.placed_quantity,
  0,
  '[]'::jsonb,
  agg.notes,
  agg.updated_by_user_id,
  agg.created_at,
  agg.updated_at
from (
  select
    pp.tenant_id,
    pp.source_type,
    pp.source_id,
    (
      array_agg(pp.vendor_id order by pp.placed_at desc nulls last, pp.id desc)
      filter (where pp.vendor_id is not null)
    )[1] as vendor_id,
    coalesce(sum(pp.quantity), 0)::integer as placed_quantity,
    (
      array_agg(nullif(trim(pp.notes), '') order by pp.placed_at desc nulls last, pp.id desc)
      filter (where nullif(trim(pp.notes), '') is not null)
    )[1] as notes,
    (
      array_agg(pp.placed_by_user_id order by pp.placed_at desc nulls last, pp.id desc)
      filter (where pp.placed_by_user_id is not null)
    )[1] as updated_by_user_id,
    min(pp.created_at) as created_at,
    max(pp.updated_at) as updated_at
  from public.procurement_placements pp
  where pp.status = 'active'
  group by pp.tenant_id, pp.source_type, pp.source_id
) agg
on conflict (source_type, source_id) do nothing;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.can_access_preorder_demand_tenant(p_tenant_id bigint)
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

create or replace function public.sum_preorder_stock_picks(p_stock_picks jsonb)
returns integer
language sql
immutable
as $$
  select coalesce(
    sum(greatest(coalesce((elem->>'quantity')::integer, 0), 0)),
    0
  )::integer
  from jsonb_array_elements(coalesce(p_stock_picks, '[]'::jsonb)) elem
  where nullif(elem->>'global_stock_id', '') is not null;
$$;

create or replace function public.validate_preorder_stock_picks(p_stock_picks jsonb)
returns boolean
language plpgsql
immutable
as $$
declare
  v_elem jsonb;
  v_stock_id bigint;
  v_qty integer;
begin
  if p_stock_picks is null then
    return true;
  end if;
  if jsonb_typeof(p_stock_picks) <> 'array' then
    return false;
  end if;

  for v_elem in select value from jsonb_array_elements(p_stock_picks)
  loop
    v_stock_id := nullif(v_elem->>'global_stock_id', '')::bigint;
    v_qty := coalesce((v_elem->>'quantity')::integer, 0);
    if v_stock_id is null or v_qty <= 0 then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

drop function if exists public.get_procurement_demand_open_qty(public.procurement_placement_source_type, bigint);

create or replace function public.get_procurement_demand_open_qty(
  p_source_type public.preorder_demand_source_type,
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
    select
      o.tenant_id,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer,
      public.normalize_shop_order_procurement_status(o.status)
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    where oi.id = p_source_id
      and o.shop_type_snapshot = 'vendor_catalog';
  elsif p_source_type = 'pbc_costing_item' then
    return query
    select
      f.tenant_id,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer,
      public.normalize_pbc_procurement_status(f.status)
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    where pci.id = p_source_id
      and f.billing_profile_id is not null;
  end if;
end;
$$;

create or replace function public.upsert_preorder_demand(
  p_tenant_id bigint,
  p_source_type public.preorder_demand_source_type,
  p_source_id bigint,
  p_vendor_id bigint default null,
  p_placed_quantity integer default null,
  p_stock_picks jsonb default null,
  p_notes text default null
)
returns public.preorder_demand
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.preorder_demand;
  v_line_tenant_id bigint;
  v_open_qty integer;
  v_doc_status text;
  v_delivered integer;
  v_placed integer;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;
  if p_source_id is null then
    raise exception 'source_id is required';
  end if;

  select g.tenant_id, g.open_qty, g.document_status
  into v_line_tenant_id, v_open_qty, v_doc_status
  from public.get_procurement_demand_open_qty(p_source_type, p_source_id) g;

  if v_line_tenant_id is null then
    raise exception 'demand line not found';
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_line_tenant_id) then
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
    raise exception 'document is not open for preorder demand updates';
  end if;

  if p_placed_quantity is not null and v_doc_status <> 'procuring' then
    raise exception 'placed_quantity can only be updated while procuring';
  end if;

  if p_stock_picks is not null and v_doc_status <> 'ready_for_shipment' then
    raise exception 'stock_picks can only be updated while ready_for_shipment';
  end if;

  if p_placed_quantity is not null and coalesce(p_placed_quantity, 0) < 0 then
    raise exception 'placed_quantity cannot be negative';
  end if;

  if p_placed_quantity is not null and coalesce(p_placed_quantity, 0) > v_open_qty then
    raise exception 'placed_quantity exceeds need (open %, requested %)', v_open_qty, p_placed_quantity;
  end if;

  if p_stock_picks is not null and not public.validate_preorder_stock_picks(p_stock_picks) then
    raise exception 'invalid stock_picks payload';
  end if;

  v_delivered := case
    when p_stock_picks is not null then public.sum_preorder_stock_picks(p_stock_picks)
    else null
  end;

  select pd.* into v_row
  from public.preorder_demand pd
  where pd.source_type = p_source_type
    and pd.source_id = p_source_id;

  if found then
    v_placed := coalesce(p_placed_quantity, v_row.placed_quantity, 0);
  else
    v_placed := coalesce(p_placed_quantity, 0);
  end if;

  if v_delivered is not null and v_delivered > v_placed then
    raise exception 'delivered_quantity cannot exceed placed_quantity';
  end if;

  insert into public.preorder_demand (
    tenant_id,
    source_type,
    source_id,
    vendor_id,
    placed_quantity,
    delivered_quantity,
    stock_picks,
    notes,
    updated_by_user_id
  ) values (
    v_line_tenant_id,
    p_source_type,
    p_source_id,
    coalesce(p_vendor_id, case when found then v_row.vendor_id else null end),
    v_placed,
    coalesce(v_delivered, case when found then v_row.delivered_quantity else 0 end, 0),
    coalesce(p_stock_picks, case when found then v_row.stock_picks else '[]'::jsonb end, '[]'::jsonb),
    coalesce(nullif(trim(p_notes), ''), case when found then v_row.notes else null end),
    auth.uid()
  )
  on conflict (source_type, source_id) do update set
    vendor_id = case when p_vendor_id is not null then p_vendor_id else preorder_demand.vendor_id end,
    placed_quantity = case when p_placed_quantity is not null then p_placed_quantity else preorder_demand.placed_quantity end,
    delivered_quantity = case when v_delivered is not null then v_delivered else preorder_demand.delivered_quantity end,
    stock_picks = case when p_stock_picks is not null then p_stock_picks else preorder_demand.stock_picks end,
    notes = case when p_notes is not null then nullif(trim(p_notes), '') else preorder_demand.notes end,
    updated_by_user_id = auth.uid(),
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

-- Drop legacy placement RPCs and table
drop function if exists public.record_procurement_placement(
  bigint, public.procurement_placement_source_type, bigint, integer, bigint, text, text
);
drop function if exists public.cancel_procurement_placement(bigint, bigint);
drop function if exists public.can_access_procurement_placement_tenant(bigint);

drop table if exists public.procurement_placements;
drop type if exists public.procurement_placement_source_type;

grant execute on function public.can_access_preorder_demand_tenant(bigint) to authenticated;
grant execute on function public.get_procurement_demand_open_qty(public.preorder_demand_source_type, bigint) to authenticated;
grant execute on function public.upsert_preorder_demand(
  bigint, public.preorder_demand_source_type, bigint, bigint, integer, jsonb, text
) to authenticated;

-- list_procurement_demand_groups: join preorder_demand instead of procurement_placements
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
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      public.normalize_shop_order_procurement_status(o.status) as document_status,
      o.customer_group_id,
      cg.name as customer_group_name,
      null::jsonb as vendor,
      oi.id as source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') as barcode,
      coalesce(p.product_code, '') as product_code,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.customer_groups cg on cg.id = o.customer_group_id
    left join public.products p on p.id = oi.product_id
    where o.shop_type_snapshot = 'vendor_catalog'
      and public.normalize_shop_order_procurement_status(o.status) = v_status
      and (
        v_search is null
        or oi.name ilike '%' || v_search || '%'
        or o.name ilike '%' || v_search || '%'
        or o.order_no ilike '%' || v_search || '%'
        or coalesce(p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  pbc_lines as (
    select
      'pbc_costing_file'::text as document_type,
      f.id as document_id,
      public.normalize_pbc_procurement_status(f.status) as document_status,
      bp.customer_group_id,
      cg.name as customer_group_name,
      case
        when v.id is not null then jsonb_build_object(
          'id', v.id,
          'code', coalesce(nullif(trim(f.vendor_code), ''), v.code),
          'name', v.name
        )
        when nullif(trim(f.vendor_code), '') is not null then jsonb_build_object(
          'id', f.vendor_id,
          'code', trim(f.vendor_code),
          'name', null
        )
        else null::jsonb
      end as vendor,
      pci.id as source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url,
      coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer as quantity
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.billing_profiles bp on bp.id = f.billing_profile_id
    left join public.customer_groups cg on cg.id = bp.customer_group_id
    left join public.products p on p.id = pci.product_id
    left join public.vendors v on v.id = f.vendor_id
    where f.billing_profile_id is not null
      and public.normalize_pbc_procurement_status(f.status) = v_status
      and (
        v_search is null
        or coalesce(pci.name, p.name, '') ilike '%' || v_search || '%'
        or coalesce(f.name, '') ilike '%' || v_search || '%'
        or coalesce(pci.barcode, p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(pci.product_code, p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  all_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  preorder_lines as (
    select
      pd.id as preorder_demand_id,
      pd.source_type::text as source_type,
      pd.source_id,
      pd.vendor_id,
      pd.placed_quantity,
      pd.delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks
    from public.preorder_demand pd
    inner join tenant_scope ts on ts.tenant_id = pd.tenant_id
  ),
  enriched_lines as (
    select
      al.*,
      case when al.document_type = 'shop_order' then 'shop_order_item' else 'pbc_costing_item' end as source_type,
      pl.preorder_demand_id,
      pl.vendor_id,
      coalesce(pl.placed_quantity, 0) as placed_quantity,
      coalesce(pl.delivered_quantity, 0) as delivered_quantity,
      coalesce(pl.stock_picks, '[]'::jsonb) as stock_picks
    from all_lines al
    left join preorder_lines pl
      on pl.source_id = al.source_id
      and pl.source_type = case when al.document_type = 'shop_order' then 'shop_order_item' else 'pbc_costing_item' end
    where al.quantity > 0
      or coalesce(pl.placed_quantity, 0) > 0
      or coalesce(pl.delivered_quantity, 0) > 0
  ),
  grouped as (
    select
      el.document_type,
      el.document_id,
      max(el.document_status) as document_status,
      max(el.customer_group_id) as customer_group_id,
      max(el.customer_group_name) as customer_group_name,
      (array_agg(el.vendor) filter (where el.vendor is not null))[1] as vendor,
      jsonb_agg(
        jsonb_build_object(
          'source_type', el.source_type,
          'source_id', el.source_id,
          'product_id', el.product_id,
          'name', el.name,
          'image_url', el.image_url,
          'barcode', nullif(el.barcode, ''),
          'product_code', nullif(el.product_code, ''),
          'quantity', el.quantity,
          'need_quantity', el.quantity,
          'preorder_demand_id', el.preorder_demand_id,
          'vendor_id', el.vendor_id,
          'placed_quantity', el.placed_quantity,
          'delivered_quantity', el.delivered_quantity,
          'remaining_quantity', greatest(el.quantity - el.placed_quantity, 0),
          'remaining_to_deliver', greatest(el.placed_quantity - el.delivered_quantity, 0),
          'stock_picks', el.stock_picks
        )
        order by el.source_id
      ) as items,
      count(*)::integer as item_count
    from enriched_lines el
    group by el.document_type, el.document_id
  ),
  paged as (
    select g.*, count(*) over ()::integer as total_groups
    from grouped g
    order by g.document_type, g.document_id
    limit v_limit offset v_offset
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'document_type', p.document_type,
          'document_id', p.document_id,
          'document_status', p.document_status,
          'customer_group_id', p.customer_group_id,
          'customer_group_name', p.customer_group_name,
          'vendor', p.vendor,
          'items', p.items
        )
        order by p.document_type, p.document_id
      ),
      '[]'::jsonb
    ),
    coalesce(max(p.total_groups), 0),
    coalesce(sum(p.item_count), 0),
    coalesce(bool_or(p.document_type = 'shop_order'), false),
    coalesce(bool_or(p.document_type = 'pbc_costing_file'), false)
  into v_groups, v_group_count, v_item_count, v_has_shop, v_has_pbc
  from paged p;

  if v_has_shop then v_sources := array_append(v_sources, 'shop_order'); end if;
  if v_has_pbc then v_sources := array_append(v_sources, 'pbc_costing'); end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'tenant_id', p_tenant_id,
      'procurement_status', v_status,
      'sources_included', to_jsonb(v_sources),
      'group_count', coalesce(jsonb_array_length(v_groups), 0),
      'item_count', v_item_count,
      'total_group_count', v_group_count,
      'limit', v_limit,
      'offset', v_offset,
      'has_more', v_group_count > (v_offset + v_limit)
    ),
    'groups', v_groups
  );
end;
$$;

commit;

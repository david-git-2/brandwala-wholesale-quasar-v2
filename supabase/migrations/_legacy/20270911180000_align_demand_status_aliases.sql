-- Align catalog orders and PBC costing files on shared procurement statuses for demand desk.
begin;

-- ---------------------------------------------------------------------------
-- 1. Backfill legacy status values
-- ---------------------------------------------------------------------------

update public.product_based_costing_files
set status = 'procuring', updated_at = now()
where status = 'placing_order';

update public.product_based_costing_files
set status = 'delivered', updated_at = now()
where status = 'invoicing';

update public.shop_orders
set status = 'ready_for_shipment'::public.shop_order_status, updated_at = now()
where shop_type_snapshot = 'vendor_catalog'
  and status = 'ordered'::public.shop_order_status;

-- ---------------------------------------------------------------------------
-- 2. Normalization helpers (transition safety net)
-- ---------------------------------------------------------------------------

create or replace function public.normalize_shop_order_procurement_status(p_status public.shop_order_status)
returns text
language sql
immutable
as $$
  select case
    when p_status = 'ordered'::public.shop_order_status then 'ready_for_shipment'
    else p_status::text
  end;
$$;

create or replace function public.normalize_pbc_procurement_status(p_status text)
returns text
language sql
immutable
as $$
  select case lower(trim(coalesce(p_status, '')))
    when 'placing_order' then 'procuring'
    when 'invoicing' then 'delivered'
    else lower(trim(coalesce(p_status, '')))
  end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Open qty helper — return normalized document_status
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- 4. Demand list — alias-aware status match + placement aggregates
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
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      public.normalize_shop_order_procurement_status(o.status) as document_status,
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
    select
      el.document_type,
      el.document_id,
      max(el.document_status) as document_status,
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
          'placed_quantity', el.placed_quantity,
          'remaining_quantity', greatest(el.quantity - el.placed_quantity, 0),
          'placements', el.placements
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

-- ---------------------------------------------------------------------------
-- 5. PBC file list — alias-aware status filter
-- ---------------------------------------------------------------------------

create or replace function public.list_product_based_costing_files(
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null,
  p_status text default null,
  p_tenant_id bigint default null
)
returns jsonb
language sql
stable
set search_path = public
as $$
  with filtered as (
    select
      f.*,
      count(*) over() as total_count
    from public.product_based_costing_files f
    where
      (p_tenant_id is null or f.tenant_id = p_tenant_id)
      and (
        coalesce(trim(p_search), '') = ''
        or coalesce(f.name, '') ilike ('%' || trim(p_search) || '%')
        or coalesce(f.order_for, '') ilike ('%' || trim(p_search) || '%')
        or coalesce(f.note, '') ilike ('%' || trim(p_search) || '%')
      )
      and (
        coalesce(trim(p_status), '') = ''
        or f.status = trim(p_status)
        or (trim(p_status) = 'procuring' and f.status = 'placing_order')
        or (trim(p_status) = 'delivered' and f.status = 'invoicing')
      )
  ),
  paged as (
    select *
    from filtered
    order by created_at desc, id desc
    offset (greatest(coalesce(p_page, 1), 1) - 1) * greatest(coalesce(p_page_size, 20), 1)
    limit greatest(coalesce(p_page_size, 20), 1)
  )
  select jsonb_build_object(
    'data',
    coalesce(jsonb_agg(to_jsonb(paged) - 'total_count'), '[]'::jsonb),
    'meta',
    jsonb_build_object(
      'total', coalesce(max(paged.total_count), 0),
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', greatest(coalesce(p_page_size, 20), 1),
      'total_pages',
      case
        when coalesce(max(paged.total_count), 0) = 0 then 1
        else ceil(coalesce(max(paged.total_count), 0)::numeric / greatest(coalesce(p_page_size, 20), 1))::int
      end
    )
  )
  from paged;
$$;

commit;

drop function if exists public.list_inventory_items_with_stock(bigint, integer, integer, text, text, jsonb);

create function public.list_inventory_items_with_stock(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_sort_by text default 'id',
  p_sort_order text default 'desc',
  p_filters jsonb default '{}'::jsonb
)
returns jsonb
language sql
security invoker
set search_path = public
stable
as $$
  with filtered as (
    select
      ii.id,
      ii.tenant_id,
      ii.source_type,
      ii.source_id,
      ii.name,
      ii.image_url,
      ii.cost,
      ii.barcode,
      ii.product_code,
      ii.manufacturing_date,
      ii.expire_date,
      ii.status,
      ii.created_at,
      ii.updated_at,
      case
        when s.id is null then null
        else jsonb_build_object(
          'id', s.id,
          'inventory_item_id', s.inventory_item_id,
          'available_quantity', s.available_quantity,
          'reserved_quantity', s.reserved_quantity,
          'damaged_quantity', s.damaged_quantity,
          'stolen_quantity', s.stolen_quantity,
          'expired_quantity', s.expired_quantity,
          'created_at', s.created_at,
          'updated_at', s.updated_at
        )
      end as stock,
      case
        when si.id is null then null
        else jsonb_build_object(
          'shipment_item', to_jsonb(si),
          'shipment', to_jsonb(sh)
        )
      end as shipment
    from public.inventory_items ii
    left join public.inventory_stocks s
      on s.inventory_item_id = ii.id
    left join public.shipment_items si
      on ii.source_type = 'shipment'
      and ii.source_id = si.id
    left join public.shipments sh
      on sh.id = si.shipment_id
    where ii.tenant_id = p_tenant_id
      and (
        not (p_filters ? 'name')
        or ii.name ilike ('%' || coalesce(p_filters->>'name', '') || '%')
      )
      and (
        not (p_filters ? 'status')
        or ii.status = p_filters->>'status'
      )
      and (
        not (p_filters ? 'source_type')
        or ii.source_type = p_filters->>'source_type'
      )
      and (
        not (p_filters ? 'source_id')
        or ii.source_id = nullif(p_filters->>'source_id', '')::bigint
      )
      and (
        not (p_filters ? 'barcode')
        or coalesce(ii.barcode, '') ilike ('%' || coalesce(p_filters->>'barcode', '') || '%')
      )
      and (
        not (p_filters ? 'product_code')
        or coalesce(ii.product_code, '') ilike ('%' || coalesce(p_filters->>'product_code', '') || '%')
      )
      and (
        not (p_filters ? 'shipment_id')
        or sh.id = nullif(p_filters->>'shipment_id', '')::bigint
      )
  ),
  counted as (
    select
      filtered.*,
      count(*) over() as total_count
    from filtered
  ),
  paged as (
    select *
    from counted
    order by
      case when lower(coalesce(p_sort_order, 'desc')) = 'asc' and lower(coalesce(p_sort_by, 'id')) = 'id' then id end asc,
      case when lower(coalesce(p_sort_order, 'desc')) = 'desc' and lower(coalesce(p_sort_by, 'id')) = 'id' then id end desc,
      case when lower(coalesce(p_sort_order, 'desc')) = 'asc' and lower(coalesce(p_sort_by, 'id')) = 'name' then name end asc,
      case when lower(coalesce(p_sort_order, 'desc')) = 'desc' and lower(coalesce(p_sort_by, 'id')) = 'name' then name end desc,
      case when lower(coalesce(p_sort_order, 'desc')) = 'asc' and lower(coalesce(p_sort_by, 'id')) = 'created_at' then created_at end asc,
      case when lower(coalesce(p_sort_order, 'desc')) = 'desc' and lower(coalesce(p_sort_by, 'id')) = 'created_at' then created_at end desc,
      id desc
    offset (greatest(coalesce(p_page, 1), 1) - 1) * greatest(coalesce(p_page_size, 20), 1)
    limit greatest(coalesce(p_page_size, 20), 1)
  )
  select jsonb_build_object(
    'data',
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', paged.id,
          'tenant_id', paged.tenant_id,
          'source_type', paged.source_type,
          'source_id', paged.source_id,
          'name', paged.name,
          'image_url', paged.image_url,
          'cost', paged.cost,
          'barcode', paged.barcode,
          'product_code', paged.product_code,
          'manufacturing_date', paged.manufacturing_date,
          'expire_date', paged.expire_date,
          'status', paged.status,
          'created_at', paged.created_at,
          'updated_at', paged.updated_at,
          'stock', paged.stock,
          'shipment', paged.shipment
        )
      ),
      '[]'::jsonb
    ),
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

grant execute on function public.list_inventory_items_with_stock(bigint, integer, integer, text, text, jsonb)
to authenticated;

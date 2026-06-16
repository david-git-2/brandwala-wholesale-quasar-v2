-- Migration: Include tenant_shipment_id in list_inventory_items_with_stock, list_global_inventory_items_with_stock, and list_store_product_pricing RPCs
begin;

-- 1. Redefine list_inventory_items_with_stock
create or replace function public.list_inventory_items_with_stock(
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
      ii.product_id,
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
          'open_box_quantity', s.open_box_quantity,
          'created_at', s.created_at,
          'updated_at', s.updated_at
        )
      end as stock,
      case
        when si.id is null then null
        else jsonb_build_object(
          'shipment', jsonb_build_object(
            'id', sh.id,
            'name', sh.name,
            'tenant_shipment_id', sh.tenant_shipment_id
          ),
          'shipment_item', null
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
        not (p_filters ? 'product_id')
        or ii.product_id = nullif(p_filters->>'product_id', '')::bigint
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
    select filtered.*, count(*) over() as total_count
    from filtered
  ),
  paged as (
    select * from counted
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
    'data', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', paged.id,
          'tenant_id', paged.tenant_id,
          'source_type', paged.source_type,
          'source_id', paged.source_id,
          'product_id', paged.product_id,
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
    'meta', jsonb_build_object(
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


-- 2. Redefine list_global_inventory_items_with_stock
create or replace function public.list_global_inventory_items_with_stock(
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
      t.name as tenant_name,
      t.slug as tenant_slug,
      ii.source_type,
      ii.source_id,
      ii.product_id,
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
          'open_box_quantity', s.open_box_quantity,
          'created_at', s.created_at,
          'updated_at', s.updated_at
        )
      end as stock,
      case
        when si.id is null then null
        else jsonb_build_object(
          'shipment', jsonb_build_object(
            'id', sh.id,
            'name', sh.name,
            'tenant_shipment_id', sh.tenant_shipment_id
          ),
          'shipment_item', null
        )
      end as shipment
    from public.inventory_items ii
    left join public.tenants t
      on t.id = ii.tenant_id
    left join public.inventory_stocks s
      on s.inventory_item_id = ii.id
    left join public.shipment_items si
      on ii.source_type = 'shipment'
      and ii.source_id = si.id
    left join public.shipments sh
      on sh.id = si.shipment_id
    where (
      exists (
        select 1
        from public.memberships m
        where m.tenant_id = ii.tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.is_active = true
      )
    )
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
        not (p_filters ? 'product_id')
        or ii.product_id = nullif(p_filters->>'product_id', '')::bigint
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
    select filtered.*, count(*) over() as total_count
    from filtered
  ),
  paged as (
    select * from counted
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
    'data', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', paged.id,
          'tenant_id', paged.tenant_id,
          'tenant_name', paged.tenant_name,
          'tenant_slug', paged.tenant_slug,
          'source_type', paged.source_type,
          'source_id', paged.source_id,
          'product_id', paged.product_id,
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
    'meta', jsonb_build_object(
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


-- 3. Redefine list_store_product_pricing
create or replace function public.list_store_product_pricing(
  p_tenant_id bigint,
  p_store_id bigint,
  p_page integer default 1,
  p_page_size integer default 10,
  p_search text default null,
  p_shipment_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  with target_batches as (
    -- Filter active inventory items
    select ii.id as inventory_item_id, ii.product_id
    from public.inventory_items ii
    left join public.shipment_items si
      on ii.source_type = 'shipment'
     and ii.source_id = si.id
    left join public.inventory_stocks ist
      on ist.inventory_item_id = ii.id
    where ii.tenant_id = p_tenant_id
      and ii.status = 'active'
      and (p_shipment_id is null or (ii.source_type = 'shipment' and si.shipment_id = p_shipment_id))
      and (ist.stolen_quantity is null or ist.stolen_quantity = 0 or ist.stolen_quantity < ist.available_quantity)
  ),
  batches_with_details as (
    -- Search in batches or parent product details
    select
      tb.inventory_item_id,
      ii.product_id,
      ii.name,
      ii.image_url,
      ii.barcode,
      ii.product_code,
      ii.expire_date,
      ii.cost
    from target_batches tb
    join public.inventory_items ii on ii.id = tb.inventory_item_id
    left join public.products p on p.id = tb.product_id
    where (
      p_search is null
      or trim(p_search) = ''
      or ii.name ilike ('%' || trim(p_search) || '%')
      or ii.product_code ilike ('%' || trim(p_search) || '%')
      or ii.barcode ilike ('%' || trim(p_search) || '%')
      or p.name ilike ('%' || trim(p_search) || '%')
      or p.product_code ilike ('%' || trim(p_search) || '%')
      or p.barcode ilike ('%' || trim(p_search) || '%')
    )
  ),
  counted as (
    select *, count(*) over() as total_count
    from batches_with_details
  ),
  paged_batches as (
    select *
    from counted
    order by name asc, inventory_item_id asc
    limit p_page_size
    offset (p_page - 1) * p_page_size
  ),
  batch_items as (
    -- Construct cost, stock, and shipment info for each batch
    select
      pb.inventory_item_id,
      jsonb_build_object(
        'id', pb.inventory_item_id,
        'cost', pb.cost,
        'quantities', jsonb_build_object(
          'available', coalesce(ist.available_quantity, 0),
          'reserved', coalesce(ist.reserved_quantity, 0),
          'damaged', coalesce(ist.damaged_quantity, 0),
          'stolen', coalesce(ist.stolen_quantity, 0),
          'expired', coalesce(ist.expired_quantity, 0),
          'open_box', coalesce(ist.open_box_quantity, 0)
        ),
        'shipment', case
          when sh.id is null then null
          else jsonb_build_object(
            'shipment', jsonb_build_object(
              'id', sh.id,
              'name', sh.name,
              'tenant_shipment_id', sh.tenant_shipment_id
            )
          )
        end
      ) as item_json
    from paged_batches pb
    left join public.inventory_stocks ist
      on ist.inventory_item_id = pb.inventory_item_id
    left join public.inventory_items ii
      on ii.id = pb.inventory_item_id
    left join public.shipment_items si
      on ii.source_type = 'shipment'
     and ii.source_id = si.id
    left join public.shipments sh
      on sh.id = si.shipment_id
  ),
  final_data as (
    -- Return one row per batch, mapping batch ID to product_id for frontend table compatibility
    select
      pb.inventory_item_id as product_id,
      pb.name,
      pb.image_url,
      pb.barcode,
      pb.product_code,
      spp.stock_override,
      spp.price_bdt,
      spp.minimum_sell_price_bdt,
      jsonb_build_array(bi.item_json) as items
    from paged_batches pb
    join batch_items bi on bi.inventory_item_id = pb.inventory_item_id
    left join public.store_product_prices spp
      on spp.store_id = p_store_id
     and spp.tenant_id = p_tenant_id
     and spp.inventory_item_id = pb.inventory_item_id
     and spp.is_active = true
  )
  select jsonb_build_object(
    'data', coalesce((select jsonb_agg(to_jsonb(fd)) from final_data fd), '[]'::jsonb),
    'meta', jsonb_build_object(
      'total', coalesce((select max(total_count) from counted), 0),
      'page', p_page,
      'page_size', p_page_size,
      'total_pages', case
        when coalesce((select max(total_count) from counted), 0) = 0 then 1
        else ceil(coalesce((select max(total_count) from counted), 0)::numeric / p_page_size)::int
      end
    )
  )
  into v_result;

  return v_result;
end;
$$;

commit;

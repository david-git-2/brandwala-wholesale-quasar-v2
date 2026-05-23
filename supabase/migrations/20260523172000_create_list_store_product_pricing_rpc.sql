-- ====================================================================
-- RPC to fetch grouped store product pricing with pagination
-- Handles search query, shipment filtering, and fetches pricing/shipments
-- ====================================================================

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
  with product_ids_in_shipment as (
    -- Get product IDs in that shipment
    select distinct ii.product_id
    from public.inventory_items ii
    join public.shipment_items si
      on ii.source_type = 'shipment'
     and ii.source_id = si.id
    where ii.tenant_id = p_tenant_id
      and ii.product_id is not null
      and ii.status = 'active'
      and si.shipment_id = p_shipment_id
  ),
  base_products as (
    -- Get all unique products that have active inventory items
    select distinct ii.product_id
    from public.inventory_items ii
    where ii.tenant_id = p_tenant_id
      and ii.product_id is not null
      and ii.status = 'active'
  ),
  target_products as (
    -- Apply shipment filter if active, otherwise use all base products
    select bp.product_id
    from base_products bp
    where (p_shipment_id is null or bp.product_id in (select product_id from product_ids_in_shipment))
  ),
  products_with_details as (
    -- Get product details and match search filter
    select
      p.id as product_id,
      p.name,
      p.image_url,
      p.barcode,
      p.product_code
    from public.products p
    join target_products tp
      on p.id = tp.product_id
    where p.tenant_id = p_tenant_id
      and (
        p_search is null
        or trim(p_search) = ''
        or p.name ilike ('%' || trim(p_search) || '%')
        or p.product_code ilike ('%' || trim(p_search) || '%')
        or p.barcode ilike ('%' || trim(p_search) || '%')
      )
  ),
  counted as (
    select *, count(*) over() as total_count
    from products_with_details
  ),
  paged_products as (
    select *
    from counted
    order by name asc, product_id asc
    limit p_page_size
    offset (p_page - 1) * p_page_size
  ),
  product_items as (
    -- Fetch shipments and costs only for products on the current page
    select
      ii.product_id,
      jsonb_build_object(
        'id', ii.id,
        'cost', ii.cost,
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
              'name', sh.name
            )
          )
        end
      ) as item_json
    from public.inventory_items ii
    left join public.inventory_stocks ist
      on ist.inventory_item_id = ii.id
    left join public.shipment_items si
      on ii.source_type = 'shipment'
     and ii.source_id = si.id
    left join public.shipments sh
      on sh.id = si.shipment_id
    where ii.tenant_id = p_tenant_id
      and ii.status = 'active'
      and ii.product_id in (select product_id from paged_products)
  ),
  grouped_items as (
    select
      product_id,
      coalesce(jsonb_agg(item_json), '[]'::jsonb) as items_list
    from product_items
    group by product_id
  ),
  final_data as (
    select
      pp.product_id,
      pp.name,
      pp.image_url,
      pp.barcode,
      pp.product_code,
      spp.price_bdt,
      spp.minimum_sell_price_bdt,
      coalesce(gi.items_list, '[]'::jsonb) as items
    from paged_products pp
    left join grouped_items gi
      on pp.product_id = gi.product_id
    left join public.store_product_prices spp
      on spp.store_id = p_store_id
     and spp.tenant_id = p_tenant_id
     and spp.product_id = pp.product_id
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

grant execute on function public.list_store_product_pricing(bigint, bigint, integer, integer, text, bigint) to authenticated;

-- Migration: Add note selection to list_store_product_pricing RPC nested items
begin;

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
              'name', sh.name
            )
          )
        end,
        'note', (
          select content
          from public.inventory_notes n
          where n.inventory_item_id = pb.inventory_item_id
          order by n.id desc
          limit 1
        )
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
      (
        select content
        from public.inventory_notes n
        where n.inventory_item_id = pb.inventory_item_id
        order by n.id desc
        limit 1
      ) as note,
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

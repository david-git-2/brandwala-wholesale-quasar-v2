CREATE FUNCTION public.list_allocatable_stock_paginated (
  p_tenant_id     bigint,
  p_page          integer DEFAULT 1,
  p_page_size     integer DEFAULT 20,
  p_search        text    DEFAULT NULL::text,
  p_shipment_id   bigint  DEFAULT NULL::bigint,
  p_stock_type_id bigint  DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  -- Get total count of matching stocks
  select count(distinct gs.id)
  into v_total_count
  from public.global_stocks gs
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.global_shipments gship on gship.id = gsi.shipment_id
  inner join public.global_stock_types gst on gst.id = gs.stock_type_id
  where gs.parent_tenant_id = p_tenant_id
    and gs.is_archived = false
    and gship.status = 'received'
    and gst.is_sellable = true
    and (p_shipment_id is null or gship.id = p_shipment_id)
    and (p_stock_type_id is null or gst.id = p_stock_type_id)
    and (
      p_search is null or p_search = '' or (
        gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
      )
    );

  -- Get paginated records as a jsonb array
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id,
      gs.parent_tenant_id,
      gs.shipment_item_id,
      gs.stock_type_id,
      gs.quantity as pool_quantity,
      gs.is_usable,
      gsi.name as item_name,
      gsi.product_code,
      gsi.barcode,
      gsi.image_url,
      gsi.purchase_price,
      gsi.product_weight,
      gsi.package_weight,
      gship.id as shipment_id,
      gship.name as shipment_name,
      gst.description as stock_type_description,
      gst.is_sellable,
      coalesce(sum(gsa.quantity), 0)::integer as allocated_qty,
      greatest(gs.quantity - coalesce(sum(gsa.quantity), 0), 0)::integer as unallocated_qty
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    inner join public.global_stock_types gst on gst.id = gs.stock_type_id
    left join public.global_stock_allocations gsa on gsa.stock_id = gs.id
    where gs.parent_tenant_id = p_tenant_id
      and gs.is_archived = false
      and gship.status = 'received'
      and gst.is_sellable = true
      and (p_shipment_id is null or gship.id = p_shipment_id)
      and (p_stock_type_id is null or gst.id = p_stock_type_id)
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
        )
      )
    group by gs.id, gsi.id, gship.id, gst.id
    order by gs.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  -- Calculate total pages
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
$function$;

GRANT ALL ON FUNCTION public.list_allocatable_stock_paginated(bigint, integer, integer, text, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.list_allocatable_stock_paginated(bigint, integer, integer, text, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_allocatable_stock_paginated(bigint, integer, integer, text, bigint, bigint) TO service_role;
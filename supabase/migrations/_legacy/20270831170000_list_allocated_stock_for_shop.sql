-- Shop settings Stock tab: all child-tenant allocated sellable warehouse rows for a shop.

create or replace function public.list_allocated_stock_for_shop(
  p_shop_id bigint,
  p_search text default null,
  p_limit integer default 200,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_shop_tenant_id bigint;
  v_total_count bigint;
  v_data jsonb;
  v_limit integer;
  v_offset integer;
begin
  select s.tenant_id into v_shop_tenant_id
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;

  if v_shop_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.has_active_tenant_membership(v_shop_tenant_id)
     and not public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_shop_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 200), 500));
  v_offset := greatest(0, coalesce(p_offset, 0));

  select count(distinct gs.id)
  into v_total_count
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.stock_locations sl on sl.id = gs.location_id
  left join public.tags tg on tg.id = gs.grade_tag_id
  where gship.assigned_child_tenant_id = v_shop_tenant_id
    and gship.status = 'received'
    and gs.availability = 'sellable'::public.stock_availability
    and (gs.location_id is null or sl.is_pickable = true)
    and (
      p_search is null
      or p_search = ''
      or (
        gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or gship.name ilike '%' || p_search || '%'
        or tg.name ilike '%' || p_search || '%'
      )
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id as sort_id,
      jsonb_build_object(
        'global_stock_id', gs.id,
        'shipment_item_id', gsi.id,
        'shipment_id', gship.id,
        'shipment_name', gship.name,
        'item_name', gsi.name,
        'product_id', gsi.product_id,
        'product_code', gsi.product_code,
        'barcode', gsi.barcode,
        'image_url', gsi.image_url,
        'product_brand', p.brand,
        'product_category', p.category,
        'available_atp', public.global_stock_atp_qty(gs.id),
        'total_stock_qty', gs.quantity,
        'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(gsi.id), 0.00),
        'stock_grade', case
          when tg.slug is not null then jsonb_build_object(
            'slug', tg.slug,
            'label', tg.name,
            'color', tg.color
          )
          else null
        end,
        'is_listed_on_shop', exists (
          select 1
          from public.shop_product_listings spl
          where spl.shop_id = p_shop_id
            and spl.global_stock_id = gs.id
        ),
        'listing_id', (
          select spl.id
          from public.shop_product_listings spl
          where spl.shop_id = p_shop_id
            and spl.global_stock_id = gs.id
          limit 1
        )
      ) as row_json
    from public.global_stocks gs
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    join public.global_shipments gship on gship.id = gsi.shipment_id
    join public.products p on p.id = gsi.product_id
    left join public.stock_locations sl on sl.id = gs.location_id
    left join public.tags tg on tg.id = gs.grade_tag_id
    where gship.assigned_child_tenant_id = v_shop_tenant_id
      and gship.status = 'received'
      and gs.availability = 'sellable'::public.stock_availability
      and (gs.location_id is null or sl.is_pickable = true)
      and (
        p_search is null
        or p_search = ''
        or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
          or tg.name ilike '%' || p_search || '%'
        )
      )
    order by gs.id desc
    limit v_limit
    offset v_offset
  ) q;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', (v_offset / v_limit) + 1,
      'page_size', v_limit,
      'total_pages', greatest(1, ceil(v_total_count::numeric / v_limit::numeric))
    )
  );
end;
$$;

grant execute on function public.list_allocated_stock_for_shop(bigint, text, integer, integer) to authenticated;

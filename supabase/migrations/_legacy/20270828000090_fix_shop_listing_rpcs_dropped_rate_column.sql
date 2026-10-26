-- Listing RPCs still referenced global_shipments.product_conversion_rate after that
-- column was dropped (20270814000030). PostgREST returned 400 and the Prices tab
-- could not load candidates or listings.

create or replace function public.list_listable_stock_for_shop(
  p_shop_id bigint,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_shop_tenant_id bigint;
  v_total_count bigint;
  v_data jsonb;
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

  select count(distinct gs.id)
  into v_total_count
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.stock_locations sl on sl.id = gs.location_id
  where gship.assigned_child_tenant_id = v_shop_tenant_id
    and gship.status = 'received'
    and gs.availability = 'sellable'::public.stock_availability
    and (gs.location_id is null or sl.is_pickable = true)
    and public.global_stock_atp_qty(gs.id) > 0
    and not exists (
      select 1 from public.shop_product_listings spl
      where spl.shop_id = p_shop_id
        and spl.global_stock_id = gs.id
        and spl.is_active = true
    )
    and (
      p_search is null or p_search = '' or (
        gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or gship.name ilike '%' || p_search || '%'
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
        'available_atp', public.global_stock_atp_qty(gs.id),
        'total_stock_qty', gs.quantity,
        'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(gsi.id), 0.00)
      ) as row_json
    from public.global_stocks gs
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.stock_locations sl on sl.id = gs.location_id
    where gship.assigned_child_tenant_id = v_shop_tenant_id
      and gship.status = 'received'
      and gs.availability = 'sellable'::public.stock_availability
      and (gs.location_id is null or sl.is_pickable = true)
      and public.global_stock_atp_qty(gs.id) > 0
      and not exists (
        select 1 from public.shop_product_listings spl
        where spl.shop_id = p_shop_id
          and spl.global_stock_id = gs.id
          and spl.is_active = true
      )
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
        )
      )
    order by gs.id desc
    limit p_limit
    offset p_offset
  ) q;

  return jsonb_build_object(
    'data', v_data,
    'total', v_total_count
  );
end;
$$;

grant execute on function public.list_listable_stock_for_shop(bigint, text, integer, integer) to authenticated;

create or replace function public.list_shop_product_listings(p_shop_id bigint)
returns table (
  id bigint,
  tenant_id bigint,
  shop_id bigint,
  global_stock_allocation_id bigint,
  global_stock_id bigint,
  product_id bigint,
  sell_price_amount numeric,
  sell_price_currency_id bigint,
  minimum_sell_price_amount numeric,
  minimum_sell_price_currency_id bigint,
  show_quantity boolean,
  display_quantity_override integer,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  product_name text,
  product_image_url text,
  product_barcode text,
  product_code text,
  product_brand text,
  product_category text,
  allocated_quantity integer,
  available_to_sell integer,
  unit_cost_amount numeric,
  shipment_item_id bigint,
  shipment_id bigint
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_tenant_id bigint;
begin
  select s.tenant_id into v_tenant_id
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;
  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.has_active_tenant_membership(v_tenant_id)
     and not public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  return query
  select
    l.id,
    l.tenant_id,
    l.shop_id,
    l.global_stock_allocation_id,
    coalesce(l.global_stock_id, gs.id) as global_stock_id,
    l.product_id,
    l.sell_price_amount,
    l.sell_price_currency_id,
    l.minimum_sell_price_amount,
    l.minimum_sell_price_currency_id,
    l.show_quantity,
    l.display_quantity_override,
    l.is_active,
    l.created_at,
    l.updated_at,
    gsi.name as product_name,
    gsi.image_url as product_image_url,
    gsi.barcode as product_barcode,
    gsi.product_code as product_code,
    p.brand as product_brand,
    p.category as product_category,
    gs.quantity::integer as allocated_quantity,
    greatest(0, floor(public.global_stock_atp_qty(coalesce(l.global_stock_id, gs.id))))::integer as available_to_sell,
    coalesce(public.calculate_landed_unit_cost(gs.shipment_item_id), 0.00)::numeric as unit_cost_amount,
    gs.shipment_item_id as shipment_item_id,
    gsi.shipment_id as shipment_id
  from public.shop_product_listings l
  left join public.products p on p.id = l.product_id
  left join public.global_stocks gs on gs.id = l.global_stock_id
  left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where l.shop_id = p_shop_id
  order by gsi.name asc;
end;
$$;

grant execute on function public.list_shop_product_listings(bigint) to authenticated;

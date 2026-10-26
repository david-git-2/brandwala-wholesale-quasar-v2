-- Shipment cutover completion: warehouse list, desk ATP, shop assign gate, vendor return payload

begin;

-- =========================================================
-- 1a. list_global_stocks_paginated — no header rates; availability/location/ATP
-- =========================================================

create or replace function public.list_global_stocks_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null,
  p_stock_type_id bigint default null,
  p_is_sellable boolean default null,
  p_shipment_status text default null,
  p_hide_zero_stock boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  select count(*)
  into v_total_count
  from public.global_stocks gs
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.global_shipments gship on gship.id = gsi.shipment_id
  inner join public.global_stock_types gst on gst.id = gs.stock_type_id
  where gs.parent_tenant_id = p_tenant_id
    and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
    and (p_is_sellable is null or gst.is_sellable = p_is_sellable)
    and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
    and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
    and (
      p_search is null or p_search = '' or (
        gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or gship.name ilike '%' || p_search || '%'
      )
    );

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id,
      gs.parent_tenant_id,
      gs.shipment_item_id,
      gs.stock_type_id,
      gs.quantity,
      gs.is_usable,
      gs.availability,
      gs.location_id,
      sl.name as location_name,
      gsi.shipment_id,
      gsi.ordered_quantity,
      gsi.name as item_name,
      gsi.product_code,
      gsi.barcode,
      gsi.image_url,
      gsi.purchase_price,
      gsi.product_weight,
      gsi.package_weight,
      gsi.landed_cost_bdt,
      coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) as resolved_landed_cost_bdt,
      gship.name as shipment_name,
      gship.type as shipment_type,
      gship.status as shipment_status,
      gship.received_weight,
      gst.description as stock_type_description,
      gst.is_sellable,
      public.global_stock_atp_qty(gs.id) as available_atp
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    inner join public.global_stock_types gst on gst.id = gs.stock_type_id
    left join public.stock_locations sl on sl.id = gs.location_id
    where gs.parent_tenant_id = p_tenant_id
      and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
      and (p_is_sellable is null or gst.is_sellable = p_is_sellable)
      and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
      and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
        )
      )
    order by gs.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

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
$$;

grant execute on function public.list_global_stocks_paginated(bigint, integer, integer, text, bigint, boolean, text, boolean) to authenticated;

-- =========================================================
-- 1b. search_stock_network — ATP, location, received status, assign gate
-- =========================================================
drop function if exists public.search_stock_network(
  bigint, text, text, text, bigint, text, bigint, boolean, integer, integer
) cascade;

create or replace function public.search_stock_network(
  p_context_tenant_id bigint,
  p_mode text default 'search',
  p_search text default null,
  p_search_field text default null,
  p_product_id bigint default null,
  p_status text default 'excellent',
  p_shipment_id bigint default null,
  p_exclude_zero_qty boolean default true,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  global_stock_id bigint,
  product_id bigint,
  name text,
  barcode text,
  product_code text,
  image_url text,
  shipment_item_id bigint,
  ordered_quantity integer,
  purchase_price numeric,
  product_weight numeric,
  package_weight numeric,
  shipment_type text,
  product_conversion_rate numeric,
  cargo_conversion_rate numeric,
  cargo_rate numeric,
  received_weight numeric,
  transaction_rate numeric,
  shipment_id bigint,
  shipment_name text,
  parent_tenant_id bigint,
  holding_tenant_id bigint,
  holding_tenant_name text,
  allocated_qty integer,
  global_qty integer,
  excellent_qty integer,
  box_less_qty integer,
  box_damage_qty integer,
  expired_qty integer,
  stolen_qty integer,
  reserved_qty integer,
  total_qty integer,
  is_own_tenant boolean,
  is_pickable boolean,
  sort_rank integer,
  product_group_key text,
  available_atp numeric,
  location_id bigint,
  location_name text
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_parent_id bigint;
  v_is_parent_context boolean;
  v_mode text;
begin
  v_mode := lower(coalesce(nullif(trim(p_mode), ''), 'search'));

  if p_context_tenant_id is null then
    raise exception 'context tenant is required';
  end if;

  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_context_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'not allowed';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_context_tenant_id);
  v_is_parent_context := (p_context_tenant_id = v_parent_id);

  return query
  with matched_stocks as (
    select
      gs.id as stock_id,
      gsi.product_id,
      gsi.name,
      gsi.barcode,
      gsi.product_code,
      gsi.image_url,
      gsi.id as shipment_item_id,
      gsi.shipment_id,
      gsi.ordered_quantity,
      gsi.purchase_price,
      gsi.product_weight,
      gsi.package_weight,
      sh.type::text as shipment_type,
      1.0::numeric as product_conversion_rate,
      1.0::numeric as cargo_conversion_rate,
      0::numeric as cargo_rate,
      sh.received_weight,
      1.0::numeric as transaction_rate,
      sh.name as shipment_name,
      gs.parent_tenant_id,
      coalesce(sum(gs.quantity) filter (where gst.description ilike '%Standard%' or gst.description ilike '%Sellable%'), 0)::integer as excellent_qty,
      coalesce(sum(gs.quantity) filter (where gst.description ilike '%Box Less%' or gst.description ilike '%Boxless%'), 0)::integer as box_less_qty,
      coalesce(sum(gs.quantity) filter (where gst.description ilike '%Box Damage%' or gst.description ilike '%Damage%'), 0)::integer as box_damage_qty,
      coalesce(sum(gs.quantity) filter (where gst.description ilike '%Expired%'), 0)::integer as expired_qty,
      coalesce(sum(gs.quantity) filter (where gst.description ilike '%Stolen%'), 0)::integer as stolen_qty,
      coalesce(sum(gs.quantity) filter (where gst.description ilike '%Reserved%'), 0)::integer as reserved_qty,
      coalesce(sum(gs.quantity), 0)::integer as total_qty,
      coalesce(sum(gs.quantity) filter (where 
        case p_status
          when 'excellent' then gst.description ilike '%Standard%' or gst.description ilike '%Sellable%'
          when 'box_less' then gst.description ilike '%Box Less%' or gst.description ilike '%Boxless%'
          when 'box_damage' then gst.description ilike '%Box Damage%' or gst.description ilike '%Damage%'
          when 'expired' then gst.description ilike '%Expired%'
          when 'stolen' then gst.description ilike '%Stolen%'
          when 'reserved' then gst.description ilike '%Reserved%'
          else false
        end
      ), 0)::integer as status_global_qty
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments sh on sh.id = gsi.shipment_id
    inner join public.global_stock_types gst on gst.id = gs.stock_type_id
    where gs.parent_tenant_id = v_parent_id
      and (
        v_is_parent_context
        or sh.assigned_child_tenant_id is null
        or sh.assigned_child_tenant_id = p_context_tenant_id
      )
      and sh.status = 'received'
      and (p_shipment_id is null or sh.id = p_shipment_id)
      and (p_product_id is null or gsi.product_id = p_product_id)
      and (
        p_search is null
        or trim(p_search) = ''
        or case coalesce(nullif(lower(trim(p_search_field)), ''), 'all')
          when 'name' then (
            select coalesce(bool_and(gsi.name ilike '%' || trim(word) || '%'), true)
            from unnest(string_to_array(trim(p_search), ' ')) as word
            where trim(word) <> ''
          )
          when 'barcode' then coalesce(gsi.barcode, '') ilike '%' || trim(p_search) || '%'
          when 'product_code' then coalesce(gsi.product_code, '') ilike '%' || trim(p_search) || '%'
          else (
            select coalesce(bool_and(
              gsi.name ilike '%' || trim(word) || '%'
              or coalesce(gsi.barcode, '') ilike '%' || trim(word) || '%'
              or coalesce(gsi.product_code, '') ilike '%' || trim(word) || '%'
            ), true)
            from unnest(string_to_array(trim(p_search), ' ')) as word
            where trim(word) <> ''
          )
        end
      )
    group by gs.id, gsi.id, gsi.product_id, gsi.name, gsi.barcode, gsi.product_code, gsi.image_url, gsi.ordered_quantity, gsi.purchase_price, gsi.product_weight, gsi.package_weight, gsi.shipment_id, sh.name, sh.type, sh.received_weight, gs.parent_tenant_id
    having (
      not coalesce(p_exclude_zero_qty, true)
      or coalesce(sum(gs.quantity), 0) > 0
    )
  ),
  child_allocations as (
    select
      ms.*,
      a.child_tenant_id as holding_tenant_id,
      t.name as holding_tenant_name,
      a.quantity as allocated_qty
    from matched_stocks ms
    inner join public.global_stock_allocations a
      on a.stock_id = ms.stock_id
      and a.parent_tenant_id = v_parent_id
      and a.child_tenant_id <> v_parent_id
    inner join public.tenants t on t.id = a.child_tenant_id
    where a.quantity > 0
  ),
  allocation_totals as (
    select
      ms.stock_id,
      coalesce(sum(ca.allocated_qty), 0)::integer as total_allocated
    from matched_stocks ms
    left join child_allocations ca on ca.stock_id = ms.stock_id
    group by ms.stock_id
  ),
  parent_pool as (
    select
      ms.*,
      v_parent_id as holding_tenant_id,
      pt.name as holding_tenant_name,
      greatest(ms.status_global_qty - coalesce(at.total_allocated, 0), 0)::integer as allocated_qty
    from matched_stocks ms
    inner join public.tenants pt on pt.id = v_parent_id
    left join allocation_totals at on at.stock_id = ms.stock_id
    where greatest(ms.status_global_qty - coalesce(at.total_allocated, 0), 0) > 0
  ),
  page_parent_rows as (
    select
      ms.stock_id as global_stock_id,
      ms.product_id,
      ms.name,
      ms.barcode,
      ms.product_code,
      ms.image_url,
      ms.shipment_item_id,
      ms.ordered_quantity,
      ms.purchase_price,
      ms.product_weight,
      ms.package_weight,
      ms.shipment_type,
      ms.product_conversion_rate,
      ms.cargo_conversion_rate,
      ms.cargo_rate,
      ms.received_weight,
      ms.transaction_rate,
      ms.shipment_id,
      ms.shipment_name,
      ms.parent_tenant_id,
      v_parent_id as holding_tenant_id,
      pt.name as holding_tenant_name,
      ms.status_global_qty as allocated_qty,
      ms.status_global_qty as global_qty,
      ms.excellent_qty,
      ms.box_less_qty,
      ms.box_damage_qty,
      ms.expired_qty,
      ms.stolen_qty,
      ms.reserved_qty,
      ms.total_qty,
      v_is_parent_context as is_own_tenant,
      ms.status_global_qty > 0 as is_pickable,
      case when v_is_parent_context then 0 else 1 end as sort_rank,
      coalesce(ms.product_id::text, 'stock:' || ms.stock_id::text) as product_group_key
    from matched_stocks ms
    inner join public.tenants pt on pt.id = v_parent_id
  ),
  page_child_rows as (
    select
      ms.stock_id as global_stock_id,
      ms.product_id,
      ms.name,
      ms.barcode,
      ms.product_code,
      ms.image_url,
      ms.shipment_item_id,
      ms.ordered_quantity,
      ms.purchase_price,
      ms.product_weight,
      ms.package_weight,
      ms.shipment_type,
      ms.product_conversion_rate,
      ms.cargo_conversion_rate,
      ms.cargo_rate,
      ms.received_weight,
      ms.transaction_rate,
      ms.shipment_id,
      ms.shipment_name,
      ms.parent_tenant_id,
      ca.holding_tenant_id,
      ca.holding_tenant_name,
      ca.allocated_qty,
      ms.status_global_qty as global_qty,
      ms.excellent_qty,
      ms.box_less_qty,
      ms.box_damage_qty,
      ms.expired_qty,
      ms.stolen_qty,
      ms.reserved_qty,
      ms.total_qty,
      true as is_own_tenant,
      ca.allocated_qty > 0 as is_pickable,
      0 as sort_rank,
      coalesce(ms.product_id::text, 'stock:' || ms.stock_id::text) as product_group_key
    from matched_stocks ms
    inner join child_allocations ca on ca.stock_id = ms.stock_id
    where ca.holding_tenant_id = p_context_tenant_id
  ),
  network_child_rows as (
    select
      ms.stock_id as global_stock_id,
      ms.product_id,
      ms.name,
      ms.barcode,
      ms.product_code,
      ms.image_url,
      ms.shipment_item_id,
      ms.ordered_quantity,
      ms.purchase_price,
      ms.product_weight,
      ms.package_weight,
      ms.shipment_type,
      ms.product_conversion_rate,
      ms.cargo_conversion_rate,
      ms.cargo_rate,
      ms.received_weight,
      ms.transaction_rate,
      ms.shipment_id,
      ms.shipment_name,
      ms.parent_tenant_id,
      ca.holding_tenant_id,
      ca.holding_tenant_name,
      ca.allocated_qty,
      ms.status_global_qty as global_qty,
      ms.excellent_qty,
      ms.box_less_qty,
      ms.box_damage_qty,
      ms.expired_qty,
      ms.stolen_qty,
      ms.reserved_qty,
      ms.total_qty,
      ca.holding_tenant_id = p_context_tenant_id as is_own_tenant,
      case
        when v_mode = 'invoice' then ms.status_global_qty > 0
        else ca.allocated_qty > 0
      end as is_pickable,
      case
        when ca.holding_tenant_id = p_context_tenant_id then 0
        else 2
      end as sort_rank,
      coalesce(ms.product_id::text, 'stock:' || ms.stock_id::text) as product_group_key
    from matched_stocks ms
    inner join child_allocations ca on ca.stock_id = ms.stock_id
  ),
  network_parent_rows as (
    select
      ms.stock_id as global_stock_id,
      ms.product_id,
      ms.name,
      ms.barcode,
      ms.product_code,
      ms.image_url,
      ms.shipment_item_id,
      ms.ordered_quantity,
      ms.purchase_price,
      ms.product_weight,
      ms.package_weight,
      ms.shipment_type,
      ms.product_conversion_rate,
      ms.cargo_conversion_rate,
      ms.cargo_rate,
      ms.received_weight,
      ms.transaction_rate,
      ms.shipment_id,
      ms.shipment_name,
      ms.parent_tenant_id,
      pp.holding_tenant_id,
      pp.holding_tenant_name,
      pp.allocated_qty,
      ms.status_global_qty as global_qty,
      ms.excellent_qty,
      ms.box_less_qty,
      ms.box_damage_qty,
      ms.expired_qty,
      ms.stolen_qty,
      ms.reserved_qty,
      ms.total_qty,
      v_is_parent_context as is_own_tenant,
      case
        when v_mode = 'invoice' then ms.status_global_qty > 0
        else pp.allocated_qty > 0
      end as is_pickable,
      1 as sort_rank,
      coalesce(ms.product_id::text, 'stock:' || ms.stock_id::text) as product_group_key
    from matched_stocks ms
    inner join parent_pool pp on pp.stock_id = ms.stock_id
  ),
  invoice_own_zero_rows as (
    select
      ms.stock_id as global_stock_id,
      ms.product_id,
      ms.name,
      ms.barcode,
      ms.product_code,
      ms.image_url,
      ms.shipment_item_id,
      ms.ordered_quantity,
      ms.purchase_price,
      ms.product_weight,
      ms.package_weight,
      ms.shipment_type,
      ms.product_conversion_rate,
      ms.cargo_conversion_rate,
      ms.cargo_rate,
      ms.received_weight,
      ms.transaction_rate,
      ms.shipment_id,
      ms.shipment_name,
      ms.parent_tenant_id,
      p_context_tenant_id as holding_tenant_id,
      ct.name as holding_tenant_name,
      0 as allocated_qty,
      ms.status_global_qty as global_qty,
      ms.excellent_qty,
      ms.box_less_qty,
      ms.box_damage_qty,
      ms.expired_qty,
      ms.stolen_qty,
      ms.reserved_qty,
      ms.total_qty,
      true as is_own_tenant,
      ms.status_global_qty > 0 as is_pickable,
      0 as sort_rank,
      coalesce(ms.product_id::text, 'stock:' || ms.stock_id::text) as product_group_key
    from matched_stocks ms
    inner join public.tenants ct on ct.id = p_context_tenant_id
    where v_mode = 'invoice'
      and not v_is_parent_context
      and ms.status_global_qty > 0
      and not exists (
        select 1
        from child_allocations ca
        where ca.stock_id = ms.stock_id
          and ca.holding_tenant_id = p_context_tenant_id
          and ca.allocated_qty > 0
      )
      and exists (
        select 1
        from child_allocations ca2
        where ca2.stock_id = ms.stock_id
          and ca2.holding_tenant_id <> p_context_tenant_id
          and ca2.allocated_qty > 0
      )
  ),
  combined as (
    select * from page_parent_rows where v_mode = 'page' and v_is_parent_context
    union all
    select * from page_child_rows where v_mode = 'page' and not v_is_parent_context
    union all
    select * from network_child_rows where v_mode in ('search', 'invoice')
    union all
    select * from network_parent_rows where v_mode in ('search', 'invoice')
    union all
    select * from invoice_own_zero_rows where v_mode = 'invoice'
  )
  select
    c.global_stock_id,
    c.product_id,
    c.name,
    c.barcode,
    c.product_code,
    c.image_url,
    c.shipment_item_id,
    c.ordered_quantity,
    c.purchase_price,
    c.product_weight,
    c.package_weight,
    c.shipment_type,
    c.product_conversion_rate,
    c.cargo_conversion_rate,
    c.cargo_rate,
    c.received_weight,
    c.transaction_rate,
    c.shipment_id,
    c.shipment_name,
    c.parent_tenant_id,
    c.holding_tenant_id,
    c.holding_tenant_name,
    c.allocated_qty,
    c.global_qty,
    c.excellent_qty,
    c.box_less_qty,
    c.box_damage_qty,
    c.expired_qty,
    c.stolen_qty,
    c.reserved_qty,
    c.total_qty,
    c.is_own_tenant,
    c.is_pickable,
    c.sort_rank,
    c.product_group_key,
    public.global_stock_atp_qty(c.global_stock_id) as available_atp,
    gs_loc.location_id,
    sl_loc.name as location_name
  from combined c
  inner join public.global_stocks gs_loc on gs_loc.id = c.global_stock_id
  left join public.stock_locations sl_loc on sl_loc.id = gs_loc.location_id
  order by
    c.product_group_key asc,
    c.sort_rank asc,
    c.is_own_tenant desc,
    c.holding_tenant_name asc nulls last,
    c.global_stock_id desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


create or replace function public.count_search_stock_network(
  p_context_tenant_id bigint,
  p_mode text default 'search',
  p_search text default null,
  p_search_field text default null,
  p_product_id bigint default null,
  p_status text default 'excellent',
  p_shipment_id bigint default null,
  p_exclude_zero_qty boolean default true
)
returns bigint
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_count bigint;
begin
  select count(*)::bigint into v_count
  from public.search_stock_network(
    p_context_tenant_id := p_context_tenant_id,
    p_mode := p_mode,
    p_search := p_search,
    p_search_field := p_search_field,
    p_product_id := p_product_id,
    p_status := p_status,
    p_shipment_id := p_shipment_id,
    p_exclude_zero_qty := p_exclude_zero_qty,
    p_limit := 100000,
    p_offset := 0
  );

  return coalesce(v_count, 0);
end;
$$;

grant execute on function public.search_stock_network(
  bigint, text, text, text, bigint, text, bigint, boolean, integer, integer
) to authenticated;

grant execute on function public.count_search_stock_network(
  bigint, text, text, text, bigint, text, bigint, boolean
) to authenticated;

-- =========================================================
-- 1c. browse_shop_catalog — assign gate + ATP qty
-- =========================================================
create or replace function public.browse_shop_catalog(
  p_shop_slug text,
  p_search text default null,
  p_category text default null,
  p_brand text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_shop_id bigint;
  v_tenant_id bigint;
  v_shop_name text;
  v_shop_type public.shop_type_enum;
  v_vendor_code text;
  v_order_mode public.shop_order_mode_enum;
  v_is_negotiable boolean;
  v_show_stock_quantity boolean;
  v_default_currency_id bigint;
  v_is_active boolean;
  v_buy_currency_id bigint;
  v_sell_currency_id bigint;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_quantity_display_mode text;
  v_vendor_filters jsonb;
  
  v_can_browse boolean;
  v_see_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;

  v_limit integer;
  v_offset integer;
  v_result jsonb;
begin
  -- Resolve the shop (slug unique per tenant)
  select 
    id, tenant_id, name, shop_type, vendor_code, order_mode, 
    is_negotiable, show_stock_quantity, default_currency_id, is_active,
    buy_currency_id, sell_currency_id, pricing_method, markup_percentage, quantity_display_mode,
    vendor_filters
  into 
    v_shop_id, v_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode,
    v_vendor_filters
  from public.shops
  where slug = p_shop_slug
    and tenant_id = public.current_tenant_id();

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  -- Resolve effective permissions
  select 
    can_browse, see_price, can_add_to_cart, can_place_order, 
    can_negotiate, can_view_quantity, can_set_dropship_price
  into 
    v_can_browse, v_see_price, v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  if v_shop_type = 'vendor_catalog' then
    execute format(
      $sql$
        with filtered as (
          select p.*
          from public.products p
          where p.is_available = true
            and (p.tenant_id = $2 or p.parent_tenant_id = $2)
            and (
              (($9 is null or jsonb_array_length($9) = 0) and p.vendor_code = $1)
              or
              ($9 is not null and jsonb_array_length($9) > 0 and exists (
                select 1 
                from jsonb_to_recordset($9) as vf(vendor_code text, brands text[])
                where vf.vendor_code = p.vendor_code
                  and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
              ))
            )
            and ($3 is null or trim($3) = '' or p.name ilike ('%%' || trim($3) || '%%') or p.product_code ilike ('%%' || trim($3) || '%%') or p.barcode ilike ('%%' || trim($3) || '%%'))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.category, '')) = lower(trim($4)))
            and ($5 is null or trim($5) = '' or lower(coalesce(p.brand, '')) = lower(trim($5)))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.name asc, f.id asc
          limit $6
          offset $7
        )
        select jsonb_build_object(
          'data',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'product_id', p.id,
                  'product_name', p.name,
                  'product_image_url', p.image_url,
                  'product_barcode', p.barcode,
                  'product_code', p.product_code,
                  'product_brand', p.brand,
                  'product_category', p.category,
                  'vendor_code', p.vendor_code,
                  'is_available', p.is_available,
                  'unit_price_amount', case when $8 then p.list_price_amount else null end,
                  'unit_price_currency_id', case when $8 then p.list_price_currency_id else null end,
                  'unit_price_currency_code', case when $8 then (select code from public.global_currencies where id = p.list_price_currency_id) else null end,
                  'unit_price_currency_symbol', case when $8 then (select symbol from public.global_currencies where id = p.list_price_currency_id) else null end,
                  'minimum_sell_price_amount', null,
                  'minimum_sell_price_currency_id', null,
                  'minimum_sell_price_currency_code', null,
                  'minimum_sell_price_currency_symbol', null,
                  'available_units', null,
                  'global_stock_allocation_id', null,
                  'global_stock_id', null,
                  'minimum_order_quantity', p.minimum_order_quantity
                )
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta',
          jsonb_build_object(
            'total', (select count(*) from filtered),
            'page', (($7 / $6) + 1),
            'page_size', $6,
            'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / $6::numeric))
          )
        )
      $sql$
    )
    into v_result
    using 
      v_vendor_code,
      v_tenant_id,
      p_search,
      p_category,
      p_brand,
      v_limit,
      v_offset,
      v_see_price,
      v_vendor_filters;
  else
    -- fixed_price or dropship
    execute format(
      $sql$
        with filtered as (
          select 
            l.id as listing_id,
            l.global_stock_allocation_id,
            l.global_stock_id,
            case 
              when $8 = 'fixed_price' and $11 = 'markup' then 
                coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + $12 / 100.0)
              when $8 = 'fixed_price' and $11 = 'direct_cost' then
                coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
              else 
                l.sell_price_amount
            end as computed_sell_price,
            l.sell_price_currency_id,
            l.minimum_sell_price_amount,
            l.minimum_sell_price_currency_id,
            l.show_quantity as listing_show_quantity,
            l.display_quantity_override,
            p.id as product_id,
            p.name as product_name,
            p.image_url as product_image_url,
            p.barcode as product_barcode,
            p.product_code as product_code,
            p.brand as product_brand,
            p.category as product_category,
            p.vendor_code as product_vendor_code,
            p.is_available as product_is_available,
            p.minimum_order_quantity as product_moq,
            gsa.quantity as allocation_qty,
            greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer as available_qty
          from public.shop_product_listings l
          join public.products p on p.id = l.product_id
          join public.global_stock_allocations gsa on gsa.id = l.global_stock_allocation_id
          join public.global_stocks gs on gs.id = gsa.stock_id
          left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
          left join public.global_shipments gship on gship.id = gsi.shipment_id
            and gship.assigned_child_tenant_id = $14
          where l.shop_id = $1
            and coalesce(gship.status, 'received') = 'received'
            and l.is_active = true
            and ($2 is null or trim($2) = '' or p.name ilike ('%%' || trim($2) || '%%') or p.product_code ilike ('%%' || trim($2) || '%%') or p.barcode ilike ('%%' || trim($2) || '%%'))
            and ($3 is null or trim($3) = '' or lower(coalesce(p.category, '')) = lower(trim($3)))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.brand, '')) = lower(trim($4)))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.product_name asc, f.listing_id asc
          limit $5
          offset $6
        )
        select jsonb_build_object(
          'data',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'product_id', p.product_id,
                  'product_name', p.product_name,
                  'product_image_url', p.product_image_url,
                  'product_barcode', p.product_barcode,
                  'product_code', p.product_code,
                  'product_brand', p.product_brand,
                  'product_category', p.product_category,
                  'vendor_code', p.product_vendor_code,
                  'is_available', p.product_is_available,
                  'unit_price_amount', case when $7 then p.computed_sell_price else null end,
                  'unit_price_currency_id', case when $7 then p.sell_price_currency_id else null end,
                  'unit_price_currency_code', case when $7 then (select code from public.global_currencies where id = p.sell_price_currency_id) else null end,
                  'unit_price_currency_symbol', case when $7 then (select symbol from public.global_currencies where id = p.sell_price_currency_id) else null end,
                  'minimum_sell_price_amount', case when $7 and $8 = 'dropship' then p.minimum_sell_price_amount else null end,
                  'minimum_sell_price_currency_id', case when $7 and $8 = 'dropship' then p.minimum_sell_price_currency_id else null end,
                  'minimum_sell_price_currency_code', case when $7 and $8 = 'dropship' then (select code from public.global_currencies where id = p.minimum_sell_price_currency_id) else null end,
                  'minimum_sell_price_currency_symbol', case when $7 and $8 = 'dropship' then (select symbol from public.global_currencies where id = p.minimum_sell_price_currency_id) else null end,
                  'available_units', case 
                    when not $9 or not coalesce(p.listing_show_quantity, $10) then null
                    when $13 = 'original' then greatest(0, p.available_qty)
                    when p.display_quantity_override is not null then p.display_quantity_override
                    else greatest(0, p.available_qty)
                  end,
                  'global_stock_allocation_id', p.global_stock_allocation_id,
                  'global_stock_id', p.global_stock_id,
                  'minimum_order_quantity', p.product_moq
                )
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta',
          jsonb_build_object(
            'total', (select count(*) from filtered),
            'page', (($6 / $5) + 1),
            'page_size', $5,
            'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / $5::numeric))
          )
        )
      $sql$
    )
    into v_result
    using 
      v_shop_id,
      p_search,
      p_category,
      p_brand,
      v_limit,
      v_offset,
      v_see_price,
      v_shop_type,
      v_can_view_quantity,
      v_show_stock_quantity,
      v_pricing_method,
      v_markup_percentage,
      v_quantity_display_mode,
      v_tenant_id;
  end if;

  -- Add shop & permissions info to metadata
  v_result := jsonb_set(v_result, '{meta, shop}', jsonb_build_object(
    'id', v_shop_id,
    'name', v_shop_name,
    'slug', p_shop_slug,
    'shop_type', v_shop_type,
    'vendor_code', v_vendor_code,
    'order_mode', v_order_mode,
    'is_negotiable', v_is_negotiable,
    'show_stock_quantity', v_show_stock_quantity,
    'default_currency_id', v_default_currency_id,
    'is_active', v_is_active,
    'buy_currency_id', v_buy_currency_id,
    'sell_currency_id', v_sell_currency_id,
    'pricing_method', v_pricing_method,
    'markup_percentage', v_markup_percentage,
    'quantity_display_mode', v_quantity_display_mode,
    'vendor_filters', v_vendor_filters
  ));

  return v_result;
end;
$$;

grant execute on function public.browse_shop_catalog(text, text, text, text, integer, integer) to authenticated;

-- =========================================================
-- 1c. add_to_shop_cart — global_stock_id + ATP check
-- =========================================================
drop function if exists public.add_to_shop_cart(bigint, bigint, bigint, integer, numeric, bigint);

create or replace function public.add_to_shop_cart(
  p_shop_id bigint,
  p_product_id bigint,
  p_global_stock_allocation_id bigint default null,
  p_quantity integer default 1,
  p_customer_sell_price_amount numeric default null,
  p_customer_sell_price_currency_id bigint default null,
  p_global_stock_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart_res jsonb;
  v_cart_id bigint;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_prod_name text;
  v_prod_image text;
  v_prod_vendor text;
  v_prod_is_available boolean;
  v_prod_price_amount numeric;
  v_prod_price_currency_id bigint;
  
  v_listing_id bigint;
  v_global_stock_id bigint;
  v_sell_price_amount numeric;
  v_sell_price_currency_id bigint;
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
  v_display_qty_override integer;
  v_landed_cost numeric;
  
  v_allocated_qty integer;
  v_other_reserved_qty integer;
  v_available_to_sell integer;
  
  v_existing_item_id bigint;
  v_existing_item_qty integer;
  v_target_qty integer;
  
  v_can_add_to_cart boolean;
  v_can_set_dropship_price boolean;
  v_customer_sell_price_amount numeric;
  v_customer_sell_price_currency_id bigint;
begin
  -- 1. Resolve / verify cart
  v_cart_res := public.get_or_create_shop_cart(p_shop_id);
  v_cart_id := (v_cart_res->'cart'->>'id')::bigint;
  
  select 
    tenant_id, shop_type, pricing_method, markup_percentage 
  into 
    v_tenant_id, v_shop_type, v_pricing_method, v_markup_percentage 
  from public.shops 
  where id = p_shop_id;
  
  -- Check permission to add to cart
  select can_add_to_cart, can_set_dropship_price
  into v_can_add_to_cart, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(p_shop_id);
  
  if coalesce(v_can_add_to_cart, false) is not true then
    raise exception 'cart additions not allowed';
  end if;

  -- 2. Resolve product details
  select name, image_url, vendor_code, is_available, list_price_amount, list_price_currency_id
  into v_prod_name, v_prod_image, v_prod_vendor, v_prod_is_available, v_prod_price_amount, v_prod_price_currency_id
  from public.products
  where id = p_product_id;
  
  if v_prod_name is null then
    raise exception 'product not found';
  end if;

  -- 3. If fixed_price or dropship, enforce allocation matching
  if v_shop_type in ('fixed_price', 'dropship') then
    if p_global_stock_allocation_id is null then
      raise exception 'global stock allocation required for this shop type';
    end if;

    select 
      l.id, l.global_stock_id, l.sell_price_amount, l.sell_price_currency_id,
      l.minimum_sell_price_amount, l.minimum_sell_price_currency_id, l.display_quantity_override,
      gsa.quantity
    into 
      v_listing_id, v_global_stock_id, v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id, v_display_qty_override,
      v_allocated_qty
    from public.shop_product_listings l
    join public.global_stock_allocations gsa on gsa.id = l.global_stock_allocation_id
    where l.shop_id = p_shop_id
      and l.global_stock_allocation_id = p_global_stock_allocation_id
      and l.product_id = p_product_id
      and l.is_active = true;

    if v_listing_id is null then
      raise exception 'active product listing not found on this shop';
    end if;

    if p_global_stock_id is not null then
      v_global_stock_id := p_global_stock_id;
    end if;

    -- Dynamic pricing override for fixed_price retail shop
    if v_shop_type = 'fixed_price' then
      select coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
      into v_landed_cost
      from public.global_stocks gs
      join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      where gs.id = v_global_stock_id;

      if v_pricing_method = 'markup' then
        v_sell_price_amount := v_landed_cost * (1 + v_markup_percentage / 100.0);
      elsif v_pricing_method = 'direct_cost' then
        v_sell_price_amount := v_landed_cost;
      end if;
    end if;

    -- Calculate current quantity in the cart for this allocation
    select id, quantity into v_existing_item_id, v_existing_item_qty
    from public.shop_cart_items
    where cart_id = v_cart_id
      and global_stock_allocation_id = p_global_stock_allocation_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;

    -- Calculate other reservations (excluding ours)
    select coalesce(sum(quantity), 0)
    into v_other_reserved_qty
    from public.shop_stock_reservations r
    where r.global_stock_allocation_id = p_global_stock_allocation_id
      and r.cart_item_id <> coalesce(v_existing_item_id, -1);

    if v_global_stock_id is not null then
      v_available_to_sell := greatest(0, floor(public.global_stock_atp_qty(v_global_stock_id))::integer);
    else
      v_available_to_sell := v_allocated_qty - v_other_reserved_qty;
    end if;

    if v_target_qty > v_available_to_sell then
      raise exception 'insufficient stock: requested %, available %', v_target_qty, greatest(0, v_available_to_sell);
    end if;

    -- Handle dropship pricing
    if v_shop_type = 'dropship' then
      if coalesce(v_can_set_dropship_price, false) then
        -- Default to the regular sell price amount, but ensure it is not below minimum sell price floor if currencies match
        if p_customer_sell_price_amount is not null then
          v_customer_sell_price_amount := p_customer_sell_price_amount;
          v_customer_sell_price_currency_id := p_customer_sell_price_currency_id;
        else
          if v_sell_price_currency_id = v_min_sell_price_currency_id then
            v_customer_sell_price_amount := greatest(v_sell_price_amount, coalesce(v_min_sell_price_amount, 0));
          else
            v_customer_sell_price_amount := v_sell_price_amount;
          end if;
          v_customer_sell_price_currency_id := v_sell_price_currency_id;
        end if;
        
        -- Enforce minimum sell price floor
        if v_customer_sell_price_currency_id = v_min_sell_price_currency_id 
           and v_customer_sell_price_amount < v_min_sell_price_amount then
          raise exception 'price cannot be lower than the minimum sell price %', v_min_sell_price_amount;
        end if;
      else
        v_customer_sell_price_amount := v_sell_price_amount;
        v_customer_sell_price_currency_id := v_sell_price_currency_id;
      end if;
    end if;

  else
    -- Vendor catalog
    select id, quantity into v_existing_item_id, v_existing_item_qty
    from public.shop_cart_items
    where cart_id = v_cart_id
      and product_id = p_product_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;
  end if;

  -- 4. Upsert cart item
  if v_existing_item_id is not null then
    update public.shop_cart_items
    set 
      quantity = v_target_qty,
      unit_sell_price_amount = v_sell_price_amount,
      customer_sell_price_amount = coalesce(v_customer_sell_price_amount, customer_sell_price_amount),
      customer_sell_price_currency_id = coalesce(v_customer_sell_price_currency_id, customer_sell_price_currency_id),
      updated_at = now()
    where id = v_existing_item_id;
  else
    insert into public.shop_cart_items (
      cart_id, product_id, global_stock_id, global_stock_allocation_id,
      quantity, minimum_quantity,
      unit_list_price_amount, unit_list_price_currency_id,
      unit_sell_price_amount, unit_sell_price_currency_id,
      unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
      customer_sell_price_amount, customer_sell_price_currency_id,
      name, image_url
    )
    values (
      v_cart_id, p_product_id, v_global_stock_id, p_global_stock_allocation_id,
      p_quantity, 1,
      v_prod_price_amount, v_prod_price_currency_id,
      v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      v_prod_name, v_prod_image
    );
  end if;

  return public.get_or_create_shop_cart(p_shop_id);
end;
$$;


grant execute on function public.add_to_shop_cart(bigint, bigint, bigint, integer, numeric, bigint, bigint) to authenticated;

-- =========================================================
-- 1d. return_shipment_to_vendor — accept shipment_item_id
-- =========================================================

create or replace function public.return_shipment_to_vendor(
  p_shipment_id bigint,
  p_items_qty jsonb,
  p_outcome text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_item jsonb;
  v_stock_id bigint;
  v_shipment_item_id bigint;
  v_qty numeric;
  v_mov_id bigint;
  v_amount numeric := 0;
  v_ledger jsonb;
  v_vendor_id bigint;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if v_ship.status is distinct from 'received' then
    raise exception 'shipment must be received before return';
  end if;

  if p_outcome not in ('cash_refund', 'store_credit') then
    raise exception 'outcome must be cash_refund or store_credit';
  end if;

  if not public.has_active_tenant_membership(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  v_vendor_id := v_ship.vendor_id;

  insert into public.stock_movements (
    tenant_id, movement_no, movement_type, reference_type, reference_id, notes, created_by_email
  ) values (
    v_ship.parent_tenant_id,
    'VR-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('stock_movements_id_seq')::text, 6, '0'),
    'return_inbound',
    'shipment_return',
    p_shipment_id::text,
    'Vendor return outcome: ' || p_outcome,
    public.current_user_email()
  )
  returning id into v_mov_id;

  for v_item in select value from jsonb_array_elements(coalesce(p_items_qty, '[]'::jsonb))
  loop
    v_stock_id := (v_item->>'global_stock_id')::bigint;
    v_shipment_item_id := (v_item->>'shipment_item_id')::bigint;
    v_qty := coalesce((v_item->>'quantity')::numeric, 0);

    if v_stock_id is null and v_shipment_item_id is not null then
      select gs.id into v_stock_id
      from public.global_stocks gs
      join public.global_stock_types gst on gst.id = gs.stock_type_id
      where gs.shipment_item_id = v_shipment_item_id
        and gs.parent_tenant_id = v_ship.parent_tenant_id
        and gst.is_sellable = true
        and gs.availability = 'sellable'::public.stock_availability
      order by gs.quantity desc, gs.id
      limit 1;
    end if;

    if v_stock_id is null or v_qty <= 0 then
      continue;
    end if;

    insert into public.stock_movement_lines (
      movement_id, stock_id, quantity, from_availability, to_availability
    ) values (
      v_mov_id, v_stock_id, v_qty, 'sellable'::public.stock_availability, 'returned'::public.stock_availability
    );

    v_amount := v_amount + (v_qty * coalesce(
      (select gsi.landed_cost_bdt from public.global_stocks gs
       join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
       where gs.id = v_stock_id),
      0
    ));
  end loop;

  perform public.post_stock_movement(v_mov_id);

  if v_amount <= 0 then
    v_amount := coalesce((
      select sum(coalesce(e.amount, 0) * coalesce(e.exchange_rate, 1))
      from public.global_shipment_cost_entries e
      where e.shipment_id = p_shipment_id and e.cost_type = 'product'
    ), 0);
  end if;

  if p_outcome = 'cash_refund' then
    v_ledger := public.record_ledger_transaction(
      p_tenant_id => v_ship.parent_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_ship.parent_tenant_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_source_type => 'shipment_return',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object('outcome', 'cash_refund', 'movement_id', v_mov_id)
    );
    if v_vendor_id is not null then
      perform public.record_ledger_transaction(
        p_tenant_id => v_ship.parent_tenant_id,
        p_entity_type => 'vendor',
        p_entity_id => v_vendor_id,
        p_type => 'debit',
        p_amount => v_amount,
        p_currency_code => 'BDT',
        p_source_type => 'shipment_return',
        p_source_id => p_shipment_id::text,
        p_metadata => jsonb_build_object('outcome', 'cash_refund', 'movement_id', v_mov_id)
      );
    end if;
  else
    v_ledger := public.record_ledger_transaction(
      p_tenant_id => v_ship.parent_tenant_id,
      p_entity_type => 'vendor',
      p_entity_id => v_vendor_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_source_type => 'shipment_return',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object('outcome', 'store_credit', 'movement_id', v_mov_id)
    );
  end if;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'outcome', p_outcome,
    'movement_id', v_mov_id,
    'return_processed', true,
    'wallet_posted', true,
    'amount_bdt', v_amount
  );
end;
$$;

grant execute on function public.return_shipment_to_vendor(bigint, jsonb, text) to authenticated;

commit;

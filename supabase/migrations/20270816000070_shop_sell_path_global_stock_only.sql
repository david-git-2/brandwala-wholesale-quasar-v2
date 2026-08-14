-- Complete W5 shop sell path: browse/cart/search without global_stock_allocations.
-- Also add list_global_stocks_paginated p_availability.

begin;

-- =========================================================
-- 1. search_stock_network — ATP rows only, no allocation CTEs
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
  v_avail public.stock_availability;
begin
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

  v_avail := case lower(coalesce(nullif(trim(p_status), ''), 'excellent'))
    when 'excellent' then 'sellable'::public.stock_availability
    when 'sellable' then 'sellable'::public.stock_availability
    when 'held' then 'held'::public.stock_availability
    when 'hold' then 'held'::public.stock_availability
    when 'reserved' then 'held'::public.stock_availability
    when 'unsellable' then 'unsellable'::public.stock_availability
    when 'damaged' then 'unsellable'::public.stock_availability
    when 'box_damage' then 'unsellable'::public.stock_availability
    when 'box_less' then 'unsellable'::public.stock_availability
    when 'expired' then 'unsellable'::public.stock_availability
    when 'stolen' then 'unsellable'::public.stock_availability
    else null
  end;

  return query
  select
    gs.id as global_stock_id,
    gsi.product_id,
    gsi.name,
    gsi.barcode,
    gsi.product_code,
    gsi.image_url,
    gsi.id as shipment_item_id,
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
    gsi.shipment_id,
    sh.name as shipment_name,
    gs.parent_tenant_id,
    coalesce(sh.assigned_child_tenant_id, v_parent_id) as holding_tenant_id,
    coalesce(ht.name, pt.name) as holding_tenant_name,
    gs.quantity as allocated_qty,
    gs.quantity as global_qty,
    case when gs.availability = 'sellable' then gs.quantity else 0 end as excellent_qty,
    0 as box_less_qty,
    case when gs.availability = 'unsellable' then gs.quantity else 0 end as box_damage_qty,
    0 as expired_qty,
    0 as stolen_qty,
    case when gs.availability = 'held' then gs.quantity else 0 end as reserved_qty,
    gs.quantity as total_qty,
    (coalesce(sh.assigned_child_tenant_id, v_parent_id) = p_context_tenant_id) as is_own_tenant,
    (gs.availability = 'sellable' and (gs.location_id is null or sl.is_pickable = true)) as is_pickable,
    case
      when coalesce(sh.assigned_child_tenant_id, v_parent_id) = p_context_tenant_id then 0
      else 1
    end as sort_rank,
    coalesce(gsi.product_id::text, 'stock:' || gs.id::text) as product_group_key,
    public.global_stock_atp_qty(gs.id) as available_atp,
    gs.location_id,
    sl.name as location_name
  from public.global_stocks gs
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.global_shipments sh on sh.id = gsi.shipment_id
  inner join public.tenants pt on pt.id = v_parent_id
  left join public.tenants ht on ht.id = coalesce(sh.assigned_child_tenant_id, v_parent_id)
  left join public.stock_locations sl on sl.id = gs.location_id
  where gs.parent_tenant_id = v_parent_id
    and (
      v_is_parent_context
      or sh.assigned_child_tenant_id is null
      or sh.assigned_child_tenant_id = p_context_tenant_id
    )
    and sh.status = 'received'
    and (p_shipment_id is null or sh.id = p_shipment_id)
    and (p_product_id is null or gsi.product_id = p_product_id)
    and (v_avail is null or gs.availability = v_avail)
    and (not coalesce(p_exclude_zero_qty, true) or gs.quantity > 0)
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
            or coalesce(gsi.barcode, '') ilike '%' || trim(p_search) || '%'
            or coalesce(gsi.product_code, '') ilike '%' || trim(p_search) || '%'
          ), true)
          from unnest(string_to_array(trim(p_search), ' ')) as word
          where trim(word) <> ''
        )
      end
    )
  order by
    coalesce(gsi.product_id::text, 'stock:' || gs.id::text) asc,
    case
      when coalesce(sh.assigned_child_tenant_id, v_parent_id) = p_context_tenant_id then 0
      else 1
    end asc,
    gs.id desc
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
-- 2. browse_shop_catalog — join listings.global_stock_id only
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
    execute format(
      $sql$
        with filtered as (
          select
            l.id as listing_id,
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
            greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer as available_qty
          from public.shop_product_listings l
          join public.products p on p.id = l.product_id
          join public.global_stocks gs on gs.id = l.global_stock_id
          left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
          left join public.global_shipments gship on gship.id = gsi.shipment_id
            and gship.assigned_child_tenant_id = $14
          where l.shop_id = $1
            and l.global_stock_id is not null
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
                  'global_stock_allocation_id', p.global_stock_id,
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
-- 3. add_to_shop_cart — require global_stock_id, ATP only
-- =========================================================
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
  v_available_to_sell integer;
  v_existing_item_id bigint;
  v_existing_item_qty integer;
  v_target_qty integer;
  v_can_add_to_cart boolean;
  v_can_set_dropship_price boolean;
  v_customer_sell_price_amount numeric;
  v_customer_sell_price_currency_id bigint;
begin
  v_cart_res := public.get_or_create_shop_cart(p_shop_id);
  v_cart_id := (v_cart_res->'cart'->>'id')::bigint;

  select tenant_id, shop_type, pricing_method, markup_percentage
  into v_tenant_id, v_shop_type, v_pricing_method, v_markup_percentage
  from public.shops
  where id = p_shop_id;

  select can_add_to_cart, can_set_dropship_price
  into v_can_add_to_cart, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(p_shop_id);

  if coalesce(v_can_add_to_cart, false) is not true then
    raise exception 'cart additions not allowed';
  end if;

  select name, image_url, vendor_code, is_available, list_price_amount, list_price_currency_id
  into v_prod_name, v_prod_image, v_prod_vendor, v_prod_is_available, v_prod_price_amount, v_prod_price_currency_id
  from public.products
  where id = p_product_id;

  if v_prod_name is null then
    raise exception 'product not found';
  end if;

  v_global_stock_id := coalesce(p_global_stock_id, p_global_stock_allocation_id);

  if v_shop_type in ('fixed_price', 'dropship') then
    if v_global_stock_id is null then
      raise exception 'global stock required for this shop type';
    end if;

    select
      l.id, l.global_stock_id, l.sell_price_amount, l.sell_price_currency_id,
      l.minimum_sell_price_amount, l.minimum_sell_price_currency_id, l.display_quantity_override
    into
      v_listing_id, v_global_stock_id, v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id, v_display_qty_override
    from public.shop_product_listings l
    where l.shop_id = p_shop_id
      and l.global_stock_id = v_global_stock_id
      and l.product_id = p_product_id
      and l.is_active = true;

    if v_listing_id is null then
      raise exception 'active product listing not found on this shop';
    end if;

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

    select id, quantity into v_existing_item_id, v_existing_item_qty
    from public.shop_cart_items
    where cart_id = v_cart_id
      and global_stock_id = v_global_stock_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;
    v_available_to_sell := greatest(0, floor(public.global_stock_atp_qty(v_global_stock_id))::integer);

    if v_target_qty > v_available_to_sell then
      raise exception 'insufficient stock: requested %, available %', v_target_qty, v_available_to_sell;
    end if;

    if v_shop_type = 'dropship' then
      if coalesce(v_can_set_dropship_price, false) then
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
    select id, quantity into v_existing_item_id, v_existing_item_qty
    from public.shop_cart_items
    where cart_id = v_cart_id
      and product_id = p_product_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;
  end if;

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
      v_cart_id, p_product_id, v_global_stock_id, null,
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
-- 4. upsert listing — never write allocation id
-- =========================================================
create or replace function public.upsert_shop_product_listing(
  p_tenant_id bigint,
  p_shop_id bigint,
  p_global_stock_allocation_id bigint default null,
  p_sell_price_amount numeric default null,
  p_sell_price_currency_id bigint default null,
  p_minimum_sell_price_amount numeric default null,
  p_minimum_sell_price_currency_id bigint default null,
  p_show_quantity boolean default null,
  p_display_quantity_override integer default null,
  p_is_active boolean default true,
  p_id bigint default null,
  p_is_price_locked boolean default null,
  p_is_quantity_locked boolean default null,
  p_quantity_override_type text default null,
  p_global_stock_id bigint default null
)
returns setof public.shop_product_listings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_id bigint;
  v_target_stock_id bigint;
  v_existing record;
  v_price_locked boolean;
  v_qty_locked boolean;
  v_override_type text;
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_target_stock_id := coalesce(p_global_stock_id, p_global_stock_allocation_id);

  if v_target_stock_id is null then
    raise exception 'global stock not found';
  end if;

  select gsi.product_id into v_product_id
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gs.id = v_target_stock_id;

  if v_product_id is null then
    raise exception 'global stock not found';
  end if;

  if p_id is not null then
    select * into v_existing from public.shop_product_listings where id = p_id;
  else
    select * into v_existing from public.shop_product_listings
    where shop_id = p_shop_id and global_stock_id = v_target_stock_id;
  end if;

  v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
  v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
  v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

  return query
  insert into public.shop_product_listings (
    id,
    tenant_id,
    shop_id,
    global_stock_allocation_id,
    global_stock_id,
    product_id,
    sell_price_amount,
    sell_price_currency_id,
    minimum_sell_price_amount,
    minimum_sell_price_currency_id,
    show_quantity,
    display_quantity_override,
    is_active,
    is_price_locked,
    is_quantity_locked,
    quantity_override_type
  ) values (
    coalesce(p_id, nextval('public.shop_product_listings_id_seq')),
    p_tenant_id,
    p_shop_id,
    null,
    v_target_stock_id,
    v_product_id,
    p_sell_price_amount,
    p_sell_price_currency_id,
    p_minimum_sell_price_amount,
    p_minimum_sell_price_currency_id,
    p_show_quantity,
    p_display_quantity_override,
    coalesce(p_is_active, true),
    v_price_locked,
    v_qty_locked,
    v_override_type
  )
  on conflict (shop_id, global_stock_id) do update set
    sell_price_amount = excluded.sell_price_amount,
    sell_price_currency_id = excluded.sell_price_currency_id,
    minimum_sell_price_amount = excluded.minimum_sell_price_amount,
    minimum_sell_price_currency_id = excluded.minimum_sell_price_currency_id,
    show_quantity = coalesce(excluded.show_quantity, shop_product_listings.show_quantity),
    display_quantity_override = excluded.display_quantity_override,
    is_active = excluded.is_active,
    is_price_locked = excluded.is_price_locked,
    is_quantity_locked = excluded.is_quantity_locked,
    quantity_override_type = excluded.quantity_override_type,
    global_stock_allocation_id = null,
    updated_at = now()
  returning *;
end;
$$;

grant execute on function public.upsert_shop_product_listing(
  bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint, boolean, boolean, text, bigint
) to authenticated;

-- =========================================================
-- 5. Reservation trigger — global_stock_id only
-- =========================================================
create or replace function public.sync_shop_cart_item_reservation()
returns trigger language plpgsql as $$
begin
  if tg_op = 'DELETE' then
    delete from public.shop_stock_reservations where cart_item_id = old.id;
    return old;
  end if;

  if new.quantity > 0 and new.global_stock_id is not null then
    insert into public.shop_stock_reservations (cart_item_id, global_stock_id, global_stock_allocation_id, quantity)
    values (new.id, new.global_stock_id, null, new.quantity)
    on conflict (cart_item_id) do update set
      global_stock_id = excluded.global_stock_id,
      global_stock_allocation_id = null,
      quantity = excluded.quantity;
  else
    delete from public.shop_stock_reservations where cart_item_id = new.id;
  end if;

  return new;
end;
$$;

-- =========================================================
-- 6. list_global_stocks_paginated — p_availability
-- =========================================================
drop function if exists public.list_global_stocks_paginated(
  bigint, integer, integer, text, bigint, boolean, text, boolean, bigint
);

create or replace function public.list_global_stocks_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null,
  p_stock_type_id bigint default null,
  p_is_sellable boolean default null,
  p_shipment_status text default null,
  p_hide_zero_stock boolean default true,
  p_location_id bigint default null,
  p_availability public.stock_availability default null
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
  left join public.global_stock_types gst on gst.id = gs.stock_type_id
  where gs.parent_tenant_id = p_tenant_id
    and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
    and (p_availability is null or gs.availability = p_availability)
    and (
      p_is_sellable is null
      or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
      or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
    )
    and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
    and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
    and (p_location_id is null or gs.location_id = p_location_id)
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
      coalesce(gst.is_sellable, gs.availability = 'sellable') as is_sellable,
      public.global_stock_atp_qty(gs.id) as available_atp
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.global_stock_types gst on gst.id = gs.stock_type_id
    left join public.stock_locations sl on sl.id = gs.location_id
    where gs.parent_tenant_id = p_tenant_id
      and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
      and (p_availability is null or gs.availability = p_availability)
      and (
        p_is_sellable is null
        or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
        or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
      )
      and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
      and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
      and (p_location_id is null or gs.location_id = p_location_id)
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

grant execute on function public.list_global_stocks_paginated(
  bigint, integer, integer, text, bigint, boolean, text, boolean, bigint, public.stock_availability
) to authenticated;

commit;

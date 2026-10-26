-- Phase 2 (W5 Step 2.2): Shop RPC rewrite to sell from global_stock_id directly

begin;

-- 1. New RPC: list_listable_stock_for_shop
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
  select s.tenant_id into v_shop_tenant_id from public.shops s where s.id = p_shop_id;
  if v_shop_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.has_active_tenant_membership(v_shop_tenant_id)
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
        'unit_cost_amount', coalesce(
          public.calculate_landed_unit_cost(gsi.id),
          0.00
        )
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

-- 2. Update upsert_shop_product_listing to accept p_global_stock_id as primary identifier
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

  v_target_stock_id := coalesce(
    p_global_stock_id,
    p_global_stock_allocation_id
  );

  if v_target_stock_id is null then
    raise exception 'global stock not found';
  end if;

  select gsi.product_id into v_product_id
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gs.id = v_target_stock_id;

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
    p_global_stock_allocation_id,
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
    updated_at = now()
  returning *;
end;
$$;

grant execute on function public.upsert_shop_product_listing(
  bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint, boolean, boolean, text, bigint
) to authenticated;

-- 3. Update list_shop_product_listings to use global_stock_atp_qty directly
drop function if exists public.list_shop_product_listings(bigint);

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
  select s.tenant_id into v_tenant_id from public.shops s where s.id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not exists (
    select 1 from public.memberships m
    where m.tenant_id = v_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
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
    gs.quantity as allocated_quantity,
    greatest(0, floor(public.global_stock_atp_qty(coalesce(l.global_stock_id, gs.id))))::integer as available_to_sell,
    coalesce(
      public.calculate_landed_unit_cost(gs.shipment_item_id),
      0.00
    )::numeric as unit_cost_amount,
    gs.shipment_item_id as shipment_item_id,
    gsi.shipment_id as shipment_id
  from public.shop_product_listings l
  left join public.products p on p.id = l.product_id
  left join public.global_stocks gs on gs.id = l.global_stock_id
  left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  left join public.global_shipments gship on gship.id = gsi.shipment_id
  where l.shop_id = p_shop_id
  order by gsi.name asc;
end;
$$;

grant execute on function public.list_shop_product_listings(bigint) to authenticated;

-- 4. Stub retired allocation RPCs
create or replace function public.list_allocations_for_shop_pick(
  p_shop_id bigint,
  p_search text default null
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object('data', '[]'::jsonb, 'total', 0);
$$;

create or replace function public.upsert_global_stock_allocation(
  p_parent_tenant_id bigint,
  p_child_tenant_id bigint,
  p_stock_id bigint,
  p_quantity integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return jsonb_build_object('status', 'retired');
end;
$$;

create or replace function public.bulk_allocate_shipment_stock(
  p_shipment_id bigint,
  p_child_tenant_id bigint,
  p_allocations jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return jsonb_build_object('status', 'retired');
end;
$$;

commit;

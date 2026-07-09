-- Remove API cost from stock search; return costing inputs for client-side landed cost calculation.

begin;

-- Drop existing functions using cascade so dependant count function is dropped as well
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
  product_group_key text
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
      sh.product_conversion_rate,
      sh.cargo_conversion_rate,
      sh.cargo_rate,
      sh.received_weight,
      sh.transaction_rate,
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
      and sh.status = 'Ready Stock'
      and sh.stock_ready = true
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
    group by gs.id, gsi.id, gsi.product_id, gsi.name, gsi.barcode, gsi.product_code, gsi.image_url, gsi.ordered_quantity, gsi.purchase_price, gsi.product_weight, gsi.package_weight, gsi.shipment_id, sh.name, sh.type, sh.cargo_rate, sh.transaction_rate, sh.product_conversion_rate, sh.cargo_conversion_rate, sh.received_weight, gs.parent_tenant_id
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
    c.product_group_key
  from combined c
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
-- list_global_stocks_paginated: add shipment item ids for client costing
-- =========================================================
drop function if exists public.list_global_stocks_paginated(bigint, integer, integer, text, bigint, boolean, text, boolean);

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
      gs.*,
      gsi.id as shipment_item_id,
      gsi.shipment_id,
      gsi.ordered_quantity,
      gsi.name as item_name,
      gsi.product_code,
      gsi.barcode,
      gsi.image_url,
      gsi.purchase_price,
      gsi.product_weight,
      gsi.package_weight,
      gship.name as shipment_name,
      gship.type as shipment_type,
      gship.status as shipment_status,
      gship.product_conversion_rate,
      gship.cargo_conversion_rate,
      gship.cargo_rate,
      gship.received_weight,
      gship.transaction_rate,
      gst.description as stock_type_description,
      gst.is_sellable
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
-- list_global_stock_allocations_paginated: add costing fields
-- =========================================================
drop function if exists public.list_global_stock_allocations_paginated(bigint, integer, integer, text, bigint, bigint);

create or replace function public.list_global_stock_allocations_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null,
  p_child_tenant_id bigint default null,
  p_stock_type_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_is_parent boolean;
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  select (parent_id is null) into v_is_parent from public.tenants where id = p_tenant_id;

  select count(*)
  into v_total_count
  from public.global_stock_allocations gsa
  inner join public.global_stocks gs on gs.id = gsa.stock_id
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.tenants child_t on child_t.id = gsa.child_tenant_id
  where (
    (v_is_parent and gsa.parent_tenant_id = p_tenant_id)
    or (not v_is_parent and gsa.child_tenant_id = p_tenant_id)
  )
  and (p_child_tenant_id is null or gsa.child_tenant_id = p_child_tenant_id)
  and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
  and (
    p_search is null or p_search = '' or (
      gsi.name ilike '%' || p_search || '%'
      or gsi.product_code ilike '%' || p_search || '%'
      or gsi.barcode ilike '%' || p_search || '%'
      or child_t.name ilike '%' || p_search || '%'
    )
  );

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      gsa.*,
      child_t.name as child_tenant_name,
      gs.quantity as pool_quantity,
      gs.is_usable,
      gsi.id as shipment_item_id,
      gsi.shipment_id,
      gsi.ordered_quantity,
      gsi.name as item_name,
      gsi.product_code,
      gsi.barcode,
      gsi.image_url,
      gsi.purchase_price,
      gsi.product_weight,
      gsi.package_weight,
      gship.name as shipment_name,
      gship.type as shipment_type,
      gship.status as shipment_status,
      gship.product_conversion_rate,
      gship.cargo_conversion_rate,
      gship.cargo_rate,
      gship.received_weight,
      gship.transaction_rate,
      gst.description as stock_type_description,
      gst.is_sellable
    from public.global_stock_allocations gsa
    inner join public.global_stocks gs on gs.id = gsa.stock_id
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    inner join public.global_stock_types gst on gst.id = gs.stock_type_id
    inner join public.tenants child_t on child_t.id = gsa.child_tenant_id
    where (
      (v_is_parent and gsa.parent_tenant_id = p_tenant_id)
      or (not v_is_parent and gsa.child_tenant_id = p_tenant_id)
    )
    and (p_child_tenant_id is null or gsa.child_tenant_id = p_child_tenant_id)
    and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
    and (
      p_search is null or p_search = '' or (
        gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or child_t.name ilike '%' || p_search || '%'
      )
    )
    order by gsa.id desc
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

grant execute on function public.list_global_stock_allocations_paginated(bigint, integer, integer, text, bigint, bigint) to authenticated;

-- =========================================================
-- get_parent_cash_circulation: use calculate_landed_unit_cost
-- =========================================================
create or replace function public.get_parent_cash_circulation(
  p_parent_tenant_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_deposits numeric(12,2);
  v_withdrawals numeric(12,2);
  v_deployed numeric(12,2);
  v_ar_due numeric(12,2);
  v_ar_paid numeric(12,2);
  v_stock_cost numeric(12,2);
  v_profit_mtd numeric(12,2);
  v_payouts numeric(12,2);
begin
  if not public.user_can_manage_parent_tenant(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  select
    coalesce(sum(case when type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment') then amount else 0 end), 0),
    coalesce(sum(case when type in ('withdrawal', 'withdrawal_paid') then amount else 0 end), 0)
  into v_deposits, v_withdrawals
  from public.investor_transactions it
  where it.tenant_id = p_parent_tenant_id;

  select coalesce(sum(coalesce(allocated_cost, invested_amount)), 0) into v_deployed
  from public.shipment_investments
  where tenant_id = p_parent_tenant_id and status = 'active';

  select
    coalesce(sum(due_amount), 0),
    coalesce(sum(paid_amount), 0)
  into v_ar_due, v_ar_paid
  from public.global_invoices
  where parent_tenant_id = p_parent_tenant_id;

  select coalesce(sum(
    public.calculate_landed_unit_cost(gs.shipment_item_id) * gs.quantity
  ), 0) into v_stock_cost
  from public.global_stocks gs
  inner join public.global_stock_types gst on gst.id = gs.stock_type_id
  where gs.parent_tenant_id = p_parent_tenant_id
    and gst.is_sellable = true
    and gs.quantity > 0;

  with invoice_line_margin as (
    select
      ii.invoice_id,
      sum((ii.sell_price_amount - ii.unit_cost_price) * ii.quantity - ii.line_discount_amount) as lines_margin
    from public.global_invoice_items ii
    join public.global_invoices i on i.id = ii.invoice_id
    where i.parent_tenant_id = p_parent_tenant_id
      and i.invoice_status = 'posted'::public.global_invoice_status
      and i.invoice_date >= date_trunc('month', current_date)::date
    group by ii.invoice_id
  ),
  invoice_return_margin as (
    select
      ri.invoice_id,
      sum(ri.return_accounting_amount - (ii.unit_cost_price * ri.quantity)) as returns_margin
    from public.global_return_items ri
    join public.global_invoice_items ii on ii.id = ri.invoice_item_id
    join public.global_invoices i on i.id = ri.invoice_id
    where i.parent_tenant_id = p_parent_tenant_id
      and i.invoice_status = 'posted'::public.global_invoice_status
      and i.invoice_date >= date_trunc('month', current_date)::date
    group by ri.invoice_id
  )
  select coalesce(sum(
    coalesce(lm.lines_margin, 0.00)
      - i.discount_amount
      + (case
           when i.invoice_type = 'wholesale' or i.invoice_type = 'dropship' then i.shipping_charge
           when i.invoice_type = 'retail' then i.shipping_charge + i.cod_charge + i.print_charge + i.wrapping_charge
           else 0.00
         end)
      - coalesce(rm.returns_margin, 0.00)
  ), 0) into v_profit_mtd
  from public.global_invoices i
  left join invoice_line_margin lm on lm.invoice_id = i.id
  left join invoice_return_margin rm on rm.invoice_id = i.id
  where i.parent_tenant_id = p_parent_tenant_id
    and i.invoice_status = 'posted'::public.global_invoice_status
    and i.invoice_date >= date_trunc('month', current_date)::date;

  select coalesce(sum(amount), 0) into v_payouts
  from public.investor_transactions
  where tenant_id = p_parent_tenant_id
    and type in ('profit_payout', 'profit_reinvest');

  return jsonb_build_object(
    'investor_capital_in', v_deposits,
    'investor_capital_withdrawn', v_withdrawals,
    'investor_capital_deployed', v_deployed,
    'investor_capital_available', v_deposits - v_withdrawals - v_deployed,
    'customer_ar_due', v_ar_due,
    'customer_ar_paid', v_ar_paid,
    'stock_cost_in_circulation', v_stock_cost,
    'realized_profit_mtd', v_profit_mtd,
    'profit_distributed', v_payouts
  );
end;
$$;

grant execute on function public.get_parent_cash_circulation(bigint) to authenticated;

commit;

begin;

-- =========================================================
-- 1. list_global_shipments_paginated
-- =========================================================
drop function if exists public.list_global_shipments_paginated(bigint, integer, integer, text, text);

create or replace function public.list_global_shipments_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null,
  p_status text default null
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
  -- Get total count of matching shipments
  select count(*)
  into v_total_count
  from public.global_shipments s
  where s.parent_tenant_id = p_tenant_id
    and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
    and (
      p_search is null or p_search = '' or (
        s.name ilike '%' || p_search || '%'
        or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
      )
    );

  -- Get paginated records as a jsonb array
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select s.*, v.name as vendor_name
    from public.global_shipments s
    left join public.vendors v on v.id = s.vendor_id
    where s.parent_tenant_id = p_tenant_id
      and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
      and (
        p_search is null or p_search = '' or (
          s.name ilike '%' || p_search || '%'
          or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
        )
      )
    order by s.id desc
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
$$;

grant execute on function public.list_global_shipments_paginated(bigint, integer, integer, text, text) to authenticated;

-- =========================================================
-- 2. list_global_stocks_paginated
-- =========================================================
drop function if exists public.list_global_stocks_paginated(bigint, integer, integer, text);

create or replace function public.list_global_stocks_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null
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
  -- Get total count of matching stocks
  select count(*)
  into v_total_count
  from public.global_stocks gs
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.global_shipments gship on gship.id = gsi.shipment_id
  where gs.parent_tenant_id = p_tenant_id
    and (
      p_search is null or p_search = '' or (
        gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or gship.name ilike '%' || p_search || '%'
      )
    );

  -- Get paginated records as a jsonb array
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      gs.*,
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
$$;

grant execute on function public.list_global_stocks_paginated(bigint, integer, integer, text) to authenticated;

-- =========================================================
-- 3. list_global_stock_allocations_paginated
-- =========================================================
drop function if exists public.list_global_stock_allocations_paginated(bigint, integer, integer, text);

create or replace function public.list_global_stock_allocations_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null
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
  -- Resolve if calling tenant is a parent
  select (parent_id is null) into v_is_parent from public.tenants where id = p_tenant_id;

  -- Get total count of matching allocations
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
  and (
    p_search is null or p_search = '' or (
      gsi.name ilike '%' || p_search || '%'
      or gsi.product_code ilike '%' || p_search || '%'
      or gsi.barcode ilike '%' || p_search || '%'
      or child_t.name ilike '%' || p_search || '%'
    )
  );

  -- Get paginated records as a jsonb array
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      gsa.*,
      child_t.name as child_tenant_name,
      gs.quantity as pool_quantity,
      gs.is_usable,
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
$$;

grant execute on function public.list_global_stock_allocations_paginated(bigint, integer, integer, text) to authenticated;

commit;

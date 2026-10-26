begin;

-- =========================================================
-- 1. list_allocatable_stock_paginated
-- =========================================================
drop function if exists public.list_allocatable_stock_paginated(bigint, integer, integer, text, bigint, bigint);

create or replace function public.list_allocatable_stock_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null,
  p_shipment_id bigint default null,
  p_stock_type_id bigint default null
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
  select count(distinct gs.id)
  into v_total_count
  from public.global_stocks gs
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.global_shipments gship on gship.id = gsi.shipment_id
  inner join public.global_stock_types gst on gst.id = gs.stock_type_id
  where gs.parent_tenant_id = p_tenant_id
    and gship.status = 'Ready Stock'
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
      and gship.status = 'Ready Stock'
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
$$;

grant execute on function public.list_allocatable_stock_paginated(bigint, integer, integer, text, bigint, bigint) to authenticated;

-- =========================================================
-- 2. list_child_allocation_summary
-- =========================================================
drop function if exists public.list_child_allocation_summary(bigint);

create or replace function public.list_child_allocation_summary(
  p_stock_id bigint
)
returns table (
  child_tenant_id bigint,
  child_tenant_name text,
  allocation_id bigint,
  allocated_qty integer
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  return query
  select
    t.id as child_tenant_id,
    t.name as child_tenant_name,
    coalesce(gsa.id, 0)::bigint as allocation_id,
    coalesce(gsa.quantity, 0)::integer as allocated_qty
  from public.tenants t
  left join public.global_stock_allocations gsa on gsa.child_tenant_id = t.id and gsa.stock_id = p_stock_id
  where t.parent_id = (select parent_tenant_id from public.global_stocks where id = p_stock_id)
  order by t.name asc;
end;
$$;

grant execute on function public.list_child_allocation_summary(bigint) to authenticated;

-- =========================================================
-- 3. upsert_global_stock_allocation
-- =========================================================
drop function if exists public.upsert_global_stock_allocation(bigint, bigint, bigint, integer);

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
declare
  v_pool_qty integer;
  v_allocated_sum integer;
  v_shipment_status text;
  v_is_sellable boolean;
  v_upserted_row jsonb;
begin
  -- Check stock pool existence and characteristics
  select gs.quantity, gship.status, gst.is_sellable
  into v_pool_qty, v_shipment_status, v_is_sellable
  from public.global_stocks gs
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.global_shipments gship on gship.id = gsi.shipment_id
  inner join public.global_stock_types gst on gst.id = gs.stock_type_id
  where gs.id = p_stock_id and gs.parent_tenant_id = p_parent_tenant_id;

  if not found then
    raise exception 'Stock pool not found or does not belong to parent tenant';
  end if;

  if v_shipment_status <> 'Ready Stock' then
    raise exception 'Stock pool must be from a shipment in Ready Stock status';
  end if;

  if not v_is_sellable then
    raise exception 'Stock pool must be of a sellable stock type';
  end if;

  -- Check if child belongs to parent
  if not exists (select 1 from public.tenants where id = p_child_tenant_id and parent_id = p_parent_tenant_id) then
    raise exception 'Child tenant must belong to the parent tenant';
  end if;

  -- Calculate what the new sum would be
  select coalesce(sum(quantity), 0)::integer into v_allocated_sum
  from public.global_stock_allocations
  where stock_id = p_stock_id
    and child_tenant_id <> p_child_tenant_id;

  v_allocated_sum := v_allocated_sum + p_quantity;

  if v_allocated_sum > v_pool_qty then
    raise exception 'Total allocated quantity (%) exceeds stock pool quantity (%)', v_allocated_sum, v_pool_qty;
  end if;

  -- Upsert
  if p_quantity = 0 then
    delete from public.global_stock_allocations
    where child_tenant_id = p_child_tenant_id and stock_id = p_stock_id;
    
    v_upserted_row := jsonb_build_object('deleted', true);
  else
    insert into public.global_stock_allocations (parent_tenant_id, child_tenant_id, stock_id, quantity)
    values (p_parent_tenant_id, p_child_tenant_id, p_stock_id, p_quantity)
    on conflict (child_tenant_id, stock_id)
    do update set quantity = p_quantity, updated_at = now()
    returning row_to_json(public.global_stock_allocations.*)::jsonb into v_upserted_row;
  end if;

  return v_upserted_row;
end;
$$;

grant execute on function public.upsert_global_stock_allocation(bigint, bigint, bigint, integer) to authenticated;

-- =========================================================
-- 4. delete_global_stock_allocation
-- =========================================================
drop function if exists public.delete_global_stock_allocation(bigint);

create or replace function public.delete_global_stock_allocation(
  p_allocation_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.global_stock_allocations where id = p_allocation_id;
end;
$$;

grant execute on function public.delete_global_stock_allocation(bigint) to authenticated;

-- =========================================================
-- 5. get_allocation_reconciliation
-- =========================================================
drop function if exists public.get_allocation_reconciliation(bigint);

create or replace function public.get_allocation_reconciliation(
  p_stock_id bigint
)
returns table (
  stock_id bigint,
  global_qty integer,
  allocated_qty integer,
  unallocated_qty integer,
  is_reconciled boolean
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_global_qty integer;
  v_allocated_qty integer;
begin
  select quantity into v_global_qty
  from public.global_stocks
  where id = p_stock_id;

  select coalesce(sum(quantity), 0)::integer into v_allocated_qty
  from public.global_stock_allocations
  where stock_id = p_stock_id;

  return query
  select
    p_stock_id,
    coalesce(v_global_qty, 0),
    coalesce(v_allocated_qty, 0),
    greatest(coalesce(v_global_qty, 0) - coalesce(v_allocated_qty, 0), 0),
    coalesce(v_allocated_qty, 0) <= coalesce(v_global_qty, 0);
end;
$$;

grant execute on function public.get_allocation_reconciliation(bigint) to authenticated;

commit;

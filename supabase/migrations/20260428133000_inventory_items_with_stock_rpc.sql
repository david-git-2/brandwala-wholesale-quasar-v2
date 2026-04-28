begin;

create or replace function public.list_inventory_items_with_stock(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_sort_by text default 'id',
  p_sort_order text default 'desc',
  p_filters jsonb default '{}'::jsonb
)
returns table (
  id bigint,
  tenant_id bigint,
  source_type text,
  source_id bigint,
  name text,
  image_url text,
  cost numeric,
  manufacturing_date date,
  expire_date date,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  stock_id bigint,
  available_quantity integer,
  reserved_quantity integer,
  damaged_quantity integer,
  stolen_quantity integer,
  expired_quantity integer,
  stock_created_at timestamptz,
  stock_updated_at timestamptz,
  total_count bigint
)
language sql
security invoker
set search_path = public
stable
as $$
  with filtered as (
    select
      ii.id,
      ii.tenant_id,
      ii.source_type,
      ii.source_id,
      ii.name,
      ii.image_url,
      ii.cost,
      ii.manufacturing_date,
      ii.expire_date,
      ii.status,
      ii.created_at,
      ii.updated_at,
      s.id as stock_id,
      s.available_quantity,
      s.reserved_quantity,
      s.damaged_quantity,
      s.stolen_quantity,
      s.expired_quantity,
      s.created_at as stock_created_at,
      s.updated_at as stock_updated_at
    from public.inventory_items ii
    left join public.inventory_stocks s
      on s.inventory_item_id = ii.id
    where ii.tenant_id = p_tenant_id
      and (
        not (p_filters ? 'name')
        or ii.name ilike ('%' || coalesce(p_filters->>'name', '') || '%')
      )
      and (
        not (p_filters ? 'status')
        or ii.status = p_filters->>'status'
      )
      and (
        not (p_filters ? 'source_type')
        or ii.source_type = p_filters->>'source_type'
      )
      and (
        not (p_filters ? 'source_id')
        or ii.source_id = nullif(p_filters->>'source_id', '')::bigint
      )
  ),
  counted as (
    select
      filtered.*,
      count(*) over() as total_count
    from filtered
  )
  select *
  from counted
  order by
    case when lower(coalesce(p_sort_order, 'desc')) = 'asc' and lower(coalesce(p_sort_by, 'id')) = 'id' then id end asc,
    case when lower(coalesce(p_sort_order, 'desc')) = 'desc' and lower(coalesce(p_sort_by, 'id')) = 'id' then id end desc,
    case when lower(coalesce(p_sort_order, 'desc')) = 'asc' and lower(coalesce(p_sort_by, 'id')) = 'name' then name end asc,
    case when lower(coalesce(p_sort_order, 'desc')) = 'desc' and lower(coalesce(p_sort_by, 'id')) = 'name' then name end desc,
    case when lower(coalesce(p_sort_order, 'desc')) = 'asc' and lower(coalesce(p_sort_by, 'id')) = 'created_at' then created_at end asc,
    case when lower(coalesce(p_sort_order, 'desc')) = 'desc' and lower(coalesce(p_sort_by, 'id')) = 'created_at' then created_at end desc,
    id desc
  offset (greatest(coalesce(p_page, 1), 1) - 1) * greatest(coalesce(p_page_size, 20), 1)
  limit greatest(coalesce(p_page_size, 20), 1);
$$;

grant execute on function public.list_inventory_items_with_stock(bigint, integer, integer, text, text, jsonb)
to authenticated;

commit;

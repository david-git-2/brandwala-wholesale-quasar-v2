-- Extend global stock list RPC with search field, shipment filter, zero-qty exclusion, and count helper.

begin;

drop function if exists public.list_global_stock_for_tenant(bigint, text, integer, integer);

create or replace function public.list_global_stock_for_tenant(
  p_tenant_id bigint,
  p_search text default null,
  p_search_field text default null,
  p_shipment_id bigint default null,
  p_exclude_zero_qty boolean default true,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id bigint,
  tenant_id bigint,
  parent_tenant_id bigint,
  name text,
  cost numeric,
  shipment_id bigint,
  product_id bigint,
  barcode text,
  product_code text,
  image_url text,
  excellent_qty integer,
  box_less_qty integer,
  box_damage_qty integer,
  expired_qty integer,
  stolen_qty integer,
  reserved_qty integer,
  total_qty integer
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_parent_id bigint;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  return query
  select
    gs.id,
    gs.tenant_id,
    gs.parent_tenant_id,
    gs.name,
    gs.cost,
    gs.shipment_id,
    gs.product_id,
    gs.barcode,
    gs.product_code,
    gs.image_url,
    coalesce(sum(q.quantity) filter (where q.status = 'excellent'), 0)::integer as excellent_qty,
    coalesce(sum(q.quantity) filter (where q.status = 'box_less'), 0)::integer as box_less_qty,
    coalesce(sum(q.quantity) filter (where q.status = 'box_damage'), 0)::integer as box_damage_qty,
    coalesce(sum(q.quantity) filter (where q.status = 'expired'), 0)::integer as expired_qty,
    coalesce(sum(q.quantity) filter (where q.status = 'stolen'), 0)::integer as stolen_qty,
    coalesce(sum(q.quantity) filter (where q.status = 'reserved'), 0)::integer as reserved_qty,
    coalesce(sum(q.quantity), 0)::integer as total_qty
  from public.global_stocks gs
  left join public.global_stock_quantities q on q.stock_id = gs.id
  where gs.parent_tenant_id = v_parent_id
    and gs.status = 'active'
    and (
      p_tenant_id = v_parent_id
      or exists (
        select 1
        from public.child_tenant_stock_allocations a
        where a.stock_id = gs.id
          and a.child_tenant_id = p_tenant_id
          and a.quantity > 0
      )
    )
    and (p_shipment_id is null or gs.shipment_id = p_shipment_id)
    and (
      p_search is null
      or trim(p_search) = ''
      or case coalesce(nullif(lower(trim(p_search_field)), ''), 'all')
        when 'name' then gs.name ilike '%' || trim(p_search) || '%'
        when 'barcode' then coalesce(gs.barcode, '') ilike '%' || trim(p_search) || '%'
        when 'product_code' then coalesce(gs.product_code, '') ilike '%' || trim(p_search) || '%'
        else (
          gs.name ilike '%' || trim(p_search) || '%'
          or coalesce(gs.barcode, '') ilike '%' || trim(p_search) || '%'
          or coalesce(gs.product_code, '') ilike '%' || trim(p_search) || '%'
        )
      end
    )
  group by gs.id
  having (
    not coalesce(p_exclude_zero_qty, true)
    or coalesce(sum(q.quantity), 0) > 0
  )
  order by gs.id desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.count_global_stock_for_tenant(
  p_tenant_id bigint,
  p_search text default null,
  p_search_field text default null,
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
  v_parent_id bigint;
  v_count bigint;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select count(*)::bigint into v_count
  from (
    select gs.id
    from public.global_stocks gs
    left join public.global_stock_quantities q on q.stock_id = gs.id
    where gs.parent_tenant_id = v_parent_id
      and gs.status = 'active'
      and (
        p_tenant_id = v_parent_id
        or exists (
          select 1
          from public.child_tenant_stock_allocations a
          where a.stock_id = gs.id
            and a.child_tenant_id = p_tenant_id
            and a.quantity > 0
        )
      )
      and (p_shipment_id is null or gs.shipment_id = p_shipment_id)
      and (
        p_search is null
        or trim(p_search) = ''
        or case coalesce(nullif(lower(trim(p_search_field)), ''), 'all')
          when 'name' then gs.name ilike '%' || trim(p_search) || '%'
          when 'barcode' then coalesce(gs.barcode, '') ilike '%' || trim(p_search) || '%'
          when 'product_code' then coalesce(gs.product_code, '') ilike '%' || trim(p_search) || '%'
          else (
            gs.name ilike '%' || trim(p_search) || '%'
            or coalesce(gs.barcode, '') ilike '%' || trim(p_search) || '%'
            or coalesce(gs.product_code, '') ilike '%' || trim(p_search) || '%'
          )
        end
      )
    group by gs.id
    having (
      not coalesce(p_exclude_zero_qty, true)
      or coalesce(sum(q.quantity), 0) > 0
    )
  ) filtered;

  return coalesce(v_count, 0);
end;
$$;

grant execute on function public.list_global_stock_for_tenant(
  bigint, text, text, bigint, boolean, integer, integer
) to authenticated;

grant execute on function public.count_global_stock_for_tenant(
  bigint, text, text, bigint, boolean
) to authenticated;

commit;

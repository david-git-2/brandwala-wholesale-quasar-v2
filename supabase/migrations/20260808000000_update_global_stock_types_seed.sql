begin;

-- =========================================================
-- 1. Update existing stock type data and insert Box Less if missing
-- =========================================================

update public.global_stock_types
set is_sellable = true, updated_at = now()
where parent_tenant_id is null
  and description in ('Box Damage', 'Expired', 'Reserved');

update public.global_stock_types
set is_sellable = false, updated_at = now()
where parent_tenant_id is null
  and description = 'Stolen';

insert into public.global_stock_types (parent_tenant_id, description, is_sellable, sort_order)
select null, 'Box Less', true, 15
where not exists (
  select 1 from public.global_stock_types
  where parent_tenant_id is null and description = 'Box Less'
);

-- =========================================================
-- 2. Update search_stock_network function to handle Box Less
-- =========================================================

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
  cost numeric,
  shipment_id bigint,
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
      coalesce(
        case 
          when sh.type = 'domestic' then 
            (gsi.purchase_price + ((coalesce(gsi.product_weight, 0) + coalesce(gsi.package_weight, 0)) / 1000.0) * coalesce(sh.cargo_rate, 0))
          else 
            (gsi.purchase_price + ((coalesce(gsi.product_weight, 0) + coalesce(gsi.package_weight, 0)) / 1000.0) * coalesce(sh.cargo_rate, 0)) * 
            coalesce(sh.transaction_rate, (coalesce(sh.product_conversion_rate, 1.0) + coalesce(sh.cargo_conversion_rate, 1.0)) / 2.0)
        end,
        0
      )::numeric as cost,
      gsi.shipment_id,
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
          when 'name' then gsi.name ilike '%' || trim(p_search) || '%'
          when 'barcode' then coalesce(gsi.barcode, '') ilike '%' || trim(p_search) || '%'
          when 'product_code' then coalesce(gsi.product_code, '') ilike '%' || trim(p_search) || '%'
          else (
            gsi.name ilike '%' || trim(p_search) || '%'
            or coalesce(gsi.barcode, '') ilike '%' || trim(p_search) || '%'
            or coalesce(gsi.product_code, '') ilike '%' || trim(p_search) || '%'
          )
        end
      )
    group by gs.id, gsi.product_id, gsi.name, gsi.barcode, gsi.product_code, gsi.image_url, gsi.purchase_price, gsi.product_weight, gsi.package_weight, gsi.shipment_id, sh.type, sh.cargo_rate, sh.transaction_rate, sh.product_conversion_rate, sh.cargo_conversion_rate
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
      ms.cost,
      ms.shipment_id,
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
      ms.cost,
      ms.shipment_id,
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
      ms.cost,
      ms.shipment_id,
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
      ms.cost,
      ms.shipment_id,
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
      ms.cost,
      ms.shipment_id,
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
    c.cost,
    c.shipment_id,
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

commit;

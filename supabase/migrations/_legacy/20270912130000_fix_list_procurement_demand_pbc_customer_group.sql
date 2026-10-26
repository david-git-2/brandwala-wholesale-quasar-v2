-- PBC files link customer via billing_profiles, not a direct customer_group_id column.

begin;

create or replace function public.list_procurement_demand_groups(
  p_tenant_id bigint,
  p_procurement_status text default 'procuring',
  p_search text default null,
  p_child_tenant_id bigint default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_is_parent boolean;
  v_allowed boolean := false;
  v_status text := lower(trim(coalesce(p_procurement_status, 'procuring')));
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(coalesce(p_limit, 50), 1);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_groups jsonb := '[]'::jsonb;
  v_group_count integer := 0;
  v_item_count integer := 0;
  v_has_shop boolean := false;
  v_has_pbc boolean := false;
  v_sources text[] := '{}'::text[];
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then raise exception 'tenant not found: %', p_tenant_id; end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then raise exception 'access denied'; end if;
  if v_status not in ('procuring', 'ready_for_shipment', 'delivered') then
    raise exception 'invalid procurement status: %', v_status;
  end if;

  with tenant_scope as (
    select t.id as tenant_id from public.tenants t
    where ((v_is_parent and t.parent_id = p_tenant_id) or (not v_is_parent and t.id = p_tenant_id))
      and (p_child_tenant_id is null or t.id = p_child_tenant_id)
  ),
  shop_lines as (
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      public.normalize_shop_order_procurement_status(o.status) as document_status,
      o.customer_group_id,
      cg.name as customer_group_name,
      null::jsonb as vendor,
      'shop_order_item'::text as source_type,
      oi.id as source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') as barcode,
      coalesce(p.product_code, '') as product_code,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.customer_groups cg on cg.id = o.customer_group_id
    left join public.products p on p.id = oi.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'shop_order_item'
      and pd.source_id = oi.id
      and pd.tenant_id = o.tenant_id
    where o.shop_type_snapshot = 'vendor_catalog'
      and public.normalize_shop_order_procurement_status(o.status) = v_status
      and (
        v_search is null
        or oi.name ilike '%' || v_search || '%'
        or o.name ilike '%' || v_search || '%'
        or o.order_no ilike '%' || v_search || '%'
        or coalesce(p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  pbc_lines as (
    select
      'pbc_costing_file'::text as document_type,
      f.id as document_id,
      public.normalize_pbc_procurement_status(f.status) as document_status,
      bp.customer_group_id,
      cg.name as customer_group_name,
      case
        when v.id is not null then jsonb_build_object(
          'id', v.id,
          'code', coalesce(nullif(trim(f.vendor_code), ''), v.code),
          'name', v.name
        )
        when nullif(trim(f.vendor_code), '') is not null then jsonb_build_object(
          'id', f.vendor_id,
          'code', trim(f.vendor_code),
          'name', null
        )
        else null::jsonb
      end as vendor,
      'pbc_costing_item'::text as source_type,
      pci.id as source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url,
      coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.billing_profiles bp on bp.id = f.billing_profile_id
    left join public.customer_groups cg on cg.id = bp.customer_group_id
    left join public.products p on p.id = pci.product_id
    left join public.vendors v on v.id = f.vendor_id
    left join public.preorder_demand pd
      on pd.source_type = 'pbc_costing_item'
      and pd.source_id = pci.id
      and pd.tenant_id = f.tenant_id
    where f.billing_profile_id is not null
      and public.normalize_pbc_procurement_status(f.status) = v_status
      and (
        v_search is null
        or coalesce(pci.name, p.name, '') ilike '%' || v_search || '%'
        or coalesce(f.name, '') ilike '%' || v_search || '%'
        or coalesce(pci.barcode, p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(pci.product_code, p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  demand_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  eligible_lines as (
    select dl.*
    from demand_lines dl
    where dl.quantity > 0
      or dl.placed_quantity > 0
      or dl.delivered_quantity > 0
  ),
  grouped as (
    select
      el.document_type,
      el.document_id,
      max(el.document_status) as document_status,
      max(el.customer_group_id) as customer_group_id,
      max(el.customer_group_name) as customer_group_name,
      (array_agg(el.vendor) filter (where el.vendor is not null))[1] as vendor,
      jsonb_agg(
        jsonb_build_object(
          'source_type', el.source_type,
          'source_id', el.source_id,
          'product_id', el.product_id,
          'name', el.name,
          'image_url', el.image_url,
          'barcode', nullif(el.barcode, ''),
          'product_code', nullif(el.product_code, ''),
          'quantity', el.quantity,
          'need_quantity', el.quantity,
          'preorder_demand_id', el.preorder_demand_id,
          'vendor_id', el.vendor_id,
          'placed_quantity', el.placed_quantity,
          'delivered_quantity', el.delivered_quantity,
          'remaining_quantity', greatest(el.quantity - el.placed_quantity, 0),
          'remaining_to_deliver', greatest(el.placed_quantity - el.delivered_quantity, 0),
          'stock_picks', el.stock_picks
        )
        order by el.source_id
      ) as items,
      count(*)::integer as item_count
    from eligible_lines el
    group by el.document_type, el.document_id
  ),
  paged as (
    select g.*, count(*) over ()::integer as total_groups
    from grouped g
    order by g.document_type, g.document_id
    limit v_limit offset v_offset
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'document_type', p.document_type,
          'document_id', p.document_id,
          'document_status', p.document_status,
          'customer_group_id', p.customer_group_id,
          'customer_group_name', p.customer_group_name,
          'vendor', p.vendor,
          'items', p.items
        )
        order by p.document_type, p.document_id
      ),
      '[]'::jsonb
    ),
    coalesce(max(p.total_groups), 0),
    coalesce(sum(p.item_count), 0),
    coalesce(bool_or(p.document_type = 'shop_order'), false),
    coalesce(bool_or(p.document_type = 'pbc_costing_file'), false)
  into v_groups, v_group_count, v_item_count, v_has_shop, v_has_pbc
  from paged p;

  if v_has_shop then v_sources := array_append(v_sources, 'shop_order'); end if;
  if v_has_pbc then v_sources := array_append(v_sources, 'pbc_costing'); end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'tenant_id', p_tenant_id,
      'procurement_status', v_status,
      'sources_included', to_jsonb(v_sources),
      'group_count', coalesce(jsonb_array_length(v_groups), 0),
      'item_count', v_item_count,
      'total_group_count', v_group_count,
      'limit', v_limit,
      'offset', v_offset,
      'has_more', v_group_count > (v_offset + v_limit)
    ),
    'groups', v_groups
  );
end;
$$;

commit;

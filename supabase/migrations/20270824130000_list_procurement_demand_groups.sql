-- Aggregated procurement demand list (shop orders + PBC costing files)
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

  select (t.parent_id is null) into v_is_parent
  from public.tenants t
  where t.id = p_tenant_id;

  if not found then
    raise exception 'tenant not found: %', p_tenant_id;
  end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;

  if not coalesce(v_allowed, false) then
    raise exception 'access denied';
  end if;

  if v_status not in ('procuring', 'ready_for_shipment', 'delivered') then
    raise exception 'invalid procurement status: %', v_status;
  end if;

  with tenant_scope as (
    select t.id as tenant_id
    from public.tenants t
    where (
      (v_is_parent and t.parent_id = p_tenant_id)
      or (not v_is_parent and t.id = p_tenant_id)
    )
    and (p_child_tenant_id is null or t.id = p_child_tenant_id)
  ),
  shop_lines as (
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      o.status::text as document_status,
      null::jsonb as vendor,
      oi.id as source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') as barcode,
      coalesce(p.product_code, '') as product_code,
      greatest(
        coalesce(oi.confirmed_quantity, oi.quantity, 0) - coalesce(oi.delivered_quantity, 0),
        0
      )::integer as quantity
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.products p on p.id = oi.product_id
    where o.shop_type_snapshot = 'vendor_catalog'
      and (
        (v_status = 'procuring' and o.status = 'procuring'::public.shop_order_status)
        or (v_status = 'ready_for_shipment' and o.status = 'ready_for_shipment'::public.shop_order_status)
        or (v_status = 'delivered' and o.status = 'delivered'::public.shop_order_status)
      )
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
      f.status as document_status,
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
      pci.id as source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url,
      coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      greatest(
        case
          when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
            - coalesce(pci.ordered_quantity, 0)
        end,
        0
      )::integer as quantity
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.products p on p.id = pci.product_id
    left join public.vendors v on v.id = f.vendor_id
    where f.billing_profile_id is not null
      and (
        (v_status = 'procuring' and f.status = 'procuring')
        or (v_status = 'ready_for_shipment' and f.status = 'ready_for_shipment')
        or (v_status = 'delivered' and f.status = 'delivered')
      )
      and (
        v_search is null
        or coalesce(pci.name, p.name, '') ilike '%' || v_search || '%'
        or coalesce(f.name, '') ilike '%' || v_search || '%'
        or coalesce(pci.barcode, p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(pci.product_code, p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  all_lines as (
    select * from shop_lines where quantity > 0
    union all
    select * from pbc_lines where quantity > 0
  ),
  grouped as (
    select
      al.document_type,
      al.document_id,
      max(al.document_status) as document_status,
      (array_agg(al.vendor) filter (where al.vendor is not null))[1] as vendor,
      jsonb_agg(
        jsonb_build_object(
          'source_type', case when al.document_type = 'shop_order' then 'shop_order_item' else 'pbc_costing_item' end,
          'source_id', al.source_id,
          'product_id', al.product_id,
          'name', al.name,
          'image_url', al.image_url,
          'barcode', nullif(al.barcode, ''),
          'product_code', nullif(al.product_code, ''),
          'quantity', al.quantity
        )
        order by al.source_id
      ) as items,
      count(*)::integer as item_count
    from all_lines al
    group by al.document_type, al.document_id
  ),
  paged as (
    select
      g.*,
      count(*) over ()::integer as total_groups
    from grouped g
    order by g.document_type, g.document_id
    limit v_limit
    offset v_offset
  )
  select
    coalesce(jsonb_agg(
      jsonb_build_object(
        'document_type', p.document_type,
        'document_id', p.document_id,
        'document_status', p.document_status,
        'vendor', p.vendor,
        'items', p.items
      )
      order by p.document_type, p.document_id
    ), '[]'::jsonb),
    coalesce(max(p.total_groups), 0),
    coalesce(sum(p.item_count), 0),
    coalesce(bool_or(p.document_type = 'shop_order'), false),
    coalesce(bool_or(p.document_type = 'pbc_costing_file'), false)
  into v_groups, v_group_count, v_item_count, v_has_shop, v_has_pbc
  from paged p;

  if v_has_shop then
    v_sources := array_append(v_sources, 'shop_order');
  end if;
  if v_has_pbc then
    v_sources := array_append(v_sources, 'pbc_costing');
  end if;

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

grant execute on function public.list_procurement_demand_groups(bigint, text, text, bigint, integer, integer) to authenticated;

insert into public.modules (key, name, description, is_active, parent_module_key)
values (
  'procurement_demand',
  'Demand',
  'Aggregated procurement lines from shop orders and costing files.',
  true,
  'procurement_stock'
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values ('procurement_demand', 'view', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true,
  tenant_configurable = true;

insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
values
  ('app', 'admin', 'procurement_demand', 'view', true),
  ('app', 'staff', 'procurement_demand', 'view', true)
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

commit;

-- Fix: paged CTE was only in scope for the first statement in plpgsql.

CREATE OR REPLACE FUNCTION public.list_procurement_demand_group_items(
  p_tenant_id bigint,
  p_document_type text,
  p_document_id bigint,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_cursor_source_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 100));
  v_items jsonb := '[]'::jsonb;
  v_n integer := 0;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
  v_last_source_id bigint;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then raise exception 'tenant not found: %', p_tenant_id; end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then raise exception 'access denied'; end if;

  if v_doc_type not in ('shop_order', 'pbc_costing_file') then
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  with tenant_scope as (
    select t.id as tenant_id from public.tenants t
    where (
      (v_is_parent and (t.parent_id = p_tenant_id or t.id = p_tenant_id))
      or (not v_is_parent and t.id = p_tenant_id)
    )
  ),
  shop_lines as (
    select
      'shop_order'::text as document_type,
      o.id as document_id,
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
    left join public.products p on p.id = oi.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'shop_order_item'
      and pd.source_id = oi.id
      and pd.tenant_id = o.tenant_id
    where v_doc_type = 'shop_order'
      and o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog'
  ),
  pbc_lines as (
    select
      'pbc_costing_file'::text as document_type,
      f.id as document_id,
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
    left join public.products p on p.id = pci.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'pbc_costing_item'
      and pd.source_id = pci.id
      and pd.tenant_id = f.tenant_id
    where v_doc_type = 'pbc_costing_file'
      and f.id = p_document_id
      and f.billing_profile_id is not null
  ),
  demand_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  eligible_lines as (
    select dl.*
    from demand_lines dl
    where (
      dl.quantity > 0
      or dl.placed_quantity > 0
      or dl.delivered_quantity > 0
    )
      and (
        v_search is null
        or dl.name ilike '%' || v_search || '%'
        or coalesce(dl.barcode, '') ilike '%' || v_search || '%'
        or coalesce(dl.product_code, '') ilike '%' || v_search || '%'
      )
      and (
        p_cursor_source_id is null
        or dl.source_id > p_cursor_source_id
      )
  ),
  paged as (
    select el.*
    from eligible_lines el
    order by el.source_id
    limit v_limit + 1
  ),
  page_count as (
    select count(*)::integer as n from paged
  ),
  page_rows as (
    select p.*
    from paged p
    order by p.source_id
    limit v_limit
  ),
  item_json as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'source_type', row.source_type,
          'source_id', row.source_id,
          'product_id', row.product_id,
          'name', row.name,
          'image_url', row.image_url,
          'barcode', nullif(row.barcode, ''),
          'product_code', nullif(row.product_code, ''),
          'quantity', row.quantity,
          'need_quantity', row.quantity,
          'preorder_demand_id', row.preorder_demand_id,
          'vendor_id', row.vendor_id,
          'placed_quantity', row.placed_quantity,
          'delivered_quantity', row.delivered_quantity,
          'remaining_quantity', row.quantity - row.placed_quantity,
          'remaining_to_deliver', greatest(row.quantity - row.delivered_quantity, 0),
          'stock_picks', row.stock_picks
        )
        order by row.source_id
      ),
      '[]'::jsonb
    ) as items
    from page_rows row
  ),
  cursor_row as (
    select p.source_id
    from paged p
    order by p.source_id
    offset v_limit
    limit 1
  )
  select
    ij.items,
    pc.n,
    cr.source_id
  into v_items, v_n, v_last_source_id
  from item_json ij
  cross join page_count pc
  left join cursor_row cr on true;

  if v_n > v_limit then
    v_has_more := true;
    v_next_cursor := jsonb_build_object('source_id', v_last_source_id);
  end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'document_type', v_doc_type,
      'document_id', p_document_id,
      'limit', v_limit,
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    ),
    'items', v_items
  );
end;
$$;

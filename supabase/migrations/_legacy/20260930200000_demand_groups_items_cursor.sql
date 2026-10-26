-- Demand: slim groups list; cursor item pages; bulk vendor RPC
-- Bodies copied from supabase/schemas/procurement/03_rpcs.sql
CREATE OR REPLACE FUNCTION "public"."list_procurement_demand_groups"("p_tenant_id" bigint, "p_procurement_status" "text" DEFAULT 'procuring'::"text", "p_search" "text" DEFAULT NULL::"text", "p_child_tenant_id" bigint DEFAULT NULL::bigint, "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    where (
      (v_is_parent and (t.parent_id = p_tenant_id or t.id = p_tenant_id))
      or (not v_is_parent and t.id = p_tenant_id)
    )
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
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      o.global_invoice_id as invoice_id
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
      f.customer_group_id,
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
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      f.invoice_id
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.customer_groups cg on cg.id = f.customer_group_id
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
      max(el.invoice_id) as invoice_id,
      count(*)::integer as item_count,
      count(*) filter (where el.quantity > el.delivered_quantity)::integer as unallocated_item_count
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
          'invoice_id', p.invoice_id,
          'item_count', p.item_count,
          'unallocated_item_count', p.unallocated_item_count
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


ALTER FUNCTION "public"."list_procurement_demand_groups"("p_tenant_id" bigint, "p_procurement_status" "text", "p_search" "text", "p_child_tenant_id" bigint, "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."set_preorder_demand_vendor_for_document"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint, "p_vendor_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_updated integer := 0;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;
  if p_vendor_id is null then
    raise exception 'vendor_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
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

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_line_tenant_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_line_tenant_id is null then
      raise exception 'shop order not found or not vendor catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_line_tenant_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id
      and f.billing_profile_id is not null;

    if v_line_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_line_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_line_tenant_id <> p_tenant_id then
    if not exists (
      select 1
      from public.tenants t
      where t.id = v_line_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_parent_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand document';
    end if;
  end if;

  if v_doc_status <> 'procuring' then
    raise exception 'document is not open for vendor updates';
  end if;

  if v_doc_type = 'shop_order' then
    with lines as (
      select
        o.tenant_id,
        oi.id as source_id
      from public.shop_order_items oi
      inner join public.shop_orders o on o.id = oi.order_id
      where o.id = p_document_id
        and o.shop_type_snapshot = 'vendor_catalog'
    ),
    upserted as (
      insert into public.preorder_demand (
        tenant_id,
        source_type,
        source_id,
        vendor_id,
        placed_quantity,
        delivered_quantity,
        stock_picks,
        updated_by_user_id
      )
      select
        l.tenant_id,
        'shop_order_item'::public.preorder_demand_source_type,
        l.source_id,
        p_vendor_id,
        0,
        0,
        '[]'::jsonb,
        auth.uid()
      from lines l
      on conflict (source_type, source_id) do update set
        vendor_id = excluded.vendor_id,
        updated_by_user_id = auth.uid(),
        updated_at = now()
      returning 1
    )
    select count(*)::integer into v_updated from upserted;
  else
    with lines as (
      select
        f.tenant_id,
        pci.id as source_id
      from public.product_based_costing_items pci
      inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
      where f.id = p_document_id
        and f.billing_profile_id is not null
    ),
    upserted as (
      insert into public.preorder_demand (
        tenant_id,
        source_type,
        source_id,
        vendor_id,
        placed_quantity,
        delivered_quantity,
        stock_picks,
        updated_by_user_id
      )
      select
        l.tenant_id,
        'pbc_costing_item'::public.preorder_demand_source_type,
        l.source_id,
        p_vendor_id,
        0,
        0,
        '[]'::jsonb,
        auth.uid()
      from lines l
      on conflict (source_type, source_id) do update set
        vendor_id = excluded.vendor_id,
        updated_by_user_id = auth.uid(),
        updated_at = now()
      returning 1
    )
    select count(*)::integer into v_updated from upserted;
  end if;

  return jsonb_build_object(
    'document_type', v_doc_type,
    'document_id', p_document_id,
    'vendor_id', p_vendor_id,
    'updated_count', v_updated
  );
end;
$$;


ALTER FUNCTION "public"."set_preorder_demand_vendor_for_document"(bigint, text, bigint, bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_procurement_demand_group_items"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_cursor_source_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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
  )
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
  )
  into v_items
  from (
    select p.*
    from paged p
    order by p.source_id
    limit v_limit
  ) row;

  select count(*)::integer into v_n from paged;

  if v_n > v_limit then
    v_has_more := true;
    select p.source_id into v_last_source_id
    from paged p
    order by p.source_id
    offset v_limit
    limit 1;

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


ALTER FUNCTION "public"."list_procurement_demand_group_items"(bigint, text, bigint, text, integer, bigint) OWNER TO "postgres";

GRANT ALL ON FUNCTION public.set_preorder_demand_vendor_for_document(bigint, text, bigint, bigint) TO authenticated;
GRANT ALL ON FUNCTION public.list_procurement_demand_group_items(bigint, text, bigint, text, integer, bigint) TO authenticated;

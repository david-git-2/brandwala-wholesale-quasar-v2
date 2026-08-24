-- Drop line-level ordered/delivered qty from catalog orders and PBC items.
-- Shortfalls are tracked via customer_demand_bucket_items (see DEMAND_BUCKET.md).
begin;

-- ---------------------------------------------------------------------------
-- 1. Rewrite RPCs before dropping columns
-- ---------------------------------------------------------------------------

create or replace function public.staff_set_catalog_ordered_qty(
  p_order_id bigint,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_ordered_qty integer;
  v_item_row record;
  v_target_qty integer;
  v_shortfall integer;
  v_product record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_set_catalog_ordered_qty is only valid for vendor_catalog orders.';
  end if;

  for v_elem in select * from jsonb_array_elements(p_items) loop
    v_item_id := (v_elem->>'id')::bigint;
    v_ordered_qty := (v_elem->>'ordered_quantity')::integer;

    select * into v_item_row from public.shop_order_items where id = v_item_id and order_id = p_order_id;

    if v_item_row.id is not null then
      v_target_qty := coalesce(v_item_row.confirmed_quantity, v_item_row.quantity, 0);
      v_shortfall := v_target_qty - coalesce(v_ordered_qty, 0);

      if v_shortfall > 0 and v_order.billing_profile_id is not null then
        select p.barcode, p.product_code
        into v_product
        from public.products p
        where p.id = v_item_row.product_id;

        perform public.add_demand_bucket_item_internal(
          p_tenant_id => v_order.tenant_id,
          p_billing_profile_id => v_order.billing_profile_id,
          p_product_id => v_item_row.product_id,
          p_source_type => 'shop_order_item',
          p_source_id => v_item_id,
          p_snapshot => jsonb_build_object(
            'name', coalesce(v_item_row.name, ''),
            'image_url', v_item_row.image_url,
            'barcode', v_product.barcode,
            'product_code', v_product.product_code,
            'note', null
          ),
          p_quantity => v_shortfall
        );

        insert into public.customer_order_backlog_items (
          tenant_id,
          billing_profile_id,
          product_id,
          order_id,
          order_item_id,
          requested_quantity,
          fulfilled_quantity,
          backlog_status
        ) values (
          v_order.tenant_id,
          v_order.billing_profile_id,
          v_item_row.product_id,
          p_order_id,
          v_item_id,
          v_shortfall,
          0,
          'open'
        )
        on conflict (tenant_id, billing_profile_id, product_id)
        do update set
          requested_quantity = customer_order_backlog_items.requested_quantity + excluded.requested_quantity,
          backlog_status = 'open',
          updated_at = now();
      end if;
    end if;
  end loop;

  update public.shop_orders
  set
    status = 'ready_for_shipment'::public.shop_order_status,
    placed_at = coalesce(placed_at, now()),
    updated_at = now()
  where id = p_order_id;

  return public.get_shop_order_for_staff(v_order.tenant_id, p_order_id);
end;
$$;

create or replace function public.staff_set_catalog_delivered_qty(
  p_order_id bigint,
  p_items jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_set_catalog_delivered_qty is only valid for vendor_catalog orders.';
  end if;

  update public.shop_orders
  set
    status = 'delivered'::public.shop_order_status,
    fulfilled_at = coalesce(fulfilled_at, now()),
    updated_at = now()
  where id = p_order_id;

  return public.get_shop_order_for_staff(v_order.tenant_id, p_order_id);
end;
$$;

create or replace function public.staff_update_catalog_order_item_for_staff(
  p_tenant_id bigint,
  p_order_id bigint,
  p_item_id bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_product_id bigint;
  v_product_weight_gm numeric;
  v_package_weight_gm numeric;
begin
  if p_tenant_id is null or p_order_id is null or p_item_id is null then
    raise exception 'tenant, order, and item required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found or v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'order not found';
  end if;

  update public.shop_order_items soi
  set
    weight_kg = case when p_payload ? 'weight_kg' then (p_payload->>'weight_kg')::numeric else soi.weight_kg end,
    cost_price_amount = case when p_payload ? 'cost_price_amount' then (p_payload->>'cost_price_amount')::numeric else soi.cost_price_amount end,
    staff_offer_amount = case when p_payload ? 'staff_offer_amount' then (p_payload->>'staff_offer_amount')::numeric else soi.staff_offer_amount end,
    is_first_offer_manual = case when p_payload ? 'is_first_offer_manual' then coalesce((p_payload->>'is_first_offer_manual')::boolean, false) else soi.is_first_offer_manual end,
    customer_offer_amount = case when p_payload ? 'customer_offer_amount' then (p_payload->>'customer_offer_amount')::numeric else soi.customer_offer_amount end,
    customer_offer_currency_id = case when p_payload ? 'customer_offer_currency_id' then nullif(p_payload->>'customer_offer_currency_id', '')::bigint else soi.customer_offer_currency_id end,
    final_price_amount = case when p_payload ? 'final_price_amount' then (p_payload->>'final_price_amount')::numeric else soi.final_price_amount end,
    is_final_offer_manual = case when p_payload ? 'is_final_offer_manual' then coalesce((p_payload->>'is_final_offer_manual')::boolean, false) else soi.is_final_offer_manual end,
    confirmed_quantity = case when p_payload ? 'confirmed_quantity' then (p_payload->>'confirmed_quantity')::integer else soi.confirmed_quantity end,
    quantity = case when p_payload ? 'quantity' then (p_payload->>'quantity')::integer else soi.quantity end,
    updated_at = now()
  where soi.id = p_item_id and soi.order_id = p_order_id;

  select soi.product_id into v_product_id
  from public.shop_order_items soi
  where soi.id = p_item_id and soi.order_id = p_order_id;

  v_product_weight_gm := nullif(p_payload->>'product_weight_gm', '')::numeric;
  v_package_weight_gm := nullif(p_payload->>'package_weight_gm', '')::numeric;

  if v_product_id is not null
     and (
       (v_product_weight_gm is not null and v_product_weight_gm > 0)
       or (v_package_weight_gm is not null and v_package_weight_gm > 0)
     ) then
    update public.products p
    set
      product_weight = case
        when v_product_weight_gm is not null and v_product_weight_gm > 0 then v_product_weight_gm
        else p.product_weight
      end,
      package_weight = case
        when v_package_weight_gm is not null and v_package_weight_gm > 0 then v_package_weight_gm
        else p.package_weight
      end,
      updated_at = now()
    where p.id = v_product_id;
  end if;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Drop columns (shop orders first; PBC trigger must be updated before PBC cols)
-- ---------------------------------------------------------------------------

alter table public.shop_order_items
  drop column if exists ordered_quantity,
  drop column if exists delivered_quantity;

-- PBC backlog trigger still references ordered_quantity in UPDATE OF until recreated.
drop trigger if exists trg_pbc_items_auto_backlog on public.product_based_costing_items;

create trigger trg_pbc_items_auto_backlog
  after insert or delete or update of quantity, confirmed_quantity, product_id, price_gbp
  on public.product_based_costing_items
  for each row execute function public.trg_fn_auto_upsert_pbc_backlog();

alter table public.product_based_costing_items
  drop column if exists ordered_quantity,
  drop column if exists delivered_quantity;

-- ---------------------------------------------------------------------------
-- 3. Fix RPCs that referenced dropped columns
-- ---------------------------------------------------------------------------

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
    select 'shop_order'::text as document_type, o.id as document_id, o.status::text as document_status,
      null::jsonb as vendor, oi.id as source_id, oi.product_id, oi.name, oi.image_url,
      coalesce(p.barcode, '') as barcode, coalesce(p.product_code, '') as product_code,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.products p on p.id = oi.product_id
    where o.shop_type_snapshot = 'vendor_catalog'
      and ((v_status = 'procuring' and o.status = 'procuring'::public.shop_order_status)
        or (v_status = 'ready_for_shipment' and o.status = 'ready_for_shipment'::public.shop_order_status)
        or (v_status = 'delivered' and o.status = 'delivered'::public.shop_order_status))
      and (v_search is null or oi.name ilike '%' || v_search || '%' or o.name ilike '%' || v_search || '%'
        or o.order_no ilike '%' || v_search || '%' or coalesce(p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(p.product_code, '') ilike '%' || v_search || '%')
  ),
  pbc_lines as (
    select 'pbc_costing_file'::text as document_type, f.id as document_id, f.status as document_status,
      case when v.id is not null then jsonb_build_object('id', v.id, 'code', coalesce(nullif(trim(f.vendor_code), ''), v.code), 'name', v.name)
        when nullif(trim(f.vendor_code), '') is not null then jsonb_build_object('id', f.vendor_id, 'code', trim(f.vendor_code), 'name', null)
        else null::jsonb end as vendor,
      pci.id as source_id, pci.product_id, coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url, coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      greatest(case when pci.assigned_shipment_id is not null then 0
        else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0) end, 0)::integer as quantity
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.products p on p.id = pci.product_id
    left join public.vendors v on v.id = f.vendor_id
    where f.billing_profile_id is not null
      and ((v_status = 'procuring' and f.status = 'procuring')
        or (v_status = 'ready_for_shipment' and f.status = 'ready_for_shipment')
        or (v_status = 'delivered' and f.status = 'delivered'))
      and (v_search is null or coalesce(pci.name, p.name, '') ilike '%' || v_search || '%'
        or coalesce(f.name, '') ilike '%' || v_search || '%'
        or coalesce(pci.barcode, p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(pci.product_code, p.product_code, '') ilike '%' || v_search || '%')
  ),
  all_lines as (
    select * from shop_lines where quantity > 0
    union all
    select * from pbc_lines where quantity > 0
  ),
  grouped as (
    select al.document_type, al.document_id, max(al.document_status) as document_status,
      (array_agg(al.vendor) filter (where al.vendor is not null))[1] as vendor,
      jsonb_agg(jsonb_build_object(
        'source_type', case when al.document_type = 'shop_order' then 'shop_order_item' else 'pbc_costing_item' end,
        'source_id', al.source_id, 'product_id', al.product_id, 'name', al.name, 'image_url', al.image_url,
        'barcode', nullif(al.barcode, ''), 'product_code', nullif(al.product_code, ''), 'quantity', al.quantity
      ) order by al.source_id) as items,
      count(*)::integer as item_count
    from all_lines al
    group by al.document_type, al.document_id
  ),
  paged as (
    select g.*, count(*) over ()::integer as total_groups from grouped g
    order by g.document_type, g.document_id limit v_limit offset v_offset
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'document_type', p.document_type, 'document_id', p.document_id, 'document_status', p.document_status,
      'vendor', p.vendor, 'items', p.items) order by p.document_type, p.document_id), '[]'::jsonb),
    coalesce(max(p.total_groups), 0), coalesce(sum(p.item_count), 0),
    coalesce(bool_or(p.document_type = 'shop_order'), false), coalesce(bool_or(p.document_type = 'pbc_costing_file'), false)
  into v_groups, v_group_count, v_item_count, v_has_shop, v_has_pbc from paged p;

  if v_has_shop then v_sources := array_append(v_sources, 'shop_order'); end if;
  if v_has_pbc then v_sources := array_append(v_sources, 'pbc_costing'); end if;

  return jsonb_build_object(
    'meta', jsonb_build_object('tenant_id', p_tenant_id, 'procurement_status', v_status,
      'sources_included', to_jsonb(v_sources), 'group_count', coalesce(jsonb_array_length(v_groups), 0),
      'item_count', v_item_count, 'total_group_count', v_group_count, 'limit', v_limit, 'offset', v_offset,
      'has_more', v_group_count > (v_offset + v_limit)),
    'groups', v_groups);
end;
$$;

commit;

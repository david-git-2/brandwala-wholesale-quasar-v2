-- Migration: Shop Order Phase 8 — Fulfillment
begin;

-- =========================================================
-- 1. RPC: place_shop_order_for_procurement
-- =========================================================
create or replace function public.place_shop_order_for_procurement(p_order_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_status public.shop_order_status;
  v_type public.shop_type_enum;
begin
  select tenant_id, status, shop_type_snapshot
  into v_tenant_id, v_status, v_type
  from public.shop_orders
  where id = p_order_id;

  if v_tenant_id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_type <> 'vendor_catalog' then
    raise exception 'only vendor catalog orders can be placed for procurement';
  end if;

  if v_status <> 'confirmed' then
    raise exception 'order must be confirmed before placing';
  end if;

  update public.shop_orders
  set status = 'placed',
      placed_at = now(),
      updated_at = now()
  where id = p_order_id;
end;
$$;

grant execute on function public.place_shop_order_for_procurement(bigint) to authenticated;

-- =========================================================
-- 2. RPC: list_procurement_shop_order_lines
-- =========================================================
create or replace function public.list_procurement_shop_order_lines(
  p_parent_tenant_id bigint,
  p_child_tenant_id bigint default null,
  p_search text default null,
  p_limit integer default 100,
  p_offset integer default 0
)
returns table (
  source_type text,
  source_id bigint,
  child_tenant_id bigint,
  child_tenant_name text,
  name text,
  product_id bigint,
  quantity integer,
  cost_bdt numeric,
  price_gbp numeric,
  image_url text,
  barcode text,
  product_code text,
  reference_label text
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.user_can_manage_parent_tenant(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  select
    'shop_order_item'::text as source_type,
    oi.id as source_id,
    o.tenant_id as child_tenant_id,
    t.name as child_tenant_name,
    oi.name,
    oi.product_id,
    greatest(coalesce(oi.ordered_quantity, 0), 0)::integer as quantity,
    case when gc.code = 'BDT' then oi.final_price_amount else null::numeric end as cost_bdt,
    case when gc.code = 'GBP' then oi.final_price_amount else null::numeric end as price_gbp,
    oi.image_url,
    p.barcode,
    p.product_code,
    ('Shop Order #' || o.order_no || ' — ' || o.name) as reference_label
  from public.shop_order_items oi
  inner join public.shop_orders o on o.id = oi.order_id
  inner join public.tenants t on t.id = o.tenant_id
  left join public.products p on p.id = oi.product_id
  left join public.global_currencies gc on gc.id = oi.final_price_currency_id
  where o.status = 'placed'
    and oi.procurement_pulled = false
    and o.shop_type_snapshot = 'vendor_catalog'
    and t.parent_id = p_parent_tenant_id
    and (p_child_tenant_id is null or o.tenant_id = p_child_tenant_id)
    and (
      p_search is null or trim(p_search) = ''
      or oi.name ilike '%' || trim(p_search) || '%'
      or o.name ilike '%' || trim(p_search) || '%'
    )
  order by t.name, oi.id
  limit greatest(coalesce(p_limit, 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

grant execute on function public.list_procurement_shop_order_lines(bigint, bigint, text, integer, integer) to authenticated;

-- =========================================================
-- 3. Redefine list_child_procurement_lines to include shop orders
-- =========================================================
drop function if exists public.list_child_procurement_lines(bigint, bigint, text, integer, integer) cascade;

create or replace function public.list_child_procurement_lines(
  p_parent_tenant_id bigint,
  p_child_tenant_id bigint default null,
  p_search text default null,
  p_limit integer default 100,
  p_offset integer default 0
)
returns table (
  source_type text,
  source_id bigint,
  child_tenant_id bigint,
  child_tenant_name text,
  name text,
  product_id bigint,
  quantity integer,
  cost_bdt numeric,
  price_gbp numeric,
  image_url text,
  barcode text,
  product_code text,
  reference_label text
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.user_can_manage_parent_tenant(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  (
    select
      'order_item'::text as source_type,
      oi.id as source_id,
      o.tenant_id as child_tenant_id,
      t.name as child_tenant_name,
      oi.name,
      oi.product_id,
      greatest(coalesce(oi.ordered_quantity, 0), 0)::integer as quantity,
      oi.cost_bdt,
      oi.price_gbp,
      oi.image_url,
      null::text as barcode,
      null::text as product_code,
      ('Order #' || o.id::text || ' — ' || o.name) as reference_label
    from public.order_items oi
    inner join public.orders o on o.id = oi.order_id
    inner join public.tenants t on t.id = o.tenant_id
    where o.parent_tenant_id = p_parent_tenant_id
      and t.parent_id = p_parent_tenant_id
      and (p_child_tenant_id is null or o.tenant_id = p_child_tenant_id)
      and oi.shipment_id is null
      and coalesce(oi.ordered_quantity, 0) > 0
      and (
        p_search is null or trim(p_search) = ''
        or oi.name ilike '%' || trim(p_search) || '%'
        or o.name ilike '%' || trim(p_search) || '%'
      )
  )
  union all
  (
    select
      'costing_item'::text as source_type,
      pci.id as source_id,
      pcf.tenant_id as child_tenant_id,
      t.name as child_tenant_name,
      pci.name,
      pci.product_id,
      greatest(coalesce(pci.quantity, 0), 0)::integer as quantity,
      pci.offer_price as cost_bdt,
      pci.price_gbp,
      pci.image_url,
      pci.barcode,
      pci.product_code,
      ('Costing #' || pcf.id::text || ' — ' || coalesce(pcf.name, 'Untitled')) as reference_label
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files pcf on pcf.id = pci.product_based_costing_file_id
    inner join public.tenants t on t.id = pcf.tenant_id
    where t.parent_id = p_parent_tenant_id
      and (p_child_tenant_id is null or pcf.tenant_id = p_child_tenant_id)
      and pci.assigned_shipment_id is null
      and coalesce(pci.quantity, 0) > 0
      and (
        p_search is null or trim(p_search) = ''
        or pci.name ilike '%' || trim(p_search) || '%'
        or pcf.name ilike '%' || trim(p_search) || '%'
      )
  )
  union all
  (
    select
      'shop_order_item'::text as source_type,
      oi.id as source_id,
      o.tenant_id as child_tenant_id,
      t.name as child_tenant_name,
      oi.name,
      oi.product_id,
      greatest(coalesce(oi.ordered_quantity, 0), 0)::integer as quantity,
      case when gc.code = 'BDT' then oi.final_price_amount else null::numeric end as cost_bdt,
      case when gc.code = 'GBP' then oi.final_price_amount else null::numeric end as price_gbp,
      oi.image_url,
      p.barcode,
      p.product_code,
      ('Shop Order #' || o.order_no || ' — ' || o.name) as reference_label
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join public.tenants t on t.id = o.tenant_id
    left join public.products p on p.id = oi.product_id
    left join public.global_currencies gc on gc.id = oi.final_price_currency_id
    where o.status = 'placed'
      and oi.procurement_pulled = false
      and o.shop_type_snapshot = 'vendor_catalog'
      and t.parent_id = p_parent_tenant_id
      and (p_child_tenant_id is null or o.tenant_id = p_child_tenant_id)
      and (
        p_search is null or trim(p_search) = ''
        or oi.name ilike '%' || trim(p_search) || '%'
        or o.name ilike '%' || trim(p_search) || '%'
      )
  )
  order by child_tenant_name, source_type, source_id
  limit greatest(coalesce(p_limit, 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

grant execute on function public.list_child_procurement_lines(bigint, bigint, text, integer, integer) to authenticated;

-- =========================================================
-- 4. Redefine add_child_line_to_parent_shipment to target global_shipment_items and support shop orders
-- =========================================================
drop function if exists public.add_child_line_to_parent_shipment(bigint, text, bigint) cascade;

create or replace function public.add_child_line_to_parent_shipment(
  p_parent_shipment_id bigint,
  p_source_type text,
  p_source_id bigint
)
returns public.global_shipment_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shipment public.global_shipments;
  v_row public.global_shipment_items;
  v_source_type text;
  v_child_tenant_id bigint;
  v_prod record;
  v_vendor_id bigint;
begin
  v_source_type := lower(trim(coalesce(p_source_type, '')));

  if v_source_type not in ('order_item', 'costing_item', 'shop_order_item') then
    raise exception 'invalid source_type: %', p_source_type;
  end if;

  select * into v_shipment
  from public.global_shipments
  where id = p_parent_shipment_id;

  if v_shipment.id is null then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_shipment.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_source_type = 'order_item' then
    -- Legacy Order Pull
    select o.tenant_id into v_child_tenant_id
    from public.order_items oi
    inner join public.orders o on o.id = oi.order_id
    where oi.id = p_source_id
      and o.parent_tenant_id = v_shipment.parent_tenant_id
      and oi.shipment_id is null;

    if v_child_tenant_id is null then
      raise exception 'order item not available for procurement';
    end if;

    select barcode, product_code, product_weight, package_weight into v_prod
    from public.products
    where id = (select product_id from public.order_items where id = p_source_id);

    insert into public.global_shipment_items (
      shipment_id,
      product_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    select
      p_parent_shipment_id,
      oi.product_id,
      oi.name,
      greatest(coalesce(oi.ordered_quantity, 0), 0),
      oi.image_url,
      'order'::public.global_shipment_item_add_method,
      coalesce(oi.price_gbp, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      v_prod.barcode,
      v_prod.product_code,
      v_child_tenant_id,
      'order_item',
      oi.id
    from public.order_items oi
    where oi.id = p_source_id
    returning * into v_row;

    update public.order_items
    set shipment_id = p_parent_shipment_id
    where id = p_source_id;

  elsif v_source_type = 'costing_item' then
    -- Costing Pull
    select pcf.tenant_id into v_child_tenant_id
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files pcf on pcf.id = pci.product_based_costing_file_id
    inner join public.tenants t on t.id = pcf.tenant_id
    where pci.id = p_source_id
      and t.parent_id = v_shipment.parent_tenant_id
      and pci.assigned_shipment_id is null;

    if v_child_tenant_id is null then
      raise exception 'costing item not available for procurement';
    end if;

    select product_weight, package_weight into v_prod
    from public.products
    where id = (select product_id from public.product_based_costing_items where id = p_source_id);

    insert into public.global_shipment_items (
      shipment_id,
      product_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    select
      p_parent_shipment_id,
      pci.product_id,
      pci.name,
      greatest(coalesce(pci.quantity, 0), 0),
      pci.image_url,
      'costing'::public.global_shipment_item_add_method,
      coalesce(pci.price_gbp, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      pci.barcode,
      pci.product_code,
      v_child_tenant_id,
      'costing_item',
      pci.id
    from public.product_based_costing_items pci
    where pci.id = p_source_id
    returning * into v_row;

    update public.product_based_costing_items
    set assigned_shipment_id = p_parent_shipment_id
    where id = p_source_id;

  elsif v_source_type = 'shop_order_item' then
    -- Shop Order Pull
    select o.tenant_id into v_child_tenant_id
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join public.tenants t on t.id = o.tenant_id
    where oi.id = p_source_id
      and t.parent_id = v_shipment.parent_tenant_id
      and oi.procurement_pulled = false
      and o.status = 'placed';

    if v_child_tenant_id is null then
      raise exception 'shop order item not available for procurement';
    end if;

    select barcode, product_code, product_weight, package_weight into v_prod
    from public.products
    where id = (select product_id from public.shop_order_items where id = p_source_id);

    -- Try to match vendor by vendor_code of the shop
    select v.id into v_vendor_id
    from public.shop_order_items oi
    join public.shop_orders o on o.id = oi.order_id
    join public.shops s on s.id = o.shop_id
    join public.vendors v on v.code = s.vendor_code and v.tenant_id = o.tenant_id
    where oi.id = p_source_id
    limit 1;

    insert into public.global_shipment_items (
      shipment_id,
      product_id,
      vendor_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    select
      p_parent_shipment_id,
      oi.product_id,
      v_vendor_id,
      oi.name,
      greatest(coalesce(oi.quantity, 0), 0),
      oi.image_url,
      'order'::public.global_shipment_item_add_method,
      coalesce(oi.final_price_amount, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      v_prod.barcode,
      v_prod.product_code,
      v_child_tenant_id,
      'shop_order_item',
      oi.id
    from public.shop_order_items oi
    where oi.id = p_source_id
    returning * into v_row;

    update public.shop_order_items
    set procurement_pulled = true
    where id = p_source_id;

  end if;

  return v_row;
end;
$$;

grant execute on function public.add_child_line_to_parent_shipment(bigint, text, bigint) to authenticated;

-- =========================================================
-- 5. RPC: fulfill_shop_order_to_invoice
-- =========================================================
create or replace function public.fulfill_shop_order_to_invoice(p_order_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice public.global_invoices;
  v_invoice_type public.global_invoice_type;
  v_retail_billing_mode public.retail_billing_mode;
  v_invoice_no text;
  v_item record;
  v_invoice_row record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  
  if v_order.id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'confirmed' then
    raise exception 'only confirmed orders can be fulfilled to an invoice';
  end if;

  if v_order.shop_type_snapshot = 'vendor_catalog' then
    raise exception 'vendor catalog orders cannot be fulfilled to an invoice directly';
  end if;

  -- 1. Determine invoice type & retail billing mode
  if v_order.shop_type_snapshot = 'dropship' then
    v_invoice_type := 'dropship'::public.global_invoice_type;
    v_retail_billing_mode := null;
  else
    -- fixed_price
    if v_order.order_mode_snapshot = 'checkout_wholesale' then
      v_invoice_type := 'wholesale'::public.global_invoice_type;
      v_retail_billing_mode := null;
    else
      v_invoice_type := 'retail'::public.global_invoice_type;
      if v_order.billing_profile_id is not null then
        v_retail_billing_mode := 'account'::public.retail_billing_mode;
      else
        v_retail_billing_mode := 'direct'::public.retail_billing_mode;
      end if;
    end if;
  end if;

  -- Generate invoice number
  v_invoice_no := 'INV-SO-' || v_order.order_no;

  -- 2. Create the global invoice
  select * into v_invoice from public.create_global_invoice(
    p_tenant_id => v_order.tenant_id,
    p_invoice_no => v_invoice_no,
    p_invoice_type => v_invoice_type,
    p_billing_profile_id => v_order.billing_profile_id,
    p_recipient_profile_id => null,
    p_recipient_name => v_order.recipient_name,
    p_recipient_phone => v_order.recipient_phone,
    p_recipient_address => v_order.shipping_address,
    p_retail_billing_mode => v_retail_billing_mode,
    p_due_date => null,
    p_note => 'Fulfillment of Shop Order: ' || v_order.order_no
  );

  -- 3. Add lines to invoice
  for v_item in select * from public.shop_order_items where order_id = p_order_id loop
    if v_item.global_stock_id is null then
      raise exception 'item % is missing global_stock_id association', v_item.name;
    end if;

    perform public.add_global_invoice_item(
      p_invoice_id => v_invoice.id,
      p_global_stock_id => v_item.global_stock_id,
      p_quantity => v_item.quantity::numeric,
      p_sell_price_amount => coalesce(v_item.final_price_amount, v_item.unit_sell_price_amount, v_item.unit_list_price_amount),
      p_recipient_price_amount => coalesce(v_item.customer_sell_price_amount, v_item.final_price_amount, v_item.unit_sell_price_amount, v_item.unit_list_price_amount),
      p_line_discount_amount => 0.00
    );

    -- Update delivered quantities on order item
    update public.shop_order_items
    set delivered_quantity = quantity,
        updated_at = now()
    where id = v_item.id;
  end loop;

  -- 4. Post the invoice to book ledger entries and deduct quantities
  perform public.post_global_invoice(v_invoice.id);

  -- 5. Complete the shop order
  update public.shop_orders
  set status = 'fulfilled',
      global_invoice_id = v_invoice.id,
      fulfilled_at = now(),
      updated_at = now()
  where id = p_order_id;
end;
$$;

grant execute on function public.fulfill_shop_order_to_invoice(bigint) to authenticated;

commit;

-- Migration: Transition Commerce storefront and pricing to batch-by-batch
begin;

-- 1. Alter store_product_prices to use inventory_item_id instead of product_id
alter table public.store_product_prices
  add column if not exists inventory_item_id bigint references public.inventory_items(id) on delete cascade,
  add column if not exists stock_override integer null;

-- Backfill inventory_item_id from the first active inventory_item per product
update public.store_product_prices spp
set inventory_item_id = (
  select id
  from public.inventory_items ii
  where ii.product_id = spp.product_id
    and ii.tenant_id = spp.tenant_id
    and ii.status = 'active'
  order by ii.id asc
  limit 1
)
where spp.inventory_item_id is null;

-- Remove rows that cannot be mapped to any active inventory batch
delete from public.store_product_prices where inventory_item_id is null;

-- Drop constraints and make product_id optional
alter table public.store_product_prices alter column product_id drop not null;
alter table public.store_product_prices drop constraint if exists store_product_prices_unique_store_product;

-- Create unique constraint for (tenant_id, store_id, inventory_item_id)
alter table public.store_product_prices
  add constraint store_product_prices_unique_store_inventory_item unique (tenant_id, store_id, inventory_item_id);

create index if not exists store_product_prices_inventory_item_idx
  on public.store_product_prices(inventory_item_id);


-- 2. Alter commerce_cart to use inventory_item_id
alter table public.commerce_cart
  add column if not exists inventory_item_id bigint references public.inventory_items(id) on delete cascade;

-- Backfill inventory_item_id from the first active inventory_item per product
update public.commerce_cart cc
set inventory_item_id = (
  select id
  from public.inventory_items ii
  where ii.product_id = cc.product_id
    and ii.tenant_id = cc.tenant_id
    and ii.status = 'active'
  order by ii.id asc
  limit 1
)
where cc.inventory_item_id is null;

-- Remove rows that cannot be mapped to any active inventory batch
delete from public.commerce_cart where inventory_item_id is null;

-- Drop constraints and make product_id optional
alter table public.commerce_cart alter column product_id drop not null;
alter table public.commerce_cart drop constraint if exists commerce_cart_customer_product_unique;

-- Create unique constraint for (tenant_id, customer_group_id, inventory_item_id)
alter table public.commerce_cart
  add constraint commerce_cart_customer_inventory_item_unique unique (tenant_id, customer_group_id, inventory_item_id);

create index if not exists commerce_cart_inventory_item_idx
  on public.commerce_cart(inventory_item_id);


-- Drop existing functions to allow signature / parameter name changes
drop function if exists public.add_item_to_commerce_cart(bigint, bigint, bigint, integer);
drop function if exists public.list_store_products_inventory_aggregated(bigint, text[], text, text, text, boolean, text, text, integer, integer);
drop function if exists public.list_store_product_pricing(bigint, bigint, integer, integer, text, bigint);
drop function if exists public.place_commerce_order(bigint, bigint, text, text, text, numeric, numeric, numeric, numeric, numeric, boolean, jsonb);


-- 3. Redefine add_item_to_commerce_cart RPC
create or replace function public.add_item_to_commerce_cart(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_inventory_item_id bigint,
  p_quantity integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing public.commerce_cart;
  v_row      public.commerce_cart;
  v_product_id bigint;
begin
  -- Resolve the parent product ID
  select product_id into v_product_id
  from public.inventory_items
  where id = p_inventory_item_id;

  -- Check if an entry already exists
  select *
  into v_existing
  from public.commerce_cart
  where tenant_id         = p_tenant_id
    and customer_group_id = p_customer_group_id
    and inventory_item_id = p_inventory_item_id
  limit 1;

  if v_existing.id is not null then
    -- Row exists: update quantity by adding the new amount
    update public.commerce_cart
    set quantity   = v_existing.quantity + greatest(p_quantity, 1),
        updated_at = now()
    where id = v_existing.id
    returning * into v_row;
  else
    -- Row does not exist: insert fresh
    insert into public.commerce_cart (
      tenant_id,
      customer_group_id,
      inventory_item_id,
      product_id,
      quantity
    )
    values (
      p_tenant_id,
      p_customer_group_id,
      p_inventory_item_id,
      v_product_id,
      greatest(p_quantity, 1)
    )
    returning * into v_row;
  end if;

  return to_jsonb(v_row);
end;
$$;

grant execute on function public.add_item_to_commerce_cart(bigint, bigint, bigint, integer) to authenticated;


-- 4. Redefine list_store_products_inventory_aggregated RPC to list batch-by-batch
create or replace function public.list_store_products_inventory_aggregated(
  p_store_id bigint,
  p_fields text[] default null,
  p_search text default null,
  p_category text default null,
  p_brand text default null,
  p_is_available boolean default null,
  p_sort_by text default 'id',
  p_sort_dir text default 'asc',
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_vendor_code text;
  v_sort_by text;
  v_sort_dir text;
  v_limit integer;
  v_offset integer;
  v_has_internal_access boolean;
  v_has_customer_access boolean;
  v_can_see_price boolean;
  v_allowed_fields text[] := array[
    'id',
    'tenant_id',
    'product_code',
    'barcode',
    'name',
    'price_gbp',
    'price_bdt',
    'minimum_sell_price_bdt',
    'country_of_origin',
    'brand',
    'category',
    'available_units',
    'stock_override',
    'tariff_code',
    'languages',
    'batch_code_manufacture_date',
    'image_url',
    'expire_date',
    'minimum_order_quantity',
    'product_weight',
    'package_weight',
    'is_available',
    'created_at',
    'updated_at',
    'vendor_code',
    'market_code'
  ];
  v_selected_fields text[];
  v_result jsonb;
begin
  select s.tenant_id, s.vendor_code
  into v_tenant_id, v_vendor_code
  from public.stores s
  where s.id = p_store_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  end if;

  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.tenant_id = v_tenant_id
      and m.role in ('admin', 'staff')
  ) into v_has_internal_access;

  v_has_customer_access := public.can_customer_access_store(p_store_id);

  if not v_has_internal_access and not v_has_customer_access then
    raise exception 'not allowed';
  end if;

  v_can_see_price := v_has_internal_access or public.can_customer_see_store_price(p_store_id);

  v_sort_by := lower(trim(coalesce(p_sort_by, 'id')));
  if not (v_sort_by = any (array[
    'id',
    'name',
    'product_code',
    'barcode',
    'brand',
    'category',
    'price_bdt',
    'available_units',
    'created_at',
    'updated_at'
  ])) then
    v_sort_by := 'id';
  end if;

  v_sort_dir := lower(trim(coalesce(p_sort_dir, 'asc')));
  if v_sort_dir not in ('asc', 'desc') then
    v_sort_dir := 'asc';
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  select coalesce(array_agg(distinct field_name), '{}'::text[])
  into v_selected_fields
  from unnest(coalesce(p_fields, v_allowed_fields)) as field_name
  where field_name = any (v_allowed_fields);

  if coalesce(array_length(v_selected_fields, 1), 0) = 0 then
    v_selected_fields := array['id', 'name', 'vendor_code', 'brand', 'category', 'available_units', 'stock_override'];
  end if;

  if not v_can_see_price then
    select coalesce(array_agg(field_name), '{}'::text[])
    into v_selected_fields
    from unnest(v_selected_fields) as field_name
    where field_name not in ('price_gbp', 'price_bdt', 'minimum_sell_price_bdt');
  end if;

  execute format(
    $sql$
      with base as (
        select
          ii.id,
          ii.tenant_id,
          ii.product_code,
          ii.barcode,
          ii.name,
          spp.price_bdt,
          spp.minimum_sell_price_bdt,
          spp.price_bdt as price_gbp,
          p.country_of_origin,
          p.brand,
          p.category,
          coalesce(spp.stock_override, greatest(0, ist.available_quantity - ist.reserved_quantity - ist.damaged_quantity - ist.stolen_quantity - ist.expired_quantity - ist.open_box_quantity), 0) as available_units,
          spp.stock_override,
          p.tariff_code,
          p.languages,
          ii.manufacturing_date as batch_code_manufacture_date,
          ii.image_url,
          ii.expire_date,
          p.minimum_order_quantity,
          p.product_weight,
          p.package_weight,
          case when ii.status = 'active' then true else false end as is_available,
          ii.created_at,
          ii.updated_at,
          p.vendor_code,
          p.market_code
        from public.inventory_items ii
        join public.products p
          on p.id = ii.product_id
        left join public.inventory_stocks ist
          on ist.inventory_item_id = ii.id
        left join public.store_product_prices spp
          on spp.store_id = $14
         and spp.tenant_id = ii.tenant_id
         and spp.inventory_item_id = ii.id
        where ii.tenant_id = $1
          and p.vendor_code = $2
          and ii.status = 'active'
      ),
      filtered as (
        select b.*
        from base b
        where (
            $3 is null
            or trim($3) = ''
            or b.name ilike ('%%' || trim($3) || '%%')
            or b.product_code ilike ('%%' || trim($3) || '%%')
            or b.barcode ilike ('%%' || trim($3) || '%%')
          )
          and (
            $4 is null
            or trim($4) = ''
            or lower(coalesce(b.category, '')) = lower(trim($4))
          )
          and (
            $5 is null
            or trim($5) = ''
            or lower(coalesce(b.brand, '')) = lower(trim($5))
          )
          and (
            $6 is null
            or b.available_units > 0
          )
      ),
      paged as (
        select f.*
        from filtered f
        order by %I %s nulls last, f.id asc
        limit $8
        offset $9
      )
      select jsonb_build_object(
        'data',
        coalesce(
          (
            select jsonb_agg(
              (
                select jsonb_object_agg(field_name, to_jsonb(p) -> field_name)
                from unnest($7::text[]) as field_name
              )
            )
            from paged p
          ),
          '[]'::jsonb
        ),
        'meta',
        jsonb_build_object(
          'store_id', $10,
          'limit', $8,
          'offset', $9,
          'current_page', (($9 / $8) + 1),
          'sort_by', $11,
          'sort_dir', $12,
          'total', (select count(*) from filtered),
          'can_see_price', $13
        )
      )
    $sql$,
    v_sort_by,
    v_sort_dir
  )
  into v_result
  using
    v_tenant_id,
    v_vendor_code,
    p_search,
    p_category,
    p_brand,
    p_is_available,
    v_selected_fields,
    v_limit,
    v_offset,
    p_store_id,
    v_sort_by,
    v_sort_dir,
    v_can_see_price,
    p_store_id;

  return coalesce(
    v_result,
    jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'store_id', p_store_id,
        'limit', v_limit,
        'offset', v_offset,
        'current_page', ((v_offset / v_limit) + 1),
        'sort_by', v_sort_by,
        'sort_dir', v_sort_dir,
        'total', 0,
        'can_see_price', v_can_see_price
      )
    )
  );
end;
$$;


-- 5. Redefine list_store_product_pricing RPC to list batch-by-batch
create or replace function public.list_store_product_pricing(
  p_tenant_id bigint,
  p_store_id bigint,
  p_page integer default 1,
  p_page_size integer default 10,
  p_search text default null,
  p_shipment_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  with target_batches as (
    -- Filter active inventory items
    select ii.id as inventory_item_id, ii.product_id
    from public.inventory_items ii
    left join public.shipment_items si
      on ii.source_type = 'shipment'
     and ii.source_id = si.id
    where ii.tenant_id = p_tenant_id
      and ii.status = 'active'
      and (p_shipment_id is null or (ii.source_type = 'shipment' and si.shipment_id = p_shipment_id))
  ),
  batches_with_details as (
    -- Search in batches or parent product details
    select
      tb.inventory_item_id,
      ii.product_id,
      ii.name,
      ii.image_url,
      ii.barcode,
      ii.product_code,
      ii.expire_date,
      ii.cost
    from target_batches tb
    join public.inventory_items ii on ii.id = tb.inventory_item_id
    left join public.products p on p.id = tb.product_id
    where (
      p_search is null
      or trim(p_search) = ''
      or ii.name ilike ('%' || trim(p_search) || '%')
      or ii.product_code ilike ('%' || trim(p_search) || '%')
      or ii.barcode ilike ('%' || trim(p_search) || '%')
      or p.name ilike ('%' || trim(p_search) || '%')
      or p.product_code ilike ('%' || trim(p_search) || '%')
      or p.barcode ilike ('%' || trim(p_search) || '%')
    )
  ),
  counted as (
    select *, count(*) over() as total_count
    from batches_with_details
  ),
  paged_batches as (
    select *
    from counted
    order by name asc, inventory_item_id asc
    limit p_page_size
    offset (p_page - 1) * p_page_size
  ),
  batch_items as (
    -- Construct cost, stock, and shipment info for each batch
    select
      pb.inventory_item_id,
      jsonb_build_object(
        'id', pb.inventory_item_id,
        'cost', pb.cost,
        'quantities', jsonb_build_object(
          'available', coalesce(ist.available_quantity, 0),
          'reserved', coalesce(ist.reserved_quantity, 0),
          'damaged', coalesce(ist.damaged_quantity, 0),
          'stolen', coalesce(ist.stolen_quantity, 0),
          'expired', coalesce(ist.expired_quantity, 0),
          'open_box', coalesce(ist.open_box_quantity, 0)
        ),
        'shipment', case
          when sh.id is null then null
          else jsonb_build_object(
            'shipment', jsonb_build_object(
              'id', sh.id,
              'name', sh.name
            )
          )
        end
      ) as item_json
    from paged_batches pb
    left join public.inventory_stocks ist
      on ist.inventory_item_id = pb.inventory_item_id
    left join public.inventory_items ii
      on ii.id = pb.inventory_item_id
    left join public.shipment_items si
      on ii.source_type = 'shipment'
     and ii.source_id = si.id
    left join public.shipments sh
      on sh.id = si.shipment_id
  ),
  final_data as (
    -- Return one row per batch, mapping batch ID to product_id for frontend table compatibility
    select
      pb.inventory_item_id as product_id,
      pb.name,
      pb.image_url,
      pb.barcode,
      pb.product_code,
      spp.stock_override,
      spp.price_bdt,
      spp.minimum_sell_price_bdt,
      jsonb_build_array(bi.item_json) as items
    from paged_batches pb
    join batch_items bi on bi.inventory_item_id = pb.inventory_item_id
    left join public.store_product_prices spp
      on spp.store_id = p_store_id
     and spp.tenant_id = p_tenant_id
     and spp.inventory_item_id = pb.inventory_item_id
     and spp.is_active = true
  )
  select jsonb_build_object(
    'data', coalesce((select jsonb_agg(to_jsonb(fd)) from final_data fd), '[]'::jsonb),
    'meta', jsonb_build_object(
      'total', coalesce((select max(total_count) from counted), 0),
      'page', p_page,
      'page_size', p_page_size,
      'total_pages', case
        when coalesce((select max(total_count) from counted), 0) = 0 then 1
        else ceil(coalesce((select max(total_count) from counted), 0)::numeric / p_page_size)::int
      end
    )
  )
  into v_result;

  return v_result;
end;
$$;


-- 6. Redefine place_commerce_order RPC to map inventory_item_id
create or replace function public.place_commerce_order(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_shipment_payment numeric,
  p_invoice_print_charge numeric,
  p_wrapping_charge numeric,
  p_cod numeric,
  p_delivery_charge numeric,
  p_is_delivery_charge_inclusive boolean,
  p_items jsonb
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id bigint;
  v_item jsonb;
  v_product_id bigint;
  v_batch_id bigint;
begin
  -- 1. Insert Commerce Order
  insert into public.commerce_orders (
    recipient_name,
    recipient_phone,
    shipping_address,
    shipment_payment,
    invoice_print_charge,
    wrapping_charge,
    cod,
    tenant_id,
    customer_group_id,
    order_placement_date,
    delivery_charge,
    is_delivery_charge_inclusive,
    status
  )
  values (
    p_recipient_name,
    p_recipient_phone,
    p_shipping_address,
    p_shipment_payment,
    p_invoice_print_charge,
    p_wrapping_charge,
    p_cod,
    p_tenant_id,
    p_customer_group_id,
    now(),
    p_delivery_charge,
    p_is_delivery_charge_inclusive,
    'placed'::public.commerce_order_status
  )
  returning id into v_order_id;

  -- 2. Insert Order Items
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_batch_id := (v_item->>'product_id')::bigint; -- product_id in payload represents the inventory_item_id

    -- Resolve the actual parent product ID from the inventory batch
    select product_id into v_product_id
    from public.inventory_items
    where id = v_batch_id;

    insert into public.commerce_order_items (
      order_id,
      product_id,
      image_url,
      cost_bdt,
      sell_price_bdt,
      recipient_price_bdt,
      quantity,
      phone_invite_id,
      inventory_item_id
    )
    values (
      v_order_id,
      v_product_id,
      v_item->>'image_url',
      (v_item->>'cost_bdt')::numeric,
      (v_item->>'sell_price_bdt')::numeric,
      (v_item->>'recipient_price_bdt')::numeric,
      (v_item->>'quantity')::integer,
      v_item->>'phone_invite_id',
      v_batch_id
    );

    -- 3. Delete from commerce_cart
    delete from public.commerce_cart
    where tenant_id = p_tenant_id
      and customer_group_id = p_customer_group_id
      and inventory_item_id = v_batch_id;
  end loop;

  return v_order_id;
end;
$$;

grant execute on function public.place_commerce_order(bigint, bigint, text, text, text, numeric, numeric, numeric, numeric, numeric, boolean, jsonb) to authenticated;

commit;

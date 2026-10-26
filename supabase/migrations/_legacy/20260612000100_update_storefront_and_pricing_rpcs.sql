-- Migration: Update storefront and pricing RPCs for commerce shop
begin;

-- 1. Redefine list_store_products_inventory_aggregated
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
          p.id,
          p.tenant_id,
          p.product_code,
          p.barcode,
          p.name,
          spp.price_bdt,
          spp.minimum_sell_price_bdt,
          spp.price_bdt as price_gbp,
          p.country_of_origin,
          p.brand,
          p.category,
          coalesce(p.stock_override, cis.usable_quantity, 0) as available_units,
          p.stock_override,
          p.tariff_code,
          p.languages,
          p.batch_code_manufacture_date,
          p.image_url,
          p.expire_date,
          p.minimum_order_quantity,
          p.product_weight,
          p.package_weight,
          p.is_available as is_available,
          p.created_at,
          p.updated_at,
          p.vendor_code,
          p.market_code
        from public.products p
        left join public.commerce_inventory_product_summaries cis
          on cis.product_id = p.id
         and cis.tenant_id = p.tenant_id
        left join public.store_product_prices spp
          on spp.store_id = $14
         and spp.tenant_id = p.tenant_id
         and spp.product_id = p.id
         and spp.is_active = true
        where p.tenant_id = $1
          and p.vendor_code = $2
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
            or b.is_available is not distinct from $6
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

-- 2. Redefine list_store_product_pricing
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
  with product_ids_in_shipment as (
    -- Get product IDs in that shipment
    select distinct ii.product_id
    from public.inventory_items ii
    join public.shipment_items si
      on ii.source_type = 'shipment'
     and ii.source_id = si.id
    where ii.tenant_id = p_tenant_id
      and ii.product_id is not null
      and ii.status = 'active'
      and si.shipment_id = p_shipment_id
  ),
  base_products as (
    -- Get all unique products for this tenant
    select id as product_id
    from public.products p
    where p.tenant_id = p_tenant_id
  ),
  target_products as (
    -- Apply shipment filter if active, otherwise use all base products
    select bp.product_id
    from base_products bp
    where (p_shipment_id is null or bp.product_id in (select product_id from product_ids_in_shipment))
  ),
  products_with_details as (
    -- Get product details and match search filter
    select
      p.id as product_id,
      p.name,
      p.image_url,
      p.barcode,
      p.product_code,
      p.stock_override
    from public.products p
    join target_products tp
      on p.id = tp.product_id
    where p.tenant_id = p_tenant_id
      and (
        p_search is null
        or trim(p_search) = ''
        or p.name ilike ('%' || trim(p_search) || '%')
        or p.product_code ilike ('%' || trim(p_search) || '%')
        or p.barcode ilike ('%' || trim(p_search) || '%')
      )
  ),
  counted as (
    select *, count(*) over() as total_count
    from products_with_details
  ),
  paged_products as (
    select *
    from counted
    order by name asc, product_id asc
    limit p_page_size
    offset (p_page - 1) * p_page_size
  ),
  product_items as (
    -- Fetch shipments and costs only for products on the current page
    select
      ii.product_id,
      ii.id, -- include id for sorting inside aggregate
      jsonb_build_object(
        'id', ii.id,
        'cost', ii.cost,
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
    from public.inventory_items ii
    left join public.inventory_stocks ist
      on ist.inventory_item_id = ii.id
    left join public.shipment_items si
      on ii.source_type = 'shipment'
     and ii.source_id = si.id
    left join public.shipments sh
      on sh.id = si.shipment_id
    where ii.tenant_id = p_tenant_id
      and ii.status = 'active'
      and ii.product_id in (select product_id from paged_products)
  ),
  grouped_items as (
    select
      product_id,
      coalesce(jsonb_agg(item_json order by id desc), '[]'::jsonb) as items_list
    from product_items
    group by product_id
  ),
  final_data as (
    select
      pp.product_id,
      pp.name,
      pp.image_url,
      pp.barcode,
      pp.product_code,
      pp.stock_override,
      spp.price_bdt,
      spp.minimum_sell_price_bdt,
      coalesce(gi.items_list, '[]'::jsonb) as items
    from paged_products pp
    left join grouped_items gi
      on pp.product_id = gi.product_id
    left join public.store_product_prices spp
      on spp.store_id = p_store_id
     and spp.tenant_id = p_tenant_id
     and spp.product_id = pp.product_id
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

commit;

-- Phase 3: product catalog reads use parent_tenant_id (+ vendor filters).
-- Caller tenant is still the shop/store/shipment tenant; RPCs resolve parent.

CREATE OR REPLACE FUNCTION "public"."browse_shop_catalog_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_search" "text" DEFAULT NULL::"text", "p_category" "text" DEFAULT NULL::"text", "p_brand" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_shop_id bigint;
  v_tenant_id bigint;
  v_shop_name text;
  v_shop_type public.shop_type_enum;
  v_vendor_code text;
  v_order_mode public.shop_order_mode_enum;
  v_is_negotiable boolean;
  v_show_stock_quantity boolean;
  v_default_currency_id bigint;
  v_is_active boolean;
  v_buy_currency_id bigint;
  v_sell_currency_id bigint;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_quantity_display_mode text;
  v_vendor_filters jsonb;
  v_can_browse boolean;
  v_see_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;
  v_limit integer;
  v_offset integer;
  v_result jsonb;
  v_parent_tenant_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;

  if public.current_customer_group_id(p_tenant_id) is null then
    raise exception 'access denied';
  end if;

  select
    id, tenant_id, name, shop_type, vendor_code, order_mode,
    is_negotiable, show_stock_quantity, default_currency_id, is_active,
    buy_currency_id, sell_currency_id, pricing_method, markup_percentage, quantity_display_mode,
    vendor_filters
  into
    v_shop_id, v_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode,
    v_vendor_filters
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select
    can_browse, see_price, can_add_to_cart, can_place_order,
    can_negotiate, can_view_quantity, can_set_dropship_price
  into
    v_can_browse, v_see_price, v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_tenant_id);
  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  if v_shop_type = 'vendor_catalog' then
    execute format(
      $sql$
        with filtered as (
          select p.*
          from public.products p
          where p.is_available = true
            and p.parent_tenant_id = $2
            and (
              (($9 is null or jsonb_array_length($9) = 0) and p.vendor_code = $1)
              or
              ($9 is not null and jsonb_array_length($9) > 0 and exists (
                select 1
                from jsonb_to_recordset($9) as vf(vendor_code text, brands text[])
                where vf.vendor_code = p.vendor_code
                  and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
              ))
            )
            and ($3 is null or trim($3) = '' or p.name ilike ('%%' || trim($3) || '%%') or p.product_code ilike ('%%' || trim($3) || '%%') or p.barcode ilike ('%%' || trim($3) || '%%'))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.category, '')) = lower(trim($4)))
            and ($5 is null or trim($5) = '' or lower(coalesce(p.brand, '')) = lower(trim($5)))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.name asc, f.id asc
          limit $6
          offset $7
        )
        select jsonb_build_object(
          'data',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'product_id', p.id,
                  'product_name', p.name,
                  'product_image_url', p.image_url,
                  'product_barcode', p.barcode,
                  'product_code', p.product_code,
                  'product_brand', p.brand,
                  'product_category', p.category,
                  'vendor_code', p.vendor_code,
                  'is_available', p.is_available,
                  'unit_price_amount', case when $8 then p.list_price_amount else null end,
                  'unit_price_currency_id', case when $8 then p.list_price_currency_id else null end,
                  'unit_price_currency_code', case when $8 then (select code from public.global_currencies where id = p.list_price_currency_id) else null end,
                  'unit_price_currency_symbol', case when $8 then (select symbol from public.global_currencies where id = p.list_price_currency_id) else null end,
                  'minimum_sell_price_amount', null,
                  'minimum_sell_price_currency_id', null,
                  'minimum_sell_price_currency_code', null,
                  'minimum_sell_price_currency_symbol', null,
                  'available_units', null,
                  'global_stock_allocation_id', null,
                  'global_stock_id', null,
                  'minimum_order_quantity', p.minimum_order_quantity
                )
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta',
          jsonb_build_object(
            'total', (select count(*) from filtered),
            'page', (($7 / $6) + 1),
            'page_size', $6,
            'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / $6::numeric))
          )
        )
      $sql$
    )
    into v_result
    using
      v_vendor_code,
      v_parent_tenant_id,
      p_search,
      p_category,
      p_brand,
      v_limit,
      v_offset,
      v_see_price,
      v_vendor_filters;
  else
    execute format(
      $sql$
        with filtered as (
          select
            l.id as listing_id,
            l.global_stock_id,
            case
              when $8 = 'fixed_price' and $11 = 'markup' then
                coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + $12 / 100.0)
              when $8 = 'fixed_price' and $11 = 'direct_cost' then
                coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
              else
                l.sell_price_amount
            end as computed_sell_price,
            l.sell_price_currency_id,
            l.minimum_sell_price_amount,
            l.minimum_sell_price_currency_id,
            l.show_quantity as listing_show_quantity,
            l.display_quantity_override,
            p.id as product_id,
            p.name as product_name,
            p.image_url as product_image_url,
            p.barcode as product_barcode,
            p.product_code as product_code,
            p.brand as product_brand,
            p.category as product_category,
            p.vendor_code as product_vendor_code,
            p.is_available as product_is_available,
            p.minimum_order_quantity as product_moq,
            greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer as available_qty
          from public.shop_product_listings l
          join public.products p on p.id = l.product_id
          join public.global_stocks gs on gs.id = l.global_stock_id
          left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
          left join public.global_shipments gship on gship.id = gsi.shipment_id
            and gship.assigned_child_tenant_id = $14
          where l.shop_id = $1
            and l.global_stock_id is not null
            and coalesce(gship.status, 'received') = 'received'
            and l.is_active = true
            and ($2 is null or trim($2) = '' or p.name ilike ('%%' || trim($2) || '%%') or p.product_code ilike ('%%' || trim($2) || '%%') or p.barcode ilike ('%%' || trim($2) || '%%'))
            and ($3 is null or trim($3) = '' or lower(coalesce(p.category, '')) = lower(trim($3)))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.brand, '')) = lower(trim($4)))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.product_name asc, f.listing_id asc
          limit $5
          offset $6
        )
        select jsonb_build_object(
          'data',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'product_id', p.product_id,
                  'product_name', p.product_name,
                  'product_image_url', p.product_image_url,
                  'product_barcode', p.product_barcode,
                  'product_code', p.product_code,
                  'product_brand', p.product_brand,
                  'product_category', p.product_category,
                  'vendor_code', p.product_vendor_code,
                  'is_available', p.product_is_available,
                  'unit_price_amount', case when $7 then p.computed_sell_price else null end,
                  'unit_price_currency_id', case when $7 then p.sell_price_currency_id else null end,
                  'unit_price_currency_code', case when $7 then (select code from public.global_currencies where id = p.sell_price_currency_id) else null end,
                  'unit_price_currency_symbol', case when $7 then (select symbol from public.global_currencies where id = p.sell_price_currency_id) else null end,
                  'minimum_sell_price_amount', case when $7 and $8 = 'dropship' then p.minimum_sell_price_amount else null end,
                  'minimum_sell_price_currency_id', case when $7 and $8 = 'dropship' then p.minimum_sell_price_currency_id else null end,
                  'minimum_sell_price_currency_code', case when $7 and $8 = 'dropship' then (select code from public.global_currencies where id = p.minimum_sell_price_currency_id) else null end,
                  'minimum_sell_price_currency_symbol', case when $7 and $8 = 'dropship' then (select symbol from public.global_currencies where id = p.minimum_sell_price_currency_id) else null end,
                  'available_units', case
                    when not $9 or not coalesce(p.listing_show_quantity, $10) then null
                    when $13 = 'original' then greatest(0, p.available_qty)
                    when p.display_quantity_override is not null then p.display_quantity_override
                    else greatest(0, p.available_qty)
                  end,
                  'global_stock_allocation_id', p.global_stock_id,
                  'global_stock_id', p.global_stock_id,
                  'minimum_order_quantity', p.product_moq
                )
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta',
          jsonb_build_object(
            'total', (select count(*) from filtered),
            'page', (($6 / $5) + 1),
            'page_size', $5,
            'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / $5::numeric))
          )
        )
      $sql$
    )
    into v_result
    using
      v_shop_id,
      p_search,
      p_category,
      p_brand,
      v_limit,
      v_offset,
      v_see_price,
      v_shop_type,
      v_can_view_quantity,
      v_show_stock_quantity,
      v_pricing_method,
      v_markup_percentage,
      v_quantity_display_mode,
      v_tenant_id;
  end if;

  v_result := jsonb_set(v_result, '{meta, shop}', jsonb_build_object(
    'id', v_shop_id,
    'name', v_shop_name,
    'slug', p_shop_slug,
    'shop_type', v_shop_type,
    'vendor_code', v_vendor_code,
    'order_mode', v_order_mode,
    'is_negotiable', v_is_negotiable,
    'show_stock_quantity', v_show_stock_quantity,
    'default_currency_id', v_default_currency_id,
    'is_active', v_is_active,
    'buy_currency_id', v_buy_currency_id,
    'sell_currency_id', v_sell_currency_id,
    'pricing_method', v_pricing_method,
    'markup_percentage', v_markup_percentage,
    'quantity_display_mode', v_quantity_display_mode,
    'vendor_filters', v_vendor_filters
  ));

  return v_result;
end;
$_$;

CREATE OR REPLACE FUNCTION "public"."fetch_customer_shop_categories"("p_tenant_id" bigint) RETURNS TABLE("name" "text", "count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_tenant_id bigint;
begin
  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  return query
  with accessible_shops as (
    select distinct s.id, s.shop_type, s.vendor_code, s.vendor_filters
    from public.shops s
    join public.shop_customer_group_access access on access.shop_id = s.id
    join public.customer_groups cg on cg.id = access.customer_group_id
    join public.customer_group_members cgm on cgm.customer_group_id = cg.id
    left join public.customer_group_shop_profiles profile
      on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
    where s.is_active = true
      and cg.is_active = true
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and s.tenant_id = p_tenant_id
      and access.status = true
      and coalesce(profile.is_active, true) = true
      and coalesce(access.can_browse, profile.default_can_browse, false) = true
  ),
  vendor_products as (
    select distinct p.id, p.category
    from public.products p
    join accessible_shops s on s.shop_type = 'vendor_catalog'
    where p.is_available = true
      and p.parent_tenant_id = v_parent_tenant_id
      and (
        ((s.vendor_filters is null or jsonb_array_length(s.vendor_filters) = 0) and p.vendor_code = s.vendor_code)
        or
        (s.vendor_filters is not null and jsonb_array_length(s.vendor_filters) > 0 and exists (
          select 1 
          from jsonb_to_recordset(s.vendor_filters) as vf(vendor_code text, brands text[])
          where vf.vendor_code = p.vendor_code
            and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
        ))
      )
  ),
  listing_products as (
    select distinct p.id, p.category
    from public.shop_product_listings l
    join accessible_shops s on s.id = l.shop_id and s.shop_type <> 'vendor_catalog'
    join public.products p on p.id = l.product_id
    where l.is_active = true
      and p.is_available = true
  ),
  combined_products as (
    select id, category from vendor_products
    union
    select id, category from listing_products
  )
  select 
    coalesce(nullif(trim(cp.category), ''), 'Uncategorized') as name,
    count(cp.id)::bigint as count
  from combined_products cp
  group by coalesce(nullif(trim(cp.category), ''), 'Uncategorized')
  order by count(cp.id) desc, name asc;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."get_store_product_brands"("p_store_id" bigint) RETURNS TABLE("brand" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_vendor_code text;
  v_parent_tenant_id bigint;
  v_has_internal_access boolean;
  v_has_customer_access boolean;
begin
  select s.tenant_id, s.vendor_code
  into v_tenant_id, v_vendor_code
  from public.stores s
  where s.id = p_store_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_tenant_id);

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

  return query
  select distinct p.brand
  from public.products p
  where p.parent_tenant_id = v_parent_tenant_id
    and p.vendor_code = v_vendor_code
    and p.brand is not null
    and length(trim(p.brand)) > 0
  order by p.brand asc;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."get_store_product_categories"("p_store_id" bigint) RETURNS TABLE("category" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_vendor_code text;
  v_parent_tenant_id bigint;
  v_has_internal_access boolean;
  v_has_customer_access boolean;
begin
  select s.tenant_id, s.vendor_code
  into v_tenant_id, v_vendor_code
  from public.stores s
  where s.id = p_store_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_tenant_id);

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

  return query
  select distinct p.category
  from public.products p
  where p.parent_tenant_id = v_parent_tenant_id
    and p.vendor_code = v_vendor_code
    and p.category is not null
    and length(trim(p.category)) > 0
  order by p.category asc;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."get_cart_details"("p_cart_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_result jsonb;
begin
  if not public.can_access_cart(p_cart_id) then
    raise exception 'not authorized to access this cart';
  end if;

  select jsonb_build_object(
    'cart',
    jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'store_id', c.store_id,
      'customer_group_id', c.customer_group_id,
      'can_see_price', c.can_see_price,
      'created_at', c.created_at,
      'updated_at', c.updated_at
    ),
    'items',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ci.id,
            'cart_id', ci.cart_id,
            'product_id', ci.product_id,
            'name', ci.name,
            'image_url', ci.image_url,
            'price_gbp', ci.price_gbp,
            'quantity', ci.quantity,
            'minimum_quantity', ci.minimum_quantity,
            'created_at', ci.created_at,
            'updated_at', ci.updated_at,
            'product',
            case
              when p.id is null then null
              else jsonb_build_object(
                'id', p.id,
                'parent_tenant_id', p.parent_tenant_id,
                'inserted_by_tenant_id', p.inserted_by_tenant_id,
                'product_code', p.product_code,
                'barcode', p.barcode,
                'name', p.name,
                'price_gbp', p.list_price_amount, -- compatibility mapping
                'list_price_amount', p.list_price_amount,
                'list_price_currency_id', p.list_price_currency_id,
                'reference_cost_amount', p.reference_cost_amount,
                'reference_cost_currency_id', p.reference_cost_currency_id,
                'country_of_origin', p.country_of_origin,
                'brand', p.brand,
                'category', p.category,
                'available_units', p.available_units,
                'languages', p.languages,
                'batch_code_manufacture_date', p.batch_code_manufacture_date,
                'image_url', p.image_url,
                'expire_date', p.expire_date,
                'minimum_order_quantity', p.minimum_order_quantity,
                'product_weight', p.product_weight,
                'package_weight', p.package_weight,
                'is_available', p.is_available,
                'vendor_code', p.vendor_code,
                'market_code', p.market_code,
                'created_at', p.created_at,
                'updated_at', p.updated_at
              )
            end
          )
          order by ci.id
        )
        from public.cart_items ci
        left join public.products p
          on p.id = ci.product_id
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from public.carts c
  where c.id = p_cart_id;

  if v_result is null then
    raise exception 'cart not found';
  end if;

  return v_result;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."list_store_products"("p_store_id" bigint, "p_fields" "text"[] DEFAULT NULL::"text"[], "p_search" "text" DEFAULT NULL::"text", "p_category" "text" DEFAULT NULL::"text", "p_brand" "text" DEFAULT NULL::"text", "p_is_available" boolean DEFAULT NULL::boolean, "p_sort_by" "text" DEFAULT 'id'::"text", "p_sort_dir" "text" DEFAULT 'asc'::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_tenant_id bigint;
  v_parent_tenant_id bigint;
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
    'parent_tenant_id',
    'inserted_by_tenant_id',
    'product_code',
    'barcode',
    'name',
    'price_gbp',
    'country_of_origin',
    'brand',
    'category',
    'available_units',
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

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_tenant_id);

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
    'price_gbp',
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
    v_selected_fields := array['id', 'name', 'vendor_code', 'brand', 'category'];
  end if;

  if not v_can_see_price then
    select coalesce(array_agg(field_name), '{}'::text[])
    into v_selected_fields
    from unnest(v_selected_fields) as field_name
    where field_name <> 'price_gbp';
  end if;

  execute format(
    $sql$
      with filtered as (
        select p.*
        from public.products p
        where p.vendor_code = $1
          and p.parent_tenant_id = $2
          and (
            $3 is null
            or trim($3) = ''
            or p.name ilike ('%%' || trim($3) || '%%')
            or p.product_code ilike ('%%' || trim($3) || '%%')
            or p.barcode ilike ('%%' || trim($3) || '%%')
          )
          and (
            $4 is null
            or trim($4) = ''
            or lower(coalesce(p.category, '')) = lower(trim($4))
          )
          and (
            $5 is null
            or trim($5) = ''
            or lower(coalesce(p.brand, '')) = lower(trim($5))
          )
          and p.is_available is true
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
    v_vendor_code,
    v_parent_tenant_id,
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
    v_can_see_price;

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
$_$;

CREATE OR REPLACE FUNCTION "public"."list_store_products_inventory_aggregated"("p_store_id" bigint, "p_fields" "text"[] DEFAULT NULL::"text"[], "p_search" "text" DEFAULT NULL::"text", "p_category" "text" DEFAULT NULL::"text", "p_brand" "text" DEFAULT NULL::"text", "p_is_available" boolean DEFAULT NULL::boolean, "p_sort_by" "text" DEFAULT 'id'::"text", "p_sort_dir" "text" DEFAULT 'asc'::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_tenant_id bigint;
  v_parent_tenant_id bigint;
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

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_tenant_id);

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
          and p.parent_tenant_id = $15
          and ii.status = 'active'
          and (ist.stolen_quantity is null or ist.stolen_quantity = 0 or ist.stolen_quantity < ist.available_quantity)
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
    p_store_id,
    v_parent_tenant_id;

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
$_$;

CREATE OR REPLACE FUNCTION "public"."add_shipment_item_from_product"("p_shipment_id" bigint, "p_product_id" bigint, "p_quantity" integer) RETURNS "public"."shipment_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.shipment_items;
  v_tenant_id bigint;
  v_parent bigint;
  v_product record;
  v_quantity integer;
begin
  select tenant_id into v_tenant_id
  from public.shipments
  where id = p_shipment_id;

  if v_tenant_id is null then
    raise exception 'shipment not found';
  end if;

  if not public.can_manage_shipment(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_parent := public.resolve_parent_tenant_id(v_tenant_id);

  v_quantity := coalesce(p_quantity, 0);
  if v_quantity <= 0 then
    raise exception 'quantity must be greater than 0';
  end if;

  select
    p.id,
    p.name,
    p.barcode,
    p.product_code,
    p.image_url,
    p.product_weight,
    p.package_weight,
    coalesce(p.list_price_amount, 0) as price_gbp
  into v_product
  from public.products p
  where p.id = p_product_id
    and p.parent_tenant_id = v_parent;

  if v_product.id is null then
    raise exception 'product not found';
  end if;

  insert into public.shipment_items (
    shipment_id,
    name,
    quantity,
    barcode,
    product_code,
    product_id,
    image_url,
    product_weight,
    package_weight,
    price_gbp
  )
  values (
    p_shipment_id,
    v_product.name,
    v_quantity,
    v_product.barcode,
    v_product.product_code,
    v_product.id,
    v_product.image_url,
    v_product.product_weight,
    v_product.package_weight,
    v_product.price_gbp
  )
  returning * into v_row;

  return v_row;
end;
$$;

-- Vendor catalog: enforce shops.min_available_units on browse, detail, search, related, and cart.

create or replace function public.shop_catalog_meets_min_available_units(
  p_min_available_units integer,
  p_product_available_units integer
)
returns boolean
language sql
immutable
as $$
  select coalesce(p_min_available_units, 0) = 0
    or coalesce(p_product_available_units, 0) >= p_min_available_units;
$$;

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
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
  v_can_see_resell_minimum_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;
  v_can_see_catalog_price boolean;
  v_limit integer;
  v_offset integer;
  v_result jsonb;
  v_parent_tenant_id bigint;
  v_min_available_units integer;
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
    vendor_filters, min_available_units
  into
    v_shop_id, v_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode,
    v_vendor_filters, v_min_available_units
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select
    can_browse, can_see_buy_price, can_see_sell_price, can_see_resell_minimum_price,
    can_add_to_cart, can_place_order,
    can_negotiate, can_view_quantity, can_set_dropship_price
  into
    v_can_browse, v_can_see_buy_price, v_can_see_sell_price, v_can_see_resell_minimum_price,
    v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_tenant_id);
  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));
  v_can_see_catalog_price := coalesce(v_can_see_buy_price, false);

  if v_shop_type = 'vendor_catalog' then
    execute format(
      $sql$
        with filtered as (
          select p.*
          from public.products p
          where p.is_available = true
            and coalesce(p.hazardous, false) = false
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
            and ($10 = 0 or coalesce(p.available_units, 0) >= $10)
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
                  'unit_price', case
                    when $8 then jsonb_build_object(
                      'amount', p.list_price_amount,
                      'currency_id', p.list_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.list_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.list_price_currency_id)
                    )
                    else null
                  end,
                  'unit_price_amount', case when $8 then p.list_price_amount else null end,
                  'unit_price_currency_id', case when $8 then p.list_price_currency_id else null end,
                  'unit_price_currency_code', case
                    when $8 then (select code from public.global_currencies where id = p.list_price_currency_id)
                    else null
                  end,
                  'unit_price_currency_symbol', case
                    when $8 then (select symbol from public.global_currencies where id = p.list_price_currency_id)
                    else null
                  end,
                  'sell_price', null,
                  'resell_minimum_price', null,
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
      v_can_see_catalog_price,
      v_vendor_filters,
      coalesce(v_min_available_units, 0);
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
            coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) as computed_unit_cost,
            l.sell_price_amount as listing_sell_price_amount,
            l.sell_price_currency_id as listing_sell_price_currency_id,
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
            public.shop_product_grade_available_units(
              $14,
              p.id,
              coalesce(l.grade_tag_id, gs.grade_tag_id)
            ) as available_qty,
            tg.slug as grade_slug,
            tg.name as grade_label,
            tg.color as grade_color
          from public.shop_product_listings l
          join public.products p on p.id = l.product_id
          left join public.global_stocks gs on gs.id = l.global_stock_id
          left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
          left join public.tags tg on tg.id = coalesce(l.grade_tag_id, gs.grade_tag_id)
          where l.shop_id = $1
            and l.is_active = true
            and p.is_available = true
            and coalesce(p.hazardous, false) = false
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
                  'unit_price', case
                    when $8 = 'dropship' and $15 then jsonb_build_object(
                      'amount', p.computed_unit_cost,
                      'currency_id', $16,
                      'code', (select code from public.global_currencies where id = $16),
                      'symbol', (select symbol from public.global_currencies where id = $16)
                    )
                    else null
                  end,
                  'sell_price', case
                    when $7 and $8 = 'fixed_price' then jsonb_build_object(
                      'amount', p.computed_sell_price,
                      'currency_id', p.sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.sell_price_currency_id)
                    )
                    when $7 and $8 = 'dropship' then jsonb_build_object(
                      'amount', p.listing_sell_price_amount,
                      'currency_id', p.listing_sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.listing_sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.listing_sell_price_currency_id)
                    )
                    else null
                  end,
                  'resell_minimum_price', case
                    when $17 and $8 = 'dropship' then jsonb_build_object(
                      'amount', p.minimum_sell_price_amount,
                      'currency_id', p.minimum_sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.minimum_sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.minimum_sell_price_currency_id)
                    )
                    else null
                  end,
                  'available_units', case
                    when not $9 or not coalesce(p.listing_show_quantity, $10) then null
                    when $13 = 'original' then greatest(0, p.available_qty)
                    when p.display_quantity_override is not null then p.display_quantity_override
                    else greatest(0, p.available_qty)
                  end,
                  'listing_id', p.listing_id,
                  'stock_grade', case
                    when p.grade_slug is not null then jsonb_build_object(
                      'slug', p.grade_slug,
                      'label', p.grade_label,
                      'color', p.grade_color
                    )
                    else null
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
      v_can_see_sell_price,
      v_shop_type,
      v_can_view_quantity,
      v_show_stock_quantity,
      v_pricing_method,
      v_markup_percentage,
      v_quantity_display_mode,
      v_tenant_id,
      v_can_see_buy_price,
      v_buy_currency_id,
      v_can_see_resell_minimum_price;
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
  v_result := jsonb_set(v_result, '{meta, permissions}', jsonb_build_object(
    'can_browse', v_can_browse,
    'can_see_buy_price', v_can_see_buy_price,
    'can_see_sell_price', v_can_see_sell_price,
    'can_see_resell_minimum_price', v_can_see_resell_minimum_price,
    'can_add_to_cart', v_can_add_to_cart,
    'can_place_order', v_can_place_order,
    'can_negotiate', v_can_negotiate,
    'can_view_quantity', v_can_view_quantity,
    'can_set_dropship_price', v_can_set_dropship_price
  ));

  return v_result;
end;
$_$;

CREATE OR REPLACE FUNCTION "public"."get_shop_catalog_product_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_shop_id bigint;
  v_shop_tenant_id bigint;
  v_parent_tenant_id bigint;
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
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
  v_can_see_resell_minimum_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;
  v_can_see_catalog_price boolean;
  v_min_available_units integer;
  v_product jsonb;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;
  if p_product_id is null then
    raise exception 'product required';
  end if;
  if public.current_customer_group_id(p_tenant_id) is null then
    raise exception 'access denied';
  end if;

  select
    id, tenant_id, name, shop_type, vendor_code, order_mode,
    is_negotiable, show_stock_quantity, default_currency_id, is_active,
    buy_currency_id, sell_currency_id, pricing_method, markup_percentage, quantity_display_mode,
    vendor_filters, min_available_units
  into
    v_shop_id, v_shop_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode,
    v_vendor_filters, v_min_available_units
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select
    can_browse, can_see_buy_price, can_see_sell_price, can_see_resell_minimum_price,
    can_add_to_cart, can_place_order,
    can_negotiate, can_view_quantity, can_set_dropship_price
  into
    v_can_browse, v_can_see_buy_price, v_can_see_sell_price, v_can_see_resell_minimum_price,
    v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_shop_tenant_id);
  v_can_see_catalog_price := coalesce(v_can_see_buy_price, false);

  if v_shop_type = 'vendor_catalog' then
    select jsonb_build_object(
      'product_id', p.id,
      'product_name', p.name,
      'product_image_url', p.image_url,
      'product_barcode', p.barcode,
      'product_code', p.product_code,
      'product_brand', p.brand,
      'product_category', p.category,
      'vendor_code', p.vendor_code,
      'is_available', p.is_available,
      'country_of_origin', p.country_of_origin,
      'expire_date', p.expire_date,
      'unit_price_amount', case when v_can_see_catalog_price then p.list_price_amount else null end,
      'unit_price_currency_id', case when v_can_see_catalog_price then p.list_price_currency_id else null end,
      'unit_price_currency_code', case when v_can_see_catalog_price then (select code from public.global_currencies where id = p.list_price_currency_id) else null end,
      'unit_price_currency_symbol', case when v_can_see_catalog_price then (select symbol from public.global_currencies where id = p.list_price_currency_id) else null end,
      'minimum_sell_price_amount', null,
      'minimum_sell_price_currency_id', null,
      'minimum_sell_price_currency_code', null,
      'minimum_sell_price_currency_symbol', null,
      'available_units', null,
      'global_stock_allocation_id', null,
      'global_stock_id', null,
      'minimum_order_quantity', p.minimum_order_quantity
    )
    into v_product
    from public.products p
    where p.id = p_product_id
      and p.is_available = true
      and coalesce(p.hazardous, false) = false
      and p.parent_tenant_id = v_parent_tenant_id
      and (
        ((v_vendor_filters is null or jsonb_array_length(v_vendor_filters) = 0) and p.vendor_code = v_vendor_code)
        or
        (v_vendor_filters is not null and jsonb_array_length(v_vendor_filters) > 0 and exists (
          select 1
          from jsonb_to_recordset(v_vendor_filters) as vf(vendor_code text, brands text[])
          where vf.vendor_code = p.vendor_code
            and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
        ))
      )
      and public.shop_catalog_meets_min_available_units(v_min_available_units, p.available_units)
    limit 1;
  else
    select jsonb_build_object(
      'product_id', row.product_id,
      'product_name', row.product_name,
      'product_image_url', row.product_image_url,
      'product_barcode', row.product_barcode,
      'product_code', row.product_code,
      'product_brand', row.product_brand,
      'product_category', row.product_category,
      'vendor_code', row.product_vendor_code,
      'is_available', row.product_is_available,
      'country_of_origin', row.country_of_origin,
      'expire_date', row.expire_date,
      'unit_price_amount', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then row.computed_sell_price
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then row.computed_sell_price
        else null
      end,
      'unit_price_currency_id', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then row.sell_price_currency_id
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then row.sell_price_currency_id
        else null
      end,
      'unit_price_currency_code', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then (select code from public.global_currencies where id = row.sell_price_currency_id)
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then (select code from public.global_currencies where id = row.sell_price_currency_id)
        else null
      end,
      'unit_price_currency_symbol', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then (select symbol from public.global_currencies where id = row.sell_price_currency_id)
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then (select symbol from public.global_currencies where id = row.sell_price_currency_id)
        else null
      end,
      'minimum_sell_price_amount', case when v_can_see_sell_price and v_shop_type = 'dropship' then row.minimum_sell_price_amount else null end,
      'minimum_sell_price_currency_id', case when v_can_see_sell_price and v_shop_type = 'dropship' then row.minimum_sell_price_currency_id else null end,
      'minimum_sell_price_currency_code', case when v_can_see_sell_price and v_shop_type = 'dropship' then (select code from public.global_currencies where id = row.minimum_sell_price_currency_id) else null end,
      'minimum_sell_price_currency_symbol', case when v_can_see_sell_price and v_shop_type = 'dropship' then (select symbol from public.global_currencies where id = row.minimum_sell_price_currency_id) else null end,
      'available_units', case
        when not v_can_view_quantity or not coalesce(row.listing_show_quantity, v_show_stock_quantity) then null
        when v_quantity_display_mode = 'original' then greatest(0, row.available_qty)
        when row.display_quantity_override is not null then row.display_quantity_override
        else greatest(0, row.available_qty)
      end,
      'listing_id', row.listing_id,
      'stock_grade', case
        when row.grade_slug is not null then jsonb_build_object(
          'slug', row.grade_slug,
          'label', row.grade_label,
          'color', row.grade_color
        )
        else null
      end,
      'global_stock_allocation_id', row.global_stock_id,
      'global_stock_id', row.global_stock_id,
      'minimum_order_quantity', row.product_moq
    )
    into v_product
    from (
      select
        l.id as listing_id,
        l.global_stock_id,
        case
          when v_shop_type = 'fixed_price' and v_pricing_method = 'markup' then
            coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + v_markup_percentage / 100.0)
          when v_shop_type = 'fixed_price' and v_pricing_method = 'direct_cost' then
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
        p.country_of_origin,
        p.expire_date,
        p.minimum_order_quantity as product_moq,
        public.shop_product_grade_available_units(
          v_shop_tenant_id,
          p.id,
          coalesce(l.grade_tag_id, gs.grade_tag_id)
        ) as available_qty,
        tg.slug as grade_slug,
        tg.name as grade_label,
        tg.color as grade_color
      from public.shop_product_listings l
      join public.products p on p.id = l.product_id
      left join public.global_stocks gs on gs.id = l.global_stock_id
      left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      left join public.tags tg on tg.id = coalesce(l.grade_tag_id, gs.grade_tag_id)
      where l.shop_id = v_shop_id
        and l.product_id = p_product_id
        and l.is_active = true
        and p.is_available = true
        and coalesce(p.hazardous, false) = false
      order by l.id asc
      limit 1
    ) row;
  end if;

  if v_product is null then
    raise exception 'product not found';
  end if;

  return jsonb_build_object(
    'data', v_product,
    'meta', jsonb_build_object(
      'shop', jsonb_build_object(
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
      ),
      'permissions', jsonb_build_object(
        'can_browse', v_can_browse,
        'can_see_buy_price', v_can_see_buy_price,
    'can_see_sell_price', v_can_see_sell_price,
        'can_add_to_cart', v_can_add_to_cart,
        'can_place_order', v_can_place_order,
        'can_negotiate', v_can_negotiate,
        'can_view_quantity', v_can_view_quantity,
        'can_set_dropship_price', v_can_set_dropship_price
      )
    )
  );
end;
$_$;

-- Category-based related products for vendor_catalog shop product detail page.

CREATE OR REPLACE FUNCTION "public"."list_related_shop_catalog_products_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint, "p_limit" integer DEFAULT 4) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_id bigint;
  v_shop_tenant_id bigint;
  v_parent_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_vendor_code text;
  v_is_active boolean;
  v_vendor_filters jsonb;
  v_can_browse boolean;
  v_see_price boolean;
  v_category text;
  v_limit integer;
  v_data jsonb;
  v_min_available_units integer;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;
  if p_product_id is null then
    raise exception 'product required';
  end if;
  if public.current_customer_group_id(p_tenant_id) is null then
    raise exception 'access denied';
  end if;

  select
    id, tenant_id, shop_type, vendor_code, is_active, vendor_filters, min_available_units
  into
    v_shop_id, v_shop_tenant_id, v_shop_type, v_vendor_code, v_is_active, v_vendor_filters, v_min_available_units
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select can_browse
  into v_can_browse
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  if v_shop_type <> 'vendor_catalog' then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object('category', null)
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_shop_tenant_id);
  v_limit := greatest(1, least(coalesce(p_limit, 4), 12));

  select see_price
  into v_see_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  select p.category
  into v_category
  from public.products p
  where p.id = p_product_id
    and p.is_available = true
    and coalesce(p.hazardous, false) = false
    and p.parent_tenant_id = v_parent_tenant_id
    and (
      ((v_vendor_filters is null or jsonb_array_length(v_vendor_filters) = 0) and p.vendor_code = v_vendor_code)
      or
      (v_vendor_filters is not null and jsonb_array_length(v_vendor_filters) > 0 and exists (
        select 1
        from jsonb_to_recordset(v_vendor_filters) as vf(vendor_code text, brands text[])
        where vf.vendor_code = p.vendor_code
          and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
      ))
    )
    and public.shop_catalog_meets_min_available_units(v_min_available_units, p.available_units)
  limit 1;

  if v_category is null or trim(v_category) = '' or left(trim(v_category), 1) = '=' then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object('category', null)
    );
  end if;

  select coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'product_id', rel.id,
          'product_name', rel.name,
          'product_image_url', rel.image_url,
          'product_barcode', rel.barcode,
          'product_code', rel.product_code,
          'product_brand', rel.brand,
          'product_category', rel.category,
          'vendor_code', rel.vendor_code,
          'is_available', rel.is_available,
          'unit_price_amount', case when v_see_price then rel.list_price_amount else null end,
          'unit_price_currency_id', case when v_see_price then rel.list_price_currency_id else null end,
          'unit_price_currency_code', case when v_see_price then (select code from public.global_currencies where id = rel.list_price_currency_id) else null end,
          'unit_price_currency_symbol', case when v_see_price then (select symbol from public.global_currencies where id = rel.list_price_currency_id) else null end,
          'minimum_sell_price_amount', null,
          'minimum_sell_price_currency_id', null,
          'minimum_sell_price_currency_code', null,
          'minimum_sell_price_currency_symbol', null,
          'available_units', null,
          'global_stock_allocation_id', null,
          'global_stock_id', null,
          'minimum_order_quantity', rel.minimum_order_quantity
        )
        order by rel.name asc, rel.id asc
      )
      from (
        select p.*
        from public.products p
        where p.is_available = true
          and coalesce(p.hazardous, false) = false
          and p.parent_tenant_id = v_parent_tenant_id
          and p.id <> p_product_id
          and lower(coalesce(p.category, '')) = lower(trim(v_category))
          and (
            ((v_vendor_filters is null or jsonb_array_length(v_vendor_filters) = 0) and p.vendor_code = v_vendor_code)
            or
            (v_vendor_filters is not null and jsonb_array_length(v_vendor_filters) > 0 and exists (
              select 1
              from jsonb_to_recordset(v_vendor_filters) as vf(vendor_code text, brands text[])
              where vf.vendor_code = p.vendor_code
                and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
            ))
          )
          and public.shop_catalog_meets_min_available_units(v_min_available_units, p.available_units)
        order by p.name asc, p.id asc
        limit v_limit
      ) rel
    ),
    '[]'::jsonb
  )
  into v_data;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object('category', trim(v_category))
  );
end;
$$;

revoke all on function public.list_related_shop_catalog_products_for_customer(bigint, text, bigint, integer) from public;
grant execute on function public.list_related_shop_catalog_products_for_customer(bigint, text, bigint, integer) to authenticated;

CREATE OR REPLACE FUNCTION "public"."search_shop_catalog_for_customer"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_tenant_id bigint;
  v_search text;
  v_limit integer;
  v_offset integer;
  v_result jsonb;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;

  if public.current_customer_group_id(p_tenant_id) is null then
    raise exception 'access denied';
  end if;

  v_search := nullif(trim(coalesce(p_search, '')), '');
  v_limit := greatest(1, least(coalesce(p_limit, 20), 50));
  v_offset := greatest(0, coalesce(p_offset, 0));

  if v_search is null then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'total', 0,
        'page', 1,
        'page_size', v_limit,
        'total_pages', 1
      )
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  with accessible_shops as (
    select
      s.id,
      s.slug,
      s.name,
      s.shop_type,
      s.vendor_code,
      s.vendor_filters,
      s.min_available_units,
      s.tenant_id,
      s.pricing_method,
      s.markup_percentage,
      bool_or(
        case
          when access.status = false or coalesce(profile.is_active, true) = false then false
          else public.resolve_shop_can_see_buy_price(
            s.shop_type,
            access.can_see_buy_price,
            access.can_see_sell_price,
            profile.default_can_see_buy_price,
            profile.default_can_see_sell_price
          )
        end
      ) as can_see_buy_price,
      bool_or(
        case
          when access.status = false or coalesce(profile.is_active, true) = false then false
          when s.shop_type = 'dropship' then true
          else coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, false)
        end
      ) as can_see_sell_price
    from public.shops s
    join public.shop_customer_group_access access on access.shop_id = s.id
    join public.customer_groups cg on cg.id = access.customer_group_id
    left join public.customer_group_shop_profiles profile
      on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
    where s.is_active = true
      and s.deleted_at is null
      and s.tenant_id = p_tenant_id
      and cg.id = public.current_customer_group_id(p_tenant_id)
      and cg.is_active = true
      and access.status = true
      and coalesce(profile.is_active, true) = true
      and coalesce(access.can_browse, profile.default_can_browse, false) = true
    group by
      s.id,
      s.slug,
      s.name,
      s.shop_type,
      s.vendor_code,
      s.vendor_filters,
      s.min_available_units,
      s.tenant_id,
      s.pricing_method,
      s.markup_percentage
  ),
  vendor_catalog_rows as (
    select
      s.id as shop_id,
      s.slug as shop_slug,
      s.name as shop_name,
      p.id as product_id,
      p.name as product_name,
      p.image_url as product_image_url,
      p.barcode as product_barcode,
      p.product_code as product_code,
      p.brand as product_brand,
      p.category as product_category,
      case when s.can_see_buy_price then p.list_price_amount else null end as unit_price_amount,
      case when s.can_see_buy_price then p.list_price_currency_id else null end as unit_price_currency_id,
      case when s.can_see_buy_price then gc.symbol else null end as unit_price_currency_symbol
    from accessible_shops s
    join public.products p on p.parent_tenant_id = v_parent_tenant_id
    left join public.global_currencies gc on gc.id = p.list_price_currency_id
    where s.shop_type = 'vendor_catalog'
      and p.is_available = true
      and coalesce(p.hazardous, false) = false
      and (
        ((s.vendor_filters is null or jsonb_array_length(s.vendor_filters) = 0) and p.vendor_code = s.vendor_code)
        or (
          s.vendor_filters is not null and jsonb_array_length(s.vendor_filters) > 0 and exists (
            select 1
            from jsonb_to_recordset(s.vendor_filters) as vf(vendor_code text, brands text[])
            where vf.vendor_code = p.vendor_code
              and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
          )
        )
      )
      and public.shop_catalog_meets_min_available_units(s.min_available_units, p.available_units)
      and (
        p.name ilike ('%' || v_search || '%')
        or p.product_code ilike ('%' || v_search || '%')
        or p.barcode ilike ('%' || v_search || '%')
      )
  ),
  listing_rows as (
    select
      s.id as shop_id,
      s.slug as shop_slug,
      s.name as shop_name,
      p.id as product_id,
      p.name as product_name,
      p.image_url as product_image_url,
      p.barcode as product_barcode,
      p.product_code as product_code,
      p.brand as product_brand,
      p.category as product_category,
      case
        when s.shop_type = 'dropship' and not s.can_see_buy_price then null
        when s.shop_type = 'fixed_price' and not s.can_see_sell_price then null
        when s.shop_type = 'fixed_price' and s.pricing_method = 'markup' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + s.markup_percentage / 100.0)
        when s.shop_type = 'fixed_price' and s.pricing_method = 'direct_cost' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
        else l.sell_price_amount
      end as unit_price_amount,
      case
        when s.shop_type = 'dropship' and s.can_see_buy_price then l.sell_price_currency_id
        when s.shop_type = 'fixed_price' and s.can_see_sell_price then l.sell_price_currency_id
        else null
      end as unit_price_currency_id,
      case
        when s.shop_type = 'dropship' and s.can_see_buy_price then gc.symbol
        when s.shop_type = 'fixed_price' and s.can_see_sell_price then gc.symbol
        else null
      end as unit_price_currency_symbol
    from accessible_shops s
    join public.shop_product_listings l on l.shop_id = s.id
    join public.products p on p.id = l.product_id
    left join public.global_stocks gs on gs.id = l.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_currencies gc on gc.id = l.sell_price_currency_id
    where s.shop_type <> 'vendor_catalog'
      and l.is_active = true
      and p.is_available = true
      and coalesce(p.hazardous, false) = false
      and (
        p.name ilike ('%' || v_search || '%')
        or p.product_code ilike ('%' || v_search || '%')
        or p.barcode ilike ('%' || v_search || '%')
      )
  ),
  combined as (
    select * from vendor_catalog_rows
    union all
    select * from listing_rows
  ),
  ranked as (
    select
      c.*,
      row_number() over (
        partition by c.product_id
        order by c.shop_name asc, c.shop_id asc
      ) as row_num
    from combined c
  ),
  deduped as (
    select * from ranked where row_num = 1
  )
  select jsonb_build_object(
    'data',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'shop_id', d.shop_id,
            'shop_slug', d.shop_slug,
            'shop_name', d.shop_name,
            'product_id', d.product_id,
            'product_name', d.product_name,
            'product_image_url', d.product_image_url,
            'product_barcode', d.product_barcode,
            'product_code', d.product_code,
            'product_brand', d.product_brand,
            'product_category', d.product_category,
            'unit_price_amount', d.unit_price_amount,
            'unit_price_currency_id', d.unit_price_currency_id,
            'unit_price_currency_symbol', d.unit_price_currency_symbol
          )
          order by d.product_name asc, d.product_id asc
        )
        from (
          select *
          from deduped
          order by product_name asc, product_id asc
          limit v_limit
          offset v_offset
        ) d
      ),
      '[]'::jsonb
    ),
    'meta',
    jsonb_build_object(
      'total', (select count(*)::bigint from deduped),
      'page', (v_offset / v_limit) + 1,
      'page_size', v_limit,
      'total_pages', greatest(1, ceil((select count(*)::numeric from deduped) / v_limit::numeric))
    )
  )
  into v_result;

  return v_result;
end;
$$;

CREATE OR REPLACE FUNCTION public.add_to_shop_cart(
  p_shop_id bigint,
  p_product_id bigint,
  p_global_stock_allocation_id bigint DEFAULT NULL,
  p_quantity integer DEFAULT 1,
  p_customer_sell_price_amount numeric DEFAULT NULL,
  p_customer_sell_price_currency_id bigint DEFAULT NULL,
  p_global_stock_id bigint DEFAULT NULL,
  p_listing_id bigint DEFAULT NULL,
  p_grade_slug text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cart_res jsonb;
  v_cart_id bigint;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_quantity_display_mode text;
  v_buy_currency_id bigint;
  v_prod_name text;
  v_prod_image text;
  v_prod_price_amount numeric;
  v_prod_price_currency_id bigint;
  v_listing_id bigint;
  v_global_stock_id bigint;
  v_grade_tag_id bigint;
  v_sell_price_amount numeric;
  v_sell_price_currency_id bigint;
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
  v_display_qty_override integer;
  v_landed_cost numeric;
  v_available_to_sell integer;
  v_existing_item_id bigint;
  v_existing_item_qty integer;
  v_target_qty integer;
  v_can_add_to_cart boolean;
  v_can_set_dropship_price boolean;
  v_customer_sell_price_amount numeric;
  v_customer_sell_price_currency_id bigint;
  v_min_available_units integer;
  v_product_available_units integer;
BEGIN
  v_cart_res := public.get_or_create_shop_cart(p_shop_id);
  v_cart_id := (v_cart_res->'cart'->>'id')::bigint;

  SELECT tenant_id, shop_type, pricing_method, markup_percentage, buy_currency_id, quantity_display_mode, min_available_units
  INTO v_tenant_id, v_shop_type, v_pricing_method, v_markup_percentage, v_buy_currency_id, v_quantity_display_mode, v_min_available_units
  FROM public.shops
  WHERE id = p_shop_id;

  SELECT can_add_to_cart, can_set_dropship_price
  INTO v_can_add_to_cart, v_can_set_dropship_price
  FROM public.get_shop_permissions_for_customer(p_shop_id);

  IF coalesce(v_can_add_to_cart, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'cart additions not allowed';
  END IF;

  SELECT name, image_url, list_price_amount, list_price_currency_id, available_units
  INTO v_prod_name, v_prod_image, v_prod_price_amount, v_prod_price_currency_id, v_product_available_units
  FROM public.products
  WHERE id = p_product_id;

  IF v_prod_name IS NULL THEN
    RAISE EXCEPTION 'product not found';
  END IF;

  v_global_stock_id := coalesce(p_global_stock_id, p_global_stock_allocation_id);

  IF v_shop_type IN ('fixed_price', 'dropship') THEN
    IF p_listing_id IS NOT NULL THEN
      SELECT
        l.id, coalesce(l.grade_tag_id, gs.grade_tag_id), l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id, l.display_quantity_override
      INTO
        v_listing_id, v_grade_tag_id, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id, v_display_qty_override
      FROM public.shop_product_listings l
      LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
      WHERE l.id = p_listing_id
        AND l.shop_id = p_shop_id
        AND l.product_id = p_product_id
        AND l.is_active = TRUE;
    ELSIF v_global_stock_id IS NOT NULL THEN
      SELECT coalesce(gs_ref.grade_tag_id, public.default_stock_grade_tag_id())
      INTO v_grade_tag_id
      FROM public.global_stocks gs_ref
      WHERE gs_ref.id = v_global_stock_id;

      SELECT
        l.id, coalesce(l.grade_tag_id, gs.grade_tag_id), l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id, l.display_quantity_override
      INTO
        v_listing_id, v_grade_tag_id, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id, v_display_qty_override
      FROM public.shop_product_listings l
      LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
      WHERE l.shop_id = p_shop_id
        AND l.product_id = p_product_id
        AND l.is_active = TRUE
        AND coalesce(l.grade_tag_id, gs.grade_tag_id) = v_grade_tag_id
      ORDER BY l.id ASC
      LIMIT 1;
    ELSIF p_grade_slug IS NOT NULL AND trim(p_grade_slug) <> '' THEN
      SELECT
        l.id, coalesce(l.grade_tag_id, gs.grade_tag_id), l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id, l.display_quantity_override
      INTO
        v_listing_id, v_grade_tag_id, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id, v_display_qty_override
      FROM public.shop_product_listings l
      LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
      LEFT JOIN public.tags tg ON tg.id = coalesce(l.grade_tag_id, gs.grade_tag_id)
      WHERE l.shop_id = p_shop_id
        AND l.product_id = p_product_id
        AND l.is_active = TRUE
        AND coalesce(tg.slug, 'standard') = coalesce(nullif(trim(p_grade_slug), ''), 'standard')
      ORDER BY l.id ASC
      LIMIT 1;
    ELSE
      RAISE EXCEPTION 'listing, grade, or global stock required for this shop type';
    END IF;

    IF v_listing_id IS NULL THEN
      RAISE EXCEPTION 'active product listing not found on this shop';
    END IF;

    v_grade_tag_id := coalesce(v_grade_tag_id, public.default_stock_grade_tag_id());

    IF v_grade_tag_id IS NULL THEN
      RAISE EXCEPTION 'listing grade required';
    END IF;

    v_global_stock_id := NULL;

    SELECT public.shop_product_grade_avg_landed_cost(v_tenant_id, p_product_id, v_grade_tag_id)
    INTO v_landed_cost;

    IF v_shop_type = 'fixed_price' THEN
      IF v_pricing_method = 'markup' THEN
        v_sell_price_amount := v_landed_cost * (1 + v_markup_percentage / 100.0);
      ELSIF v_pricing_method = 'direct_cost' THEN
        v_sell_price_amount := v_landed_cost;
      END IF;
    END IF;

    v_available_to_sell := public.shop_product_grade_available_units(v_tenant_id, p_product_id, v_grade_tag_id);
    IF v_display_qty_override IS NOT NULL THEN
      v_available_to_sell := v_display_qty_override;
    END IF;

    SELECT id, quantity INTO v_existing_item_id, v_existing_item_qty
    FROM public.shop_cart_items
    WHERE cart_id = v_cart_id
      AND listing_id = v_listing_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;

    IF v_target_qty > v_available_to_sell THEN
      RAISE EXCEPTION 'insufficient stock: requested %, available %', v_target_qty, v_available_to_sell;
    END IF;

    IF v_shop_type = 'dropship' THEN
      IF coalesce(v_can_set_dropship_price, false) THEN
        IF p_customer_sell_price_amount IS NOT NULL THEN
          v_customer_sell_price_amount := p_customer_sell_price_amount;
          v_customer_sell_price_currency_id := p_customer_sell_price_currency_id;
        ELSE
          IF v_sell_price_currency_id = v_min_sell_price_currency_id THEN
            v_customer_sell_price_amount := greatest(v_sell_price_amount, coalesce(v_min_sell_price_amount, 0));
          ELSE
            v_customer_sell_price_amount := v_sell_price_amount;
          END IF;
          v_customer_sell_price_currency_id := v_sell_price_currency_id;
        END IF;

        IF v_customer_sell_price_currency_id = v_min_sell_price_currency_id
           AND v_customer_sell_price_amount < v_min_sell_price_amount THEN
          RAISE EXCEPTION 'price cannot be lower than the minimum sell price %', v_min_sell_price_amount;
        END IF;
      ELSE
        v_customer_sell_price_amount := v_sell_price_amount;
        v_customer_sell_price_currency_id := v_sell_price_currency_id;
      END IF;
    END IF;
  ELSE
    IF NOT public.shop_catalog_meets_min_available_units(v_min_available_units, v_product_available_units) THEN
      RAISE EXCEPTION 'product does not meet minimum available units requirement';
    END IF;

    SELECT id, quantity INTO v_existing_item_id, v_existing_item_qty
    FROM public.shop_cart_items
    WHERE cart_id = v_cart_id
      AND product_id = p_product_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;
  END IF;

  IF v_existing_item_id IS NOT NULL THEN
    UPDATE public.shop_cart_items
    SET
      quantity = v_target_qty,
      unit_sell_price_amount = v_sell_price_amount,
      customer_sell_price_amount = coalesce(v_customer_sell_price_amount, customer_sell_price_amount),
      customer_sell_price_currency_id = coalesce(v_customer_sell_price_currency_id, customer_sell_price_currency_id),
      updated_at = now()
    WHERE id = v_existing_item_id;
  ELSE
    INSERT INTO public.shop_cart_items (
      cart_id, product_id, listing_id, grade_tag_id, global_stock_id, global_stock_allocation_id,
      quantity, minimum_quantity,
      unit_list_price_amount, unit_list_price_currency_id,
      unit_sell_price_amount, unit_sell_price_currency_id,
      unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
      customer_sell_price_amount, customer_sell_price_currency_id,
      name, image_url
    )
    VALUES (
      v_cart_id, p_product_id, v_listing_id, v_grade_tag_id, NULL, NULL,
      p_quantity, 1,
      CASE WHEN v_shop_type = 'dropship' THEN coalesce(v_landed_cost, v_prod_price_amount) ELSE v_prod_price_amount END,
      CASE WHEN v_shop_type = 'dropship' THEN v_buy_currency_id ELSE v_prod_price_currency_id END,
      v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      v_prod_name, v_prod_image
    );
  END IF;

  RETURN public.get_or_create_shop_cart(p_shop_id);
END;
$$;

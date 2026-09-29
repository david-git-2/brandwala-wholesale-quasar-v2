-- browse shop catalog: offset pagination -> name+id cursor keyset
drop function if exists public.browse_shop_catalog_for_customer(bigint, text, text, text, text, integer, integer);
drop function if exists public.browse_shop_catalog_for_admin(bigint, bigint, text, integer, integer, boolean);

CREATE OR REPLACE FUNCTION "public"."browse_shop_catalog_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_search" "text" DEFAULT NULL::"text", "p_category" "text" DEFAULT NULL::"text", "p_brand" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_cursor_name" "text" DEFAULT NULL::"text", "p_cursor_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
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
  v_min_available_units integer;
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
  v_fetch_limit integer;
  v_cursor_name text;
  v_result jsonb;
  v_parent_tenant_id bigint;
  v_data jsonb;
  v_n integer;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
  v_last_name text;
  v_last_id bigint;
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
  v_fetch_limit := v_limit + 1;
  v_cursor_name := coalesce(p_cursor_name, '');
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
            and ($11 = 0 or coalesce(p.available_units, 0) >= $11)
            and ($8 is null or (coalesce(p.name, ''), p.id) > (coalesce($7, ''), $8))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.name asc, f.id asc
          limit $6
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
                    when $10 then jsonb_build_object(
                      'amount', p.list_price_amount,
                      'currency_id', p.list_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.list_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.list_price_currency_id)
                    )
                    else null
                  end,
                  'unit_price_amount', case when $10 then p.list_price_amount else null end,
                  'unit_price_currency_id', case when $10 then p.list_price_currency_id else null end,
                  'unit_price_currency_code', case
                    when $10 then (select code from public.global_currencies where id = p.list_price_currency_id)
                    else null
                  end,
                  'unit_price_currency_symbol', case
                    when $10 then (select symbol from public.global_currencies where id = p.list_price_currency_id)
                    else null
                  end,
                  'sell_price', null,
                  'resell_minimum_price', null,
                  'available_units', null,
                  'global_stock_allocation_id', null,
                  'global_stock_id', null,
                  'minimum_order_quantity', p.minimum_order_quantity
                )
                order by p.name asc, p.id asc
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta', jsonb_build_object('limit', $6 - 1)
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
      v_fetch_limit,
      v_cursor_name,
      p_cursor_id,
      v_vendor_filters,
      v_can_see_catalog_price,
      coalesce(v_min_available_units, 0);
  else
    execute format(
      $sql$
        with filtered as (
          select
            l.id as listing_id,
            l.global_stock_id,
            case
              when $9 = 'fixed_price' and $12 = 'markup' then
                coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + $13 / 100.0)
              when $9 = 'fixed_price' and $12 = 'direct_cost' then
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
              $15,
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
            and ($7 is null or (coalesce(p.name, ''), l.id) > (coalesce($6, ''), $7))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.product_name asc, f.listing_id asc
          limit $5
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
                    when $9 = 'dropship' and $16 then jsonb_build_object(
                      'amount', p.computed_unit_cost,
                      'currency_id', $17,
                      'code', (select code from public.global_currencies where id = $17),
                      'symbol', (select symbol from public.global_currencies where id = $17)
                    )
                    else null
                  end,
                  'sell_price', case
                    when $8 and $9 = 'fixed_price' then jsonb_build_object(
                      'amount', p.computed_sell_price,
                      'currency_id', p.sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.sell_price_currency_id)
                    )
                    when $8 and $9 = 'dropship' then jsonb_build_object(
                      'amount', p.listing_sell_price_amount,
                      'currency_id', p.listing_sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.listing_sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.listing_sell_price_currency_id)
                    )
                    else null
                  end,
                  'resell_minimum_price', case
                    when $18 and $9 = 'dropship' then jsonb_build_object(
                      'amount', p.minimum_sell_price_amount,
                      'currency_id', p.minimum_sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.minimum_sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.minimum_sell_price_currency_id)
                    )
                    else null
                  end,
                  'available_units', case
                    when not $10 or not coalesce(p.listing_show_quantity, $11) then null
                    when $14 = 'original' then greatest(0, p.available_qty)
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
                order by p.product_name asc, p.listing_id asc
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta', jsonb_build_object('limit', $5 - 1)
        )
      $sql$
    )
    into v_result
    using
      v_shop_id,
      p_search,
      p_category,
      p_brand,
      v_fetch_limit,
      v_cursor_name,
      p_cursor_id,
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

  v_data := coalesce(v_result->'data', '[]'::jsonb);
  v_n := jsonb_array_length(v_data);
  if v_n > v_limit then
    v_has_more := true;
    select
      coalesce(t.elem->>'product_name', ''),
      case
        when v_shop_type = 'vendor_catalog' then (t.elem->>'product_id')::bigint
        else (t.elem->>'listing_id')::bigint
      end
    into v_last_name, v_last_id
    from jsonb_array_elements(v_data) with ordinality as t(elem, ord)
    where ord = v_limit;

    v_next_cursor := jsonb_build_object('name', v_last_name, 'id', v_last_id);

    select coalesce(jsonb_agg(elem order by ord), '[]'::jsonb)
    into v_data
    from (
      select elem, ord
      from jsonb_array_elements(v_data) with ordinality as t(elem, ord)
      where ord <= v_limit
    ) trimmed;
  end if;

  v_result := jsonb_set(
    jsonb_set(v_result, '{data}', v_data),
    '{meta}',
    coalesce(v_result->'meta', '{}'::jsonb)
      || jsonb_build_object(
        'has_more', v_has_more,
        'next_cursor', v_next_cursor,
        'limit', v_limit
      )
  );

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




CREATE OR REPLACE FUNCTION "public"."browse_shop_catalog_for_admin"("p_tenant_id" bigint, "p_shop_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 24, "p_cursor_name" "text" DEFAULT NULL::"text", "p_cursor_id" bigint DEFAULT NULL::bigint, "p_include_below_min_units" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop record;
  v_parent_tenant_id bigint;
  v_limit integer;
  v_fetch_limit integer;
  v_min_units integer;
  v_result jsonb;
  v_data jsonb;
  v_n integer;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
  v_cursor_name text;
  v_last_name text;
  v_last_id bigint;
begin
  if p_tenant_id is null or p_shop_id is null then
    raise exception 'tenant and shop are required';
  end if;

  if not public.user_can_manage_shop_tenant(p_tenant_id)
     and not public.user_can_manage_shop_tenant(public.resolve_parent_tenant_id(p_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  select
    id,
    tenant_id,
    shop_type,
    vendor_code,
    vendor_filters,
    min_available_units
  into v_shop
  from public.shops
  where id = p_shop_id
    and (tenant_id = p_tenant_id or parent_tenant_id = p_tenant_id)
    and deleted_at is null;

  if v_shop.id is null then
    raise exception 'shop not found';
  end if;

  if v_shop.shop_type <> 'vendor_catalog' then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'has_more', false,
        'next_cursor', null,
        'limit', greatest(1, least(coalesce(p_limit, 24), 200))
      )
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_shop.tenant_id);
  v_limit := greatest(1, least(coalesce(p_limit, 24), 200));
  v_fetch_limit := v_limit + 1;
  v_cursor_name := coalesce(p_cursor_name, '');
  v_min_units := case
    when coalesce(p_include_below_min_units, false) then 0
    else coalesce(v_shop.min_available_units, 0)
  end;

  with filtered as (
    select p.*
    from public.products p
    where p.is_available = true
      and coalesce(p.hazardous, false) = false
      and p.parent_tenant_id = v_parent_tenant_id
      and (
        ((v_shop.vendor_filters is null or jsonb_array_length(v_shop.vendor_filters) = 0)
          and p.vendor_code = v_shop.vendor_code)
        or (
          v_shop.vendor_filters is not null
          and jsonb_array_length(v_shop.vendor_filters) > 0
          and exists (
            select 1
            from jsonb_to_recordset(v_shop.vendor_filters) as vf(vendor_code text, brands text[])
            where vf.vendor_code = p.vendor_code
              and (
                vf.brands is null
                or array_length(vf.brands, 1) is null
                or p.brand = any(vf.brands)
              )
          )
        )
      )
      and (
        p_search is null
        or trim(p_search) = ''
        or p.name ilike ('%' || trim(p_search) || '%')
        or p.product_code ilike ('%' || trim(p_search) || '%')
        or p.barcode ilike ('%' || trim(p_search) || '%')
      )
      and (v_min_units = 0 or coalesce(p.available_units, 0) >= v_min_units)
      and (
        p_cursor_id is null
        or (coalesce(p.name, ''), p.id) > (v_cursor_name, p_cursor_id)
      )
  ),
  paged as (
    select f.*
    from filtered f
    order by f.name asc, f.id asc
    limit v_fetch_limit
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
            'product_brand', p.brand,
            'vendor_code', p.vendor_code,
            'country_of_origin', p.country_of_origin,
            'batch_code_manufacture_date', p.batch_code_manufacture_date,
            'expire_date', p.expire_date,
            'languages', p.languages,
            'available_units', p.available_units,
            'unit_price_amount', p.list_price_amount,
            'unit_price_currency_id', p.list_price_currency_id,
            'unit_price_currency_code', (
              select code from public.global_currencies where id = p.list_price_currency_id
            ),
            'unit_price_currency_symbol', (
              select symbol from public.global_currencies where id = p.list_price_currency_id
            )
          )
          order by p.name asc, p.id asc
        )
        from paged p
      ),
      '[]'::jsonb
    ),
    'meta', jsonb_build_object('limit', v_limit)
  )
  into v_result;

  v_data := coalesce(v_result->'data', '[]'::jsonb);
  v_n := jsonb_array_length(v_data);
  if v_n > v_limit then
    v_has_more := true;
    select
      coalesce(t.elem->>'product_name', ''),
      (t.elem->>'product_id')::bigint
    into v_last_name, v_last_id
    from jsonb_array_elements(v_data) with ordinality as t(elem, ord)
    where ord = v_limit;

    v_next_cursor := jsonb_build_object('name', v_last_name, 'id', v_last_id);

    select coalesce(jsonb_agg(elem order by ord), '[]'::jsonb)
    into v_data
    from (
      select elem, ord
      from jsonb_array_elements(v_data) with ordinality as t(elem, ord)
      where ord <= v_limit
    ) trimmed;
  end if;

  v_result := jsonb_set(
    jsonb_set(v_result, '{data}', v_data),
    '{meta}',
    jsonb_build_object(
      'has_more', v_has_more,
      'next_cursor', v_next_cursor,
      'limit', v_limit
    )
  );

  return v_result;
end;
$$;

REVOKE ALL ON FUNCTION "public"."browse_shop_catalog_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_search" "text", "p_category" "text", "p_brand" "text", "p_limit" integer, "p_cursor_name" "text", "p_cursor_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."browse_shop_catalog_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_search" "text", "p_category" "text", "p_brand" "text", "p_limit" integer, "p_cursor_name" "text", "p_cursor_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."browse_shop_catalog_for_admin"("p_tenant_id" bigint, "p_shop_id" bigint, "p_search" "text", "p_limit" integer, "p_cursor_name" "text", "p_cursor_id" bigint, "p_include_below_min_units" boolean) TO "authenticated";

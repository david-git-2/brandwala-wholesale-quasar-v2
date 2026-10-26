-- Shop storefront/stock RPCs: parent-pool stock visibility + grade-aggregated available units.

CREATE OR REPLACE FUNCTION public.shop_shipment_alloc_visible_to_tenant(
  p_assigned_child_tenant_id bigint,
  p_shop_tenant_id bigint
) RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT
    p_shop_tenant_id = public.resolve_parent_tenant_id(p_shop_tenant_id)
    OR p_assigned_child_tenant_id IS NULL
    OR p_assigned_child_tenant_id = p_shop_tenant_id;
$$;

CREATE OR REPLACE FUNCTION public.shop_product_grade_available_units(
  p_shop_tenant_id bigint,
  p_product_id bigint,
  p_grade_tag_id bigint DEFAULT NULL
) RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(
    sum(greatest(0, floor(public.global_stock_atp_qty(gs.id))))::integer,
    0
  )
  FROM public.global_stocks gs
  JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
  LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
  WHERE gsi.product_id = p_product_id
    AND coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id())
      = coalesce(p_grade_tag_id, public.default_stock_grade_tag_id())
    AND gs.parent_tenant_id = public.resolve_parent_tenant_id(p_shop_tenant_id)
    AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, p_shop_tenant_id)
    AND gship.status = 'received'
    AND gs.availability = 'sellable'::public.stock_availability
    AND (gs.location_id IS NULL OR sl.is_pickable = true);
$$;

GRANT EXECUTE ON FUNCTION public.shop_shipment_alloc_visible_to_tenant(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.shop_product_grade_available_units(bigint, bigint, bigint) TO authenticated;

-- list_allocated_stock_for_shop
CREATE OR REPLACE FUNCTION public.list_allocated_stock_for_shop(
  p_shop_id bigint,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 200,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_shop_tenant_id bigint;
  v_total_count bigint;
  v_data jsonb;
  v_limit integer;
  v_offset integer;
BEGIN
  SELECT s.tenant_id INTO v_shop_tenant_id
  FROM public.shops s
  WHERE s.id = p_shop_id
    AND s.deleted_at IS NULL;

  IF v_shop_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop not found';
  END IF;

  IF NOT public.has_active_tenant_membership(v_shop_tenant_id)
     AND NOT public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_shop_tenant_id))
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  v_limit := greatest(1, least(coalesce(p_limit, 200), 500));
  v_offset := greatest(0, coalesce(p_offset, 0));

  SELECT count(DISTINCT gs.id)
  INTO v_total_count
  FROM public.global_stocks gs
  JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
  LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
  LEFT JOIN public.tags tg ON tg.id = gs.grade_tag_id
  WHERE gs.parent_tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
    AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
    AND gship.status = 'received'
    AND gs.availability = 'sellable'::public.stock_availability
    AND (gs.location_id IS NULL OR sl.is_pickable = true)
    AND (
      p_search IS NULL
      OR p_search = ''
      OR (
        gsi.name ILIKE '%' || p_search || '%'
        OR gsi.product_code ILIKE '%' || p_search || '%'
        OR gsi.barcode ILIKE '%' || p_search || '%'
        OR gship.name ILIKE '%' || p_search || '%'
        OR tg.name ILIKE '%' || p_search || '%'
      )
    );

  SELECT coalesce(jsonb_agg(row_json ORDER BY sort_id DESC), '[]'::jsonb)
  INTO v_data
  FROM (
    SELECT
      gs.id AS sort_id,
      jsonb_build_object(
        'global_stock_id', gs.id,
        'shipment_item_id', gsi.id,
        'shipment_id', gship.id,
        'shipment_name', gship.name,
        'item_name', gsi.name,
        'product_id', gsi.product_id,
        'product_code', gsi.product_code,
        'barcode', gsi.barcode,
        'image_url', gsi.image_url,
        'product_brand', p.brand,
        'product_category', p.category,
        'available_atp', public.global_stock_atp_qty(gs.id),
        'total_stock_qty', gs.quantity,
        'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(gsi.id), 0.00),
        'stock_grade', CASE
          WHEN tg.slug IS NOT NULL THEN jsonb_build_object(
            'slug', tg.slug,
            'label', tg.name,
            'color', tg.color
          )
          ELSE NULL
        END,
        'is_listed_on_shop', EXISTS (
          SELECT 1
          FROM public.shop_product_listings spl
          WHERE spl.shop_id = p_shop_id
            AND spl.global_stock_id = gs.id
        ),
        'listing_id', (
          SELECT spl.id
          FROM public.shop_product_listings spl
          WHERE spl.shop_id = p_shop_id
            AND spl.global_stock_id = gs.id
          LIMIT 1
        )
      ) AS row_json
    FROM public.global_stocks gs
    JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
    JOIN public.products p ON p.id = gsi.product_id
    LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
    LEFT JOIN public.tags tg ON tg.id = gs.grade_tag_id
    WHERE gs.parent_tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
      AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
      AND gship.status = 'received'
      AND gs.availability = 'sellable'::public.stock_availability
      AND (gs.location_id IS NULL OR sl.is_pickable = true)
      AND (
        p_search IS NULL
        OR p_search = ''
        OR (
          gsi.name ILIKE '%' || p_search || '%'
          OR gsi.product_code ILIKE '%' || p_search || '%'
          OR gsi.barcode ILIKE '%' || p_search || '%'
          OR gship.name ILIKE '%' || p_search || '%'
          OR tg.name ILIKE '%' || p_search || '%'
        )
      )
    ORDER BY gs.id DESC
    LIMIT v_limit
    OFFSET v_offset
  ) q;

  RETURN jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', (v_offset / v_limit) + 1,
      'page_size', v_limit,
      'total_pages', greatest(1, ceil(v_total_count::numeric / v_limit::numeric))
    )
  );
END;
$$;

-- get_shop_storefront_listing_price_calculation
CREATE OR REPLACE FUNCTION public.get_shop_storefront_listing_price_calculation(
  p_shop_id bigint,
  p_listing_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_buy_currency_id bigint;
  v_sell_currency_id bigint;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_listing record;
  v_product_id bigint;
  v_grade_tag_id bigint;
  v_cost_currency_id bigint;
  v_result jsonb;
BEGIN
  SELECT
    s.tenant_id,
    s.shop_type,
    s.buy_currency_id,
    s.sell_currency_id,
    s.pricing_method,
    s.markup_percentage
  INTO
    v_tenant_id,
    v_shop_type,
    v_buy_currency_id,
    v_sell_currency_id,
    v_pricing_method,
    v_markup_percentage
  FROM public.shops s
  WHERE s.id = p_shop_id
    AND s.deleted_at IS NULL;

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop not found';
  END IF;

  IF NOT public.has_active_tenant_membership(v_tenant_id)
     AND NOT public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_tenant_id))
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  SELECT
    l.id,
    l.shop_id,
    l.product_id,
    l.global_stock_id,
    l.sell_price_amount,
    l.sell_price_currency_id,
    l.minimum_sell_price_amount,
    l.minimum_sell_price_currency_id,
    l.display_quantity_override,
    l.is_active,
    l.is_price_locked,
    l.show_quantity,
    p.name AS product_name,
    p.product_code,
    p.image_url AS product_image_url,
    tg.slug AS grade_slug,
    tg.name AS grade_label,
    tg.color AS grade_color,
    gs.grade_tag_id
  INTO v_listing
  FROM public.shop_product_listings l
  JOIN public.products p ON p.id = l.product_id
  LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
  LEFT JOIN public.tags tg ON tg.id = gs.grade_tag_id
  WHERE l.id = p_listing_id
    AND l.shop_id = p_shop_id;

  IF v_listing.id IS NULL THEN
    RAISE EXCEPTION 'listing not found';
  END IF;

  v_product_id := v_listing.product_id;
  v_grade_tag_id := coalesce(v_listing.grade_tag_id, public.default_stock_grade_tag_id());
  v_cost_currency_id := CASE
    WHEN v_shop_type = 'dropship'::public.shop_type_enum THEN v_buy_currency_id
    ELSE v_sell_currency_id
  END;

  WITH stock_lines AS (
    SELECT
      gship.id AS shipment_id,
      gship.name AS shipment_name,
      greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer AS quantity,
      coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id), 0)::numeric AS unit_cost_amount
    FROM public.global_stocks gs
    JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
    LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
    WHERE gsi.product_id = v_product_id
      AND coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
      AND gs.parent_tenant_id = public.resolve_parent_tenant_id(v_tenant_id)
      AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_tenant_id)
      AND gship.status = 'received'
      AND gs.availability = 'sellable'::public.stock_availability
      AND (gs.location_id IS NULL OR sl.is_pickable = true)
      AND public.global_stock_atp_qty(gs.id) > 0
  ),
  shipment_agg AS (
    SELECT
      sl.shipment_id,
      sl.shipment_name,
      sum(sl.quantity)::integer AS quantity,
      CASE
        WHEN sum(sl.quantity) > 0 THEN round(sum(sl.quantity * sl.unit_cost_amount) / sum(sl.quantity), 4)
        ELSE 0::numeric
      END AS unit_cost_amount
    FROM stock_lines sl
    GROUP BY sl.shipment_id, sl.shipment_name
  ),
  totals AS (
    SELECT
      coalesce(sum(sa.quantity), 0)::integer AS total_quantity,
      CASE
        WHEN coalesce(sum(sa.quantity), 0) > 0 THEN round(
          (
            SELECT sum(sl.quantity * sl.unit_cost_amount)
            FROM stock_lines sl
          ) / sum(sa.quantity),
          4
        )
        ELSE 0::numeric
      END AS weighted_avg_cost
    FROM shipment_agg sa
  )
  SELECT
    jsonb_build_object(
      'listing',
      jsonb_build_object(
        'listing_id', v_listing.id,
        'shop_id', v_listing.shop_id,
        'product_id', v_product_id,
        'product_name', v_listing.product_name,
        'product_code', v_listing.product_code,
        'product_image_url', v_listing.product_image_url,
        'global_stock_id', v_listing.global_stock_id,
        'grade_tag_id', v_grade_tag_id,
        'stock_grade',
        CASE
          WHEN v_listing.grade_slug IS NOT NULL THEN jsonb_build_object(
            'slug', v_listing.grade_slug,
            'label', v_listing.grade_label,
            'color', v_listing.grade_color
          )
          ELSE NULL
        END,
        'is_active', v_listing.is_active,
        'is_price_locked', v_listing.is_price_locked
      ),
      'shipment_costs',
      coalesce(
        (
          SELECT jsonb_agg(
            jsonb_build_object(
              'shipment_id', sa.shipment_id,
              'shipment_no', 'SHP-' || sa.shipment_id::text,
              'shipment_name', sa.shipment_name,
              'quantity', sa.quantity,
              'unit_cost_amount', sa.unit_cost_amount
            )
            ORDER BY sa.shipment_name ASC, sa.shipment_id ASC
          )
          FROM shipment_agg sa
        ),
        '[]'::jsonb
      ),
      'totals',
      (
        SELECT jsonb_build_object(
          'total_quantity', t.total_quantity,
          'real_available_units', t.total_quantity,
          'weighted_avg_cost',
          jsonb_build_object(
            'amount', t.weighted_avg_cost,
            'currency_id', v_cost_currency_id,
            'code', (SELECT gc.code FROM public.global_currencies gc WHERE gc.id = v_cost_currency_id),
            'symbol', (SELECT gc.symbol FROM public.global_currencies gc WHERE gc.id = v_cost_currency_id)
          )
        )
        FROM totals t
      ),
      'pricing',
      jsonb_build_object(
        'display_quantity_override', v_listing.display_quantity_override,
        'suggested_display_quantity', coalesce((SELECT t.total_quantity FROM totals t), 0),
        'sell_price',
        jsonb_build_object(
          'amount', v_listing.sell_price_amount,
          'currency_id', v_listing.sell_price_currency_id,
          'code', (SELECT gc.code FROM public.global_currencies gc WHERE gc.id = v_listing.sell_price_currency_id),
          'symbol', (SELECT gc.symbol FROM public.global_currencies gc WHERE gc.id = v_listing.sell_price_currency_id)
        ),
        'suggested_sell_price',
        CASE
          WHEN v_shop_type = 'fixed_price'::public.shop_type_enum
            AND v_pricing_method = 'markup'
            AND (SELECT t.weighted_avg_cost FROM totals t) IS NOT NULL THEN jsonb_build_object(
            'amount',
            round((SELECT t.weighted_avg_cost FROM totals t) * (1 + coalesce(v_markup_percentage, 0) / 100.0), 4),
            'currency_id', v_listing.sell_price_currency_id,
            'code', (SELECT gc.code FROM public.global_currencies gc WHERE gc.id = v_listing.sell_price_currency_id),
            'symbol', (SELECT gc.symbol FROM public.global_currencies gc WHERE gc.id = v_listing.sell_price_currency_id)
          )
          ELSE NULL
        END,
        'resell_minimum_price',
        CASE
          WHEN v_shop_type = 'dropship'::public.shop_type_enum
            AND v_listing.minimum_sell_price_amount IS NOT NULL THEN jsonb_build_object(
            'amount', v_listing.minimum_sell_price_amount,
            'currency_id', v_listing.minimum_sell_price_currency_id,
            'code', (SELECT gc.code FROM public.global_currencies gc WHERE gc.id = v_listing.minimum_sell_price_currency_id),
            'symbol', (SELECT gc.symbol FROM public.global_currencies gc WHERE gc.id = v_listing.minimum_sell_price_currency_id)
          )
          ELSE NULL
        END
      ),
      'shop',
      jsonb_build_object(
        'id', p_shop_id,
        'shop_type', v_shop_type,
        'pricing_method', v_pricing_method,
        'markup_percentage', v_markup_percentage,
        'sell_currency_id', v_sell_currency_id,
        'buy_currency_id', v_buy_currency_id
      )
    )
  INTO v_result;

  RETURN v_result;
END;
$$;


-- browse_shop_catalog_for_customer
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
      v_can_see_buy_price,
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
            public.shop_product_grade_available_units($14, p.id, gs.grade_tag_id) as available_qty
          from public.shop_product_listings l
          join public.products p on p.id = l.product_id
          left join public.global_stocks gs on gs.id = l.global_stock_id
          left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
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


-- get_shop_catalog_product_for_customer
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
    vendor_filters
  into
    v_shop_id, v_shop_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
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
      'unit_price_amount', case when v_can_see_buy_price then p.list_price_amount else null end,
      'unit_price_currency_id', case when v_can_see_buy_price then p.list_price_currency_id else null end,
      'unit_price_currency_code', case when v_can_see_buy_price then (select code from public.global_currencies where id = p.list_price_currency_id) else null end,
      'unit_price_currency_symbol', case when v_can_see_buy_price then (select symbol from public.global_currencies where id = p.list_price_currency_id) else null end,
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
        public.shop_product_grade_available_units(v_shop_tenant_id, p.id, gs.grade_tag_id) as available_qty
      from public.shop_product_listings l
      join public.products p on p.id = l.product_id
      left join public.global_stocks gs on gs.id = l.global_stock_id
      left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
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


-- search_shop_catalog_for_customer
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
      s.tenant_id,
      s.pricing_method,
      s.markup_percentage,
      bool_or(
        case
          when access.status = false or coalesce(profile.is_active, true) = false then false
          when s.shop_type = 'dropship' then true
          else coalesce(access.can_see_buy_price, profile.default_can_see_buy_price, false)
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


-- list_listable_stock_for_shop
CREATE OR REPLACE FUNCTION "public"."list_listable_stock_for_shop"("p_shop_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_tenant_id bigint;
  v_total_count bigint;
  v_data jsonb;
begin
  select s.tenant_id into v_shop_tenant_id
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;
  if v_shop_tenant_id is null then
    raise exception 'shop not found';
  end if;
  if not public.has_active_tenant_membership(v_shop_tenant_id)
     and not public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_shop_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  select count(distinct gs.id)
  into v_total_count
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.stock_locations sl on sl.id = gs.location_id
  where gs.parent_tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
    and public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
    and gship.status = 'received'
    and gs.availability = 'sellable'::public.stock_availability
    and (gs.location_id is null or sl.is_pickable = true)
    and public.global_stock_atp_qty(gs.id) > 0
    and not exists (
      select 1 from public.shop_product_listings spl
      where spl.shop_id = p_shop_id
        and spl.global_stock_id = gs.id
        and spl.is_active = true
    )
    and (
      p_search is null or p_search = '' or (
        gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or gship.name ilike '%' || p_search || '%'
      )
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id as sort_id,
      jsonb_build_object(
        'global_stock_id', gs.id,
        'shipment_item_id', gsi.id,
        'shipment_id', gship.id,
        'shipment_name', gship.name,
        'item_name', gsi.name,
        'product_id', gsi.product_id,
        'product_code', gsi.product_code,
        'barcode', gsi.barcode,
        'image_url', gsi.image_url,
        'available_atp', public.global_stock_atp_qty(gs.id),
        'total_stock_qty', gs.quantity,
        'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(gsi.id), 0.00)
      ) as row_json
    from public.global_stocks gs
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.stock_locations sl on sl.id = gs.location_id
    where gs.parent_tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
      and public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
      and gship.status = 'received'
      and gs.availability = 'sellable'::public.stock_availability
      and (gs.location_id is null or sl.is_pickable = true)
      and public.global_stock_atp_qty(gs.id) > 0
      and not exists (
        select 1 from public.shop_product_listings spl
        where spl.shop_id = p_shop_id
          and spl.global_stock_id = gs.id
          and spl.is_active = true
      )
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
        )
      )
    order by gs.id desc
    limit p_limit
    offset p_offset
  ) q;

  return jsonb_build_object(
    'data', v_data,
    'total', v_total_count
  );
end;
$$;
ALTER FUNCTION "public"."list_listable_stock_for_shop"("p_shop_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

-- list_shop_storefront_listings_for_admin
CREATE OR REPLACE FUNCTION public.list_shop_storefront_listings_for_admin(
  p_shop_id bigint,
  p_search text default null,
  p_limit integer default 200,
  p_offset integer default 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
as $$
declare
  v_tenant_id bigint;
  v_shop_name text;
  v_shop_slug text;
  v_shop_type public.shop_type_enum;
  v_buy_currency_id bigint;
  v_sell_currency_id bigint;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_quantity_display_mode text;
  v_limit integer;
  v_offset integer;
  v_result jsonb;
begin
  select
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.buy_currency_id,
    s.sell_currency_id,
    s.pricing_method,
    s.markup_percentage,
    s.quantity_display_mode
  into
    v_tenant_id,
    v_shop_name,
    v_shop_slug,
    v_shop_type,
    v_buy_currency_id,
    v_sell_currency_id,
    v_pricing_method,
    v_markup_percentage,
    v_quantity_display_mode
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;

  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.has_active_tenant_membership(v_tenant_id)
     and not public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  if v_shop_type = 'vendor_catalog' then
    return jsonb_build_object(
      'data',
      '[]'::jsonb,
      'meta',
      jsonb_build_object(
        'total',
        0,
        'page',
        1,
        'page_size',
        0,
        'total_pages',
        1,
        'shop',
        jsonb_build_object(
          'id',
          p_shop_id,
          'name',
          v_shop_name,
          'slug',
          v_shop_slug,
          'shop_type',
          v_shop_type
        )
      )
    );
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 200), 500));
  v_offset := greatest(0, coalesce(p_offset, 0));

  with filtered as (
    select
      l.id as listing_id,
      l.product_id,
      l.global_stock_id,
      l.global_stock_allocation_id,
      l.sell_price_amount as listing_sell_price_amount,
      l.sell_price_currency_id as listing_sell_price_currency_id,
      l.minimum_sell_price_amount,
      l.minimum_sell_price_currency_id,
      l.show_quantity,
      l.display_quantity_override,
      l.is_active,
      coalesce(
        gsi.landed_cost_bdt,
        public.calculate_landed_unit_cost(gsi.id),
        p.reference_cost_amount,
        0
      )::numeric as unit_cost_amount,
      case
        when l.global_stock_id is null then coalesce(l.sell_price_amount, p.list_price_amount, 0)
        when v_shop_type = 'fixed_price'::public.shop_type_enum
          and v_pricing_method = 'markup' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id), 0)
          * (1 + coalesce(v_markup_percentage, 0) / 100.0)
        when v_shop_type = 'fixed_price'::public.shop_type_enum
          and v_pricing_method = 'direct_cost' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id), 0)
        else
          l.sell_price_amount
      end as computed_sell_price,
      p.name as product_name,
      p.image_url as product_image_url,
      p.barcode as product_barcode,
      p.product_code as product_code,
      p.brand as product_brand,
      p.category as product_category,
      p.vendor_code as vendor_code,
      p.is_available as product_is_available,
      p.minimum_order_quantity as product_moq,
      public.shop_product_grade_available_units(v_tenant_id, l.product_id, gs.grade_tag_id) as real_available_units,
      tg.slug as grade_slug,
      tg.name as grade_label,
      tg.color as grade_color
    from public.shop_product_listings l
    join public.products p on p.id = l.product_id
    left join public.global_stocks gs on gs.id = l.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.tags tg on tg.id = gs.grade_tag_id
    where l.shop_id = p_shop_id
      and (
        p_search is null
        or trim(p_search) = ''
        or p.name ilike ('%' || trim(p_search) || '%')
        or p.product_code ilike ('%' || trim(p_search) || '%')
        or p.barcode ilike ('%' || trim(p_search) || '%')
        or p.brand ilike ('%' || trim(p_search) || '%')
        or p.category ilike ('%' || trim(p_search) || '%')
        or tg.name ilike ('%' || trim(p_search) || '%')
        or tg.slug ilike ('%' || trim(p_search) || '%')
      )
  ),
  paged as (
    select
      f.*
    from filtered f
    order by f.product_name asc, f.grade_slug asc nulls last, f.listing_id asc
    limit v_limit
    offset v_offset
  )
  select
    jsonb_build_object(
      'data',
      coalesce(
        (
          select
            jsonb_agg(
              jsonb_build_object(
                'listing_id',
                p.listing_id,
                'product_id',
                p.product_id,
                'product_name',
                p.product_name,
                'product_image_url',
                p.product_image_url,
                'product_barcode',
                p.product_barcode,
                'product_code',
                p.product_code,
                'product_brand',
                p.product_brand,
                'product_category',
                p.product_category,
                'vendor_code',
                p.vendor_code,
                'is_available',
                p.product_is_available,
                'minimum_order_quantity',
                p.product_moq,
                'global_stock_id',
                p.global_stock_id,
                'global_stock_allocation_id',
                p.global_stock_allocation_id,
                'real_available_units',
                p.real_available_units,
                'display_quantity_override',
                p.display_quantity_override,
                'available_units',
                case
                  when p.display_quantity_override is not null then p.display_quantity_override
                  else p.real_available_units
                end,
                'listing_status',
                case
                  when p.is_active then 'active'
                  else 'inactive'
                end,
                'stock_grade',
                case
                  when p.grade_slug is not null then jsonb_build_object(
                    'slug',
                    p.grade_slug,
                    'label',
                    p.grade_label,
                    'color',
                    p.grade_color
                  )
                  else null
                end,
                'unit_price',
                case
                  when v_shop_type = 'dropship'::public.shop_type_enum then jsonb_build_object(
                    'amount',
                    round(p.unit_cost_amount, 4),
                    'currency_id',
                    v_buy_currency_id,
                    'code',
                    (
                      select gc.code
                      from public.global_currencies gc
                      where gc.id = v_buy_currency_id
                    ),
                    'symbol',
                    (
                      select gc.symbol
                      from public.global_currencies gc
                      where gc.id = v_buy_currency_id
                    )
                  )
                  else null
                end,
                'sell_price',
                jsonb_build_object(
                  'amount',
                  round(p.computed_sell_price, 4),
                  'currency_id',
                  p.listing_sell_price_currency_id,
                  'code',
                  (
                    select gc.code
                    from public.global_currencies gc
                    where gc.id = p.listing_sell_price_currency_id
                  ),
                  'symbol',
                  (
                    select gc.symbol
                    from public.global_currencies gc
                    where gc.id = p.listing_sell_price_currency_id
                  )
                ),
                'resell_minimum_price',
                case
                  when v_shop_type = 'dropship'::public.shop_type_enum
                    and p.minimum_sell_price_amount is not null then jsonb_build_object(
                    'amount',
                    round(p.minimum_sell_price_amount, 4),
                    'currency_id',
                    p.minimum_sell_price_currency_id,
                    'code',
                    (
                      select gc.code
                      from public.global_currencies gc
                      where gc.id = p.minimum_sell_price_currency_id
                    ),
                    'symbol',
                    (
                      select gc.symbol
                      from public.global_currencies gc
                      where gc.id = p.minimum_sell_price_currency_id
                    )
                  )
                  else null
                end,
                'avg_cost',
                jsonb_build_object(
                  'amount',
                  round(p.unit_cost_amount, 4),
                  'currency_id',
                  case
                    when v_shop_type = 'dropship'::public.shop_type_enum then v_buy_currency_id
                    else v_sell_currency_id
                  end,
                  'code',
                  (
                    select gc.code
                    from public.global_currencies gc
                    where gc.id = case
                      when v_shop_type = 'dropship'::public.shop_type_enum then v_buy_currency_id
                      else v_sell_currency_id
                    end
                  ),
                  'symbol',
                  (
                    select gc.symbol
                    from public.global_currencies gc
                    where gc.id = case
                      when v_shop_type = 'dropship'::public.shop_type_enum then v_buy_currency_id
                      else v_sell_currency_id
                    end
                  )
                ),
                'show_quantity',
                p.show_quantity,
                'sell_price_amount',
                p.listing_sell_price_amount,
                'sell_price_currency_id',
                p.listing_sell_price_currency_id,
                'minimum_sell_price_amount',
                p.minimum_sell_price_amount,
                'minimum_sell_price_currency_id',
                p.minimum_sell_price_currency_id
              )
              order by
                p.product_name asc,
                p.grade_slug asc nulls last,
                p.listing_id asc
            )
          from
            paged p
        ),
        '[]'::jsonb
      ),
      'meta',
      jsonb_build_object(
        'total',
        (
          select
            count(*)
          from
            filtered
        ),
        'page',
        (v_offset / v_limit) + 1,
        'page_size',
        v_limit,
        'total_pages',
        greatest(
          1,
          ceil(
            (
              select
                count(*)::numeric
              from
                filtered
            ) / v_limit::numeric
          )
        ),
        'shop',
        jsonb_build_object(
          'id',
          p_shop_id,
          'name',
          v_shop_name,
          'slug',
          v_shop_slug,
          'shop_type',
          v_shop_type,
          'sell_currency_id',
          v_sell_currency_id,
          'buy_currency_id',
          v_buy_currency_id,
          'pricing_method',
          v_pricing_method,
          'markup_percentage',
          v_markup_percentage,
          'quantity_display_mode',
          v_quantity_display_mode
        )
      )
    )
  into v_result;

  return v_result;
end;
$$;

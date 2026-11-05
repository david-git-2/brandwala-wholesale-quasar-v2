CREATE FUNCTION public.get_shop_storefront_listing_price_calculation (
  p_shop_id    bigint,
  p_listing_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.get_shop_storefront_listing_price_calculation(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_shop_storefront_listing_price_calculation(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_shop_storefront_listing_price_calculation(bigint, bigint) TO service_role;
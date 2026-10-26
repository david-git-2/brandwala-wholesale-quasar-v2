-- Staff manual dropship search: match storefront catalog (products.name/code/barcode, group hides, grade ATP).

CREATE OR REPLACE FUNCTION public.browse_dropship_listings_for_staff_order(
  p_tenant_id bigint,
  p_shop_id bigint,
  p_customer_group_id bigint,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 24
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_limit integer;
  v_search text;
  v_data jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_shop_id IS NULL OR p_customer_group_id IS NULL THEN
    RAISE EXCEPTION 'tenant, shop, and customer group are required';
  END IF;

  PERFORM public.assert_staff_can_place_dropship_order_on_behalf(p_shop_id, p_customer_group_id);

  v_limit := greatest(1, least(coalesce(p_limit, 24), 100));
  v_search := nullif(trim(coalesce(p_search, '')), '');

  IF v_search IS NULL THEN
    RETURN jsonb_build_object('data', '[]'::jsonb, 'limit', v_limit);
  END IF;

  SELECT coalesce(
    jsonb_agg(row_data ORDER BY row_data->>'product_name'),
    '[]'::jsonb
  )
  INTO v_data
  FROM (
    SELECT jsonb_build_object(
      'listing_id', l.id,
      'product_id', l.product_id,
      'global_stock_id', l.global_stock_id,
      'product_name', coalesce(nullif(trim(gsi.name), ''), p.name),
      'product_image_url', coalesce(gsi.image_url, p.image_url),
      'product_barcode', coalesce(gsi.barcode, p.barcode),
      'sell_price_amount', l.sell_price_amount,
      'sell_price_currency_id', l.sell_price_currency_id,
      'minimum_sell_price_amount', l.minimum_sell_price_amount,
      'minimum_sell_price_currency_id', l.minimum_sell_price_currency_id,
      'available_to_sell', greatest(
        0,
        floor(
          public.shop_product_grade_available_units(
            s.tenant_id,
            p.id,
            coalesce(l.grade_tag_id, gs.grade_tag_id)
          )
        )::integer
      )
    ) AS row_data
    FROM public.shop_product_listings l
    JOIN public.shops s ON s.id = l.shop_id
    JOIN public.products p ON p.id = l.product_id
    LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
    LEFT JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    WHERE l.shop_id = p_shop_id
      AND s.shop_type = 'dropship'
      AND l.is_active = true
      AND l.global_stock_id IS NOT NULL
      AND p.is_available = true
      AND coalesce(p.hazardous, false) = false
      AND NOT EXISTS (
        SELECT 1 FROM public.shop_listing_group_hides h
        WHERE h.listing_id = l.id AND h.customer_group_id = p_customer_group_id
      )
      AND (
        p.name ILIKE '%' || v_search || '%'
        OR p.product_code ILIKE '%' || v_search || '%'
        OR p.barcode ILIKE '%' || v_search || '%'
      )
    ORDER BY coalesce(nullif(trim(gsi.name), ''), p.name) ASC
    LIMIT v_limit
  ) sub;

  RETURN jsonb_build_object('data', coalesce(v_data, '[]'::jsonb), 'limit', v_limit);
END;
$$;

ALTER FUNCTION public.browse_dropship_listings_for_staff_order(bigint, bigint, bigint, text, integer) OWNER TO postgres;

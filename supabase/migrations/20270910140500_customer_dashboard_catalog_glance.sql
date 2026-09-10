-- Customer home banner: distinct product + brand counts across accessible shops.

CREATE OR REPLACE FUNCTION public.customer_accessible_catalog_glance(
  p_tenant_id bigint,
  p_customer_group_id bigint
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  WITH accessible_shops AS (
    SELECT
      s.id,
      s.shop_type,
      s.vendor_code,
      s.vendor_filters
    FROM public.shops s
    JOIN public.shop_customer_group_access access ON access.shop_id = s.id
    JOIN public.customer_groups cg ON cg.id = access.customer_group_id
    LEFT JOIN public.customer_group_shop_profiles profile
      ON profile.customer_group_id = cg.id AND profile.tenant_id = s.tenant_id
    WHERE s.is_active = true
      AND s.deleted_at IS NULL
      AND s.tenant_id = p_tenant_id
      AND cg.id = p_customer_group_id
      AND cg.is_active = true
      AND access.status = true
      AND coalesce(profile.is_active, true) = true
      AND coalesce(access.can_browse, profile.default_can_browse, false) = true
  ),
  parent_tenant AS (
    SELECT public.resolve_parent_tenant_id(p_tenant_id) AS parent_tenant_id
  ),
  vendor_catalog_products AS (
    SELECT DISTINCT
      p.id AS product_id,
      p.brand AS product_brand
    FROM accessible_shops s
    CROSS JOIN parent_tenant pt
    JOIN public.products p ON p.parent_tenant_id = pt.parent_tenant_id
    WHERE s.shop_type = 'vendor_catalog'::public.shop_type_enum
      AND p.is_available = true
      AND coalesce(p.hazardous, false) = false
      AND (
        ((s.vendor_filters IS NULL OR jsonb_array_length(s.vendor_filters) = 0) AND p.vendor_code = s.vendor_code)
        OR (
          s.vendor_filters IS NOT NULL AND jsonb_array_length(s.vendor_filters) > 0 AND EXISTS (
            SELECT 1
            FROM jsonb_to_recordset(s.vendor_filters) AS vf(vendor_code text, brands text[])
            WHERE vf.vendor_code = p.vendor_code
              AND (vf.brands IS NULL OR array_length(vf.brands, 1) IS NULL OR p.brand = ANY(vf.brands))
          )
        )
      )
  ),
  listing_products AS (
    SELECT DISTINCT
      p.id AS product_id,
      p.brand AS product_brand
    FROM accessible_shops s
    JOIN public.shop_product_listings l ON l.shop_id = s.id
    JOIN public.products p ON p.id = l.product_id
    WHERE s.shop_type <> 'vendor_catalog'::public.shop_type_enum
      AND l.is_active = true
      AND p.is_available = true
      AND coalesce(p.hazardous, false) = false
  ),
  combined AS (
    SELECT product_id, product_brand FROM vendor_catalog_products
    UNION
    SELECT product_id, product_brand FROM listing_products
  )
  SELECT jsonb_build_object(
    'total_products', coalesce((SELECT count(*)::bigint FROM combined), 0),
    'total_brands', coalesce((
      SELECT count(*)::bigint
      FROM (
        SELECT DISTINCT lower(trim(product_brand)) AS brand_key
        FROM combined
        WHERE product_brand IS NOT NULL
          AND trim(product_brand) <> ''
      ) brands
    ), 0)
  );
$$;

CREATE OR REPLACE FUNCTION public.get_customer_dashboard_summary(p_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_group_id bigint;
  v_shops jsonb := '[]'::jsonb;
  v_categories jsonb := '[]'::jsonb;
  v_recent_orders jsonb := '[]'::jsonb;
  v_active_carts jsonb := '[]'::jsonb;
  v_buckets jsonb;
  v_catalog_glance jsonb := jsonb_build_object('total_products', 0, 'total_brands', 0);
BEGIN
  IF p_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'tenant_id', NULL,
      'customer_group_id', NULL,
      'shops', '[]'::jsonb,
      'categories', '[]'::jsonb,
      'catalog_glance', v_catalog_glance,
      'order_glance', jsonb_build_object(
        'buckets', jsonb_build_object('needs_you', 0, 'in_progress', 0, 'done', 0, 'total', 0),
        'segments', jsonb_build_object(
          'needs_you', 0,
          'in_progress', 0,
          'delivered', 0,
          'paid', 0,
          'payment_needed', 0,
          'total', 0
        )
      ),
      'recent_orders', '[]'::jsonb,
      'active_carts', '[]'::jsonb
    );
  END IF;

  v_group_id := public.current_customer_group_id(p_tenant_id);
  IF v_group_id IS NULL THEN
    RETURN jsonb_build_object(
      'tenant_id', p_tenant_id,
      'customer_group_id', NULL,
      'shops', '[]'::jsonb,
      'categories', '[]'::jsonb,
      'catalog_glance', v_catalog_glance,
      'order_glance', jsonb_build_object(
        'buckets', jsonb_build_object('needs_you', 0, 'in_progress', 0, 'done', 0, 'total', 0),
        'segments', jsonb_build_object(
          'needs_you', 0,
          'in_progress', 0,
          'delivered', 0,
          'paid', 0,
          'payment_needed', 0,
          'total', 0
        )
      ),
      'recent_orders', '[]'::jsonb,
      'active_carts', '[]'::jsonb
    );
  END IF;

  v_catalog_glance := public.customer_accessible_catalog_glance(p_tenant_id, v_group_id);

  SELECT coalesce(jsonb_agg(row_to_json(shop_row) ORDER BY shop_row.name), '[]'::jsonb)
  INTO v_shops
  FROM (
    SELECT
      s.id,
      s.tenant_id,
      s.name,
      s.slug,
      s.shop_type,
      s.order_mode,
      s.is_negotiable,
      bool_or(
        CASE
          WHEN access.status = false OR coalesce(profile.is_active, true) = false THEN false
          ELSE public.resolve_shop_can_see_buy_price(
            s.shop_type,
            access.can_see_buy_price,
            access.can_see_sell_price,
            profile.default_can_see_buy_price,
            profile.default_can_see_sell_price
          )
        END
      ) AS can_see_buy_price,
      bool_or(
        CASE
          WHEN access.status = false OR coalesce(profile.is_active, true) = false THEN false
          WHEN s.shop_type = 'dropship' THEN true
          ELSE coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, false)
        END
      ) AS can_see_sell_price,
      s.description,
      s.category_ids,
      coalesce(
        (
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', c.id,
              'name', c.name,
              'slug', c.slug,
              'icon', c.icon
            )
            ORDER BY c.name
          )
          FROM public.shop_categories c
          WHERE c.id = ANY(s.category_ids)
            AND c.is_active = true
        ),
        '[]'::jsonb
      ) AS categories,
      s.sell_currency_id,
      gc.code AS sell_currency_code,
      gc.symbol AS sell_currency_symbol
    FROM public.shops s
    JOIN public.shop_customer_group_access access ON access.shop_id = s.id
    JOIN public.customer_groups cg ON cg.id = access.customer_group_id
    LEFT JOIN public.customer_group_shop_profiles profile
      ON profile.customer_group_id = cg.id AND profile.tenant_id = s.tenant_id
    LEFT JOIN public.global_currencies gc ON gc.id = s.sell_currency_id
    WHERE s.is_active = true
      AND s.deleted_at IS NULL
      AND s.tenant_id = p_tenant_id
      AND cg.id = v_group_id
      AND cg.is_active = true
      AND access.status = true
      AND coalesce(profile.is_active, true) = true
      AND coalesce(access.can_browse, profile.default_can_browse, false) = true
    GROUP BY
      s.id,
      s.tenant_id,
      s.name,
      s.slug,
      s.shop_type,
      s.order_mode,
      s.is_negotiable,
      s.description,
      s.category_ids,
      s.sell_currency_id,
      gc.code,
      gc.symbol
  ) shop_row;

  SELECT coalesce(jsonb_agg(cat ORDER BY cat ->> 'name'), '[]'::jsonb)
  INTO v_categories
  FROM (
    SELECT DISTINCT ON ((cat ->> 'id')::bigint) cat
    FROM (
      SELECT jsonb_array_elements(coalesce(shop_elem -> 'categories', '[]'::jsonb)) AS cat
      FROM jsonb_array_elements(v_shops) shop_elem
    ) cats
    ORDER BY (cat ->> 'id')::bigint
  ) deduped;

  SELECT jsonb_build_object(
    'buckets', jsonb_build_object(
      'needs_you', coalesce(count(*) FILTER (
        WHERE public.customer_shop_order_glance_bucket(o.status) = 'needs_you'
      ), 0),
      'in_progress', coalesce(count(*) FILTER (
        WHERE public.customer_shop_order_glance_bucket(o.status) = 'in_progress'
      ), 0),
      'done', coalesce(count(*) FILTER (
        WHERE public.customer_shop_order_glance_bucket(o.status) = 'done'
      ), 0),
      'total', coalesce(count(*) FILTER (WHERE o.status IS DISTINCT FROM 'draft'), 0)
    ),
    'segments', jsonb_build_object(
      'needs_you', coalesce(count(*) FILTER (
        WHERE public.customer_shop_order_glance_segment(o.status) = 'needs_you'
      ), 0),
      'in_progress', coalesce(count(*) FILTER (
        WHERE public.customer_shop_order_glance_segment(o.status) = 'in_progress'
      ), 0),
      'delivered', coalesce(count(*) FILTER (
        WHERE public.customer_shop_order_glance_segment(o.status) = 'delivered'
      ), 0),
      'paid', coalesce(count(*) FILTER (
        WHERE public.customer_shop_order_glance_segment(o.status) = 'paid'
      ), 0),
      'payment_needed', coalesce(count(*) FILTER (
        WHERE public.customer_shop_order_glance_segment(o.status) = 'payment_needed'
      ), 0),
      'total', coalesce(count(*) FILTER (
        WHERE public.customer_shop_order_glance_segment(o.status) IS NOT NULL
      ), 0)
    )
  )
  INTO v_buckets
  FROM public.shop_orders o
  WHERE o.tenant_id = p_tenant_id
    AND o.customer_group_id = v_group_id
    AND o.status IS DISTINCT FROM 'draft';

  SELECT coalesce(jsonb_agg(row_to_json(order_row) ORDER BY order_row.created_at DESC), '[]'::jsonb)
  INTO v_recent_orders
  FROM (
    SELECT
      o.id,
      o.shop_id,
      s.name AS shop_name,
      s.slug AS shop_slug,
      o.order_no,
      o.status,
      gc.symbol AS currency_symbol,
      o.created_at
    FROM public.shop_orders o
    JOIN public.shops s ON s.id = o.shop_id
    LEFT JOIN public.global_currencies gc ON gc.id = s.sell_currency_id
    WHERE o.tenant_id = p_tenant_id
      AND o.customer_group_id = v_group_id
      AND o.status IS DISTINCT FROM 'draft'
    ORDER BY o.created_at DESC
    LIMIT 5
  ) order_row;

  SELECT coalesce(jsonb_agg(row_to_json(cart_row) ORDER BY cart_row.updated_at DESC), '[]'::jsonb)
  INTO v_active_carts
  FROM (
    SELECT
      c.id AS cart_id,
      s.id AS shop_id,
      s.name AS shop_name,
      s.slug AS shop_slug,
      NULL::text AS shop_logo_url,
      s.shop_type::text AS shop_type,
      c.can_see_buy_price_snapshot AS can_see_buy_price,
      c.can_see_sell_price_snapshot AS can_see_sell_price,
      s.sell_currency_id AS currency_id,
      gc.code AS currency_code,
      gc.symbol AS currency_symbol,
      coalesce(sum(ci.quantity), 0)::bigint AS item_count,
      CASE
        WHEN c.can_see_sell_price_snapshot THEN
          sum(
            ci.quantity * coalesce(
              ci.customer_sell_price_amount,
              ci.unit_sell_price_amount,
              ci.unit_list_price_amount,
              0
            )
          )::numeric
        ELSE NULL
      END AS cart_total,
      c.updated_at
    FROM public.shop_carts c
    JOIN public.shops s ON s.id = c.shop_id
    JOIN public.shop_cart_items ci ON ci.cart_id = c.id
    LEFT JOIN public.global_currencies gc ON gc.id = s.sell_currency_id
    WHERE c.status = 'active'
      AND c.tenant_id = p_tenant_id
      AND c.customer_group_id = v_group_id
    GROUP BY c.id, s.id, gc.code, gc.symbol
  ) cart_row;

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'customer_group_id', v_group_id,
    'shops', v_shops,
    'categories', v_categories,
    'catalog_glance', v_catalog_glance,
    'order_glance', v_buckets,
    'recent_orders', v_recent_orders,
    'active_carts', v_active_carts
  );
END;
$$;

REVOKE ALL ON FUNCTION public.customer_accessible_catalog_glance(bigint, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.customer_accessible_catalog_glance(bigint, bigint) TO authenticated;

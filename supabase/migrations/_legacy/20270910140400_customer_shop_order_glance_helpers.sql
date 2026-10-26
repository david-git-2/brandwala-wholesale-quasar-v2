-- Shared status mapping for customer home order glance and order list filters.

CREATE OR REPLACE FUNCTION public.customer_shop_order_glance_bucket(p_status public.shop_order_status)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_status = 'draft'::public.shop_order_status THEN NULL
    WHEN p_status IN (
      'priced'::public.shop_order_status,
      'negotiating'::public.shop_order_status,
      'countered'::public.shop_order_status,
      'final_offered'::public.shop_order_status
    ) THEN 'needs_you'
    WHEN p_status IN (
      'fulfilled'::public.shop_order_status,
      'delivered'::public.shop_order_status,
      'payment_received'::public.shop_order_status,
      'reseller_paid'::public.shop_order_status,
      'cancelled'::public.shop_order_status,
      'returned'::public.shop_order_status
    ) THEN 'done'
    ELSE 'in_progress'
  END;
$$;

CREATE OR REPLACE FUNCTION public.customer_shop_order_glance_segment(p_status public.shop_order_status)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_status IN (
      'priced'::public.shop_order_status,
      'negotiating'::public.shop_order_status,
      'countered'::public.shop_order_status,
      'final_offered'::public.shop_order_status
    ) THEN 'needs_you'
    WHEN p_status IN (
      'confirmed'::public.shop_order_status,
      'placed'::public.shop_order_status
    ) THEN 'payment_needed'
    WHEN p_status IN (
      'submitted'::public.shop_order_status,
      'costing_pending'::public.shop_order_status,
      'procuring'::public.shop_order_status,
      'ordered'::public.shop_order_status,
      'processing'::public.shop_order_status,
      'shipped'::public.shop_order_status,
      'ready_for_shipment'::public.shop_order_status,
      'ready_for_pickup'::public.shop_order_status
    ) THEN 'in_progress'
    WHEN p_status = 'delivered'::public.shop_order_status THEN 'delivered'
    WHEN p_status IN (
      'payment_received'::public.shop_order_status,
      'reseller_paid'::public.shop_order_status
    ) THEN 'paid'
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION public.list_customer_shop_orders(
  p_tenant_id bigint,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0,
  p_status_bucket text DEFAULT NULL
)
RETURNS TABLE(
  id bigint,
  shop_id bigint,
  shop_name text,
  shop_slug text,
  shop_type_snapshot public.shop_type_enum,
  order_no text,
  status public.shop_order_status,
  item_count bigint,
  can_see_buy_price boolean,
  can_see_sell_price boolean,
  sell_currency_id bigint,
  currency_symbol text,
  total_amount numeric,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_group_id bigint;
  v_limit integer;
  v_offset integer;
BEGIN
  IF p_tenant_id IS NULL THEN
    RETURN;
  END IF;

  IF p_status_bucket IS NOT NULL
     AND p_status_bucket NOT IN ('needs_you', 'in_progress', 'done') THEN
    RETURN;
  END IF;

  v_group_id := public.current_customer_group_id(p_tenant_id);
  IF v_group_id IS NULL THEN
    RETURN;
  END IF;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  RETURN QUERY
  SELECT
    o.id,
    o.shop_id,
    s.name AS shop_name,
    s.slug AS shop_slug,
    o.shop_type_snapshot,
    o.order_no,
    o.status,
    (
      SELECT count(*)::bigint
      FROM public.shop_order_items soi
      WHERE soi.order_id = o.id
    ) AS item_count,
    CASE
      WHEN o.shop_type_snapshot = 'dropship' THEN true
      WHEN o.cart_id IS NOT NULL THEN coalesce(c.can_see_buy_price_snapshot, false)
      ELSE coalesce(live_perm.can_see_buy_price, false)
    END AS can_see_buy_price,
    CASE
      WHEN o.shop_type_snapshot = 'dropship' THEN true
      WHEN o.cart_id IS NOT NULL THEN coalesce(c.can_see_sell_price_snapshot, false)
      ELSE coalesce(live_perm.can_see_sell_price, false)
    END AS can_see_sell_price,
    s.sell_currency_id,
    gc.symbol AS currency_symbol,
    CASE
      WHEN (
        CASE
          WHEN o.shop_type_snapshot = 'dropship' THEN true
          WHEN o.cart_id IS NOT NULL THEN coalesce(c.can_see_sell_price_snapshot, false)
          ELSE coalesce(live_perm.can_see_sell_price, false)
        END
      ) THEN
        coalesce(
          (
            SELECT sum(
              coalesce(
                soi.final_price_amount,
                soi.customer_offer_amount,
                soi.unit_sell_price_amount,
                soi.unit_list_price_amount
              ) * soi.quantity
            )
            FROM public.shop_order_items soi
            WHERE soi.order_id = o.id
          ),
          0
        )::numeric
      ELSE NULL
    END AS total_amount,
    o.created_at
  FROM public.shop_orders o
  JOIN public.shops s ON s.id = o.shop_id
  LEFT JOIN public.shop_carts c ON c.id = o.cart_id
  LEFT JOIN LATERAL (
    SELECT p.can_see_buy_price, p.can_see_sell_price
    FROM public.get_shop_permissions_for_customer(o.shop_id) p
    LIMIT 1
  ) live_perm ON true
  LEFT JOIN public.global_currencies gc ON gc.id = s.sell_currency_id
  WHERE o.tenant_id = p_tenant_id
    AND o.customer_group_id = v_group_id
    AND o.status IS DISTINCT FROM 'draft'
    AND (
      p_status_bucket IS NULL
      OR public.customer_shop_order_glance_bucket(o.status) = p_status_bucket
    )
  ORDER BY o.created_at DESC
  LIMIT v_limit
  OFFSET v_offset;
END;
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
BEGIN
  IF p_tenant_id IS NULL THEN
    RETURN jsonb_build_object(
      'tenant_id', NULL,
      'customer_group_id', NULL,
      'shops', '[]'::jsonb,
      'categories', '[]'::jsonb,
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
    'order_glance', v_buckets,
    'recent_orders', v_recent_orders,
    'active_carts', v_active_carts
  );
END;
$$;

REVOKE ALL ON FUNCTION public.customer_shop_order_glance_bucket(public.shop_order_status) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.customer_shop_order_glance_segment(public.shop_order_status) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.customer_shop_order_glance_bucket(public.shop_order_status) TO authenticated;
GRANT EXECUTE ON FUNCTION public.customer_shop_order_glance_segment(public.shop_order_status) TO authenticated;

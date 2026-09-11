-- Expose order pricing mode (negotiable vs fixed) on staff and customer order lists.

DROP FUNCTION IF EXISTS public.list_shop_orders_for_staff(bigint, integer, integer, text, text, bigint);

CREATE OR REPLACE FUNCTION public.list_shop_orders_for_staff(
  p_tenant_id bigint,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0,
  p_search text DEFAULT NULL::text,
  p_status text DEFAULT NULL::text,
  p_shop_id bigint DEFAULT NULL::bigint
)
RETURNS TABLE(
  id bigint,
  tenant_id bigint,
  shop_id bigint,
  shop_name text,
  customer_group_id bigint,
  customer_group_name text,
  order_no text,
  name text,
  shop_type_snapshot public.shop_type_enum,
  is_negotiable_snapshot boolean,
  status public.shop_order_status,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  item_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  RETURN QUERY
  SELECT
    o.id,
    o.tenant_id,
    o.shop_id,
    s.name AS shop_name,
    o.customer_group_id,
    cg.name AS customer_group_name,
    o.order_no,
    o.name,
    o.shop_type_snapshot,
    o.is_negotiable_snapshot,
    o.status,
    o.created_at,
    o.updated_at,
    (SELECT count(*)::bigint FROM public.shop_order_items WHERE order_id = o.id) AS item_count
  FROM public.shop_orders o
  JOIN public.shops s ON s.id = o.shop_id
  JOIN public.customer_groups cg ON cg.id = o.customer_group_id
  WHERE o.tenant_id = p_tenant_id
    AND (p_status IS NULL OR o.status::text = p_status)
    AND (p_shop_id IS NULL OR o.shop_id = p_shop_id)
    AND (
      p_search IS NULL
      OR o.order_no ILIKE ('%' || p_search || '%')
      OR o.name ILIKE ('%' || p_search || '%')
      OR s.name ILIKE ('%' || p_search || '%')
      OR cg.name ILIKE ('%' || p_search || '%')
    )
  ORDER BY o.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

DROP FUNCTION IF EXISTS public.list_customer_shop_orders(bigint, integer, integer, text);

CREATE OR REPLACE FUNCTION public.list_customer_shop_orders(
  p_tenant_id bigint,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0,
  p_status_bucket text DEFAULT NULL::text
)
RETURNS TABLE(
  id bigint,
  shop_id bigint,
  shop_name text,
  shop_slug text,
  shop_type_snapshot public.shop_type_enum,
  is_negotiable_snapshot boolean,
  order_no text,
  status public.shop_order_status,
  item_count bigint,
  can_see_buy_price boolean,
  can_see_sell_price boolean,
  sell_currency_id bigint,
  currency_symbol text,
  total_amount numeric,
  created_at timestamp with time zone
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
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
    o.is_negotiable_snapshot,
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

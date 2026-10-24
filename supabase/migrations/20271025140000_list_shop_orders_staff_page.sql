-- Bundled staff orders page: shops (first page) + cursor-paginated orders in one RPC.

CREATE OR REPLACE FUNCTION public.list_shop_orders_staff_page(
  p_tenant_id bigint,
  p_parent_tenant_id bigint DEFAULT NULL,
  p_limit integer DEFAULT 30,
  p_search text DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_shop_id bigint DEFAULT NULL,
  p_shop_type text DEFAULT NULL,
  p_cursor_created_at timestamptz DEFAULT NULL,
  p_cursor_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_limit integer := greatest(1, least(coalesce(p_limit, 30), 100));
  v_fetch integer := v_limit + 1;
  v_is_parent_query boolean;
  v_shops jsonb := '[]'::jsonb;
  v_orders jsonb := '[]'::jsonb;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
BEGIN
  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  v_is_parent_query := (p_parent_tenant_id IS NOT NULL AND p_parent_tenant_id = p_tenant_id);

  IF p_cursor_created_at IS NULL AND p_cursor_id IS NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.memberships m
      WHERE (m.tenant_id = p_tenant_id OR m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id))
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
    ) THEN
      RAISE EXCEPTION 'not allowed';
    END IF;

    IF v_is_parent_query THEN
      SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.name), '[]'::jsonb)
      INTO v_shops
      FROM (
        SELECT
          s.id,
          s.tenant_id,
          s.name,
          s.slug,
          s.shop_type,
          coalesce(t.name, '')::text AS tenant_name
        FROM public.shops s
        LEFT JOIN public.tenants t ON t.id = s.tenant_id
        WHERE (s.parent_tenant_id = p_parent_tenant_id OR s.tenant_id = p_parent_tenant_id)
          AND s.deleted_at IS NULL
        ORDER BY s.name
        LIMIT 500
      ) x;
    ELSE
      SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.name), '[]'::jsonb)
      INTO v_shops
      FROM (
        SELECT
          s.id,
          s.tenant_id,
          s.name,
          s.slug,
          s.shop_type,
          coalesce(t.name, '')::text AS tenant_name
        FROM public.shops s
        LEFT JOIN public.tenants t ON t.id = s.tenant_id
        WHERE s.tenant_id = p_tenant_id
          AND s.deleted_at IS NULL
        ORDER BY s.name
        LIMIT 500
      ) x;
    END IF;
  END IF;

  WITH base AS (
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
      (SELECT count(*)::bigint FROM public.shop_order_items WHERE order_id = o.id) AS item_count,
      coalesce(t.name, '')::text AS tenant_name
    FROM public.shop_orders o
    JOIN public.shops s ON s.id = o.shop_id
    JOIN public.customer_groups cg ON cg.id = o.customer_group_id
    LEFT JOIN public.tenants t ON t.id = o.tenant_id
    WHERE (
      (v_is_parent_query AND (o.parent_tenant_id = p_parent_tenant_id OR o.tenant_id = p_parent_tenant_id))
      OR (NOT v_is_parent_query AND o.tenant_id = p_tenant_id)
    )
      AND (p_status IS NULL OR o.status::text = p_status)
      AND (p_shop_id IS NULL OR o.shop_id = p_shop_id)
      AND (p_shop_type IS NULL OR s.shop_type::text = p_shop_type)
      AND (
        p_search IS NULL
        OR o.order_no ILIKE ('%' || p_search || '%')
        OR o.name ILIKE ('%' || p_search || '%')
        OR s.name ILIKE ('%' || p_search || '%')
        OR cg.name ILIKE ('%' || p_search || '%')
        OR t.name ILIKE ('%' || p_search || '%')
      )
      AND (
        p_cursor_created_at IS NULL
        OR (o.created_at, o.id) < (p_cursor_created_at, p_cursor_id)
      )
    ORDER BY o.created_at DESC, o.id DESC
    LIMIT v_fetch
  ),
  page AS (
    SELECT * FROM base ORDER BY created_at DESC, id DESC LIMIT v_limit
  ),
  tail AS (
    SELECT created_at, id FROM page ORDER BY created_at ASC, id ASC LIMIT 1
  )
  SELECT
    coalesce(
      (SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at DESC, p.id DESC) FROM page p),
      '[]'::jsonb
    ),
    (SELECT count(*) > v_limit FROM base),
    CASE
      WHEN (SELECT count(*) FROM base) > v_limit THEN
        (SELECT jsonb_build_object('created_at', created_at, 'id', id) FROM tail)
      ELSE NULL
    END
  INTO v_orders, v_has_more, v_next_cursor;

  RETURN jsonb_build_object(
    'shops', v_shops,
    'orders', v_orders,
    'meta', jsonb_build_object(
      'limit', v_limit,
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    )
  );
END;
$$;

ALTER FUNCTION public.list_shop_orders_staff_page(
  bigint, bigint, integer, text, text, bigint, text, timestamptz, bigint
) OWNER TO postgres;

GRANT ALL ON FUNCTION public.list_shop_orders_staff_page(
  bigint, bigint, integer, text, text, bigint, text, timestamptz, bigint
) TO authenticated;

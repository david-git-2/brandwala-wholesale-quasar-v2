-- Shops list page: shops (paginated) + catalog refresh log on first page only.

CREATE OR REPLACE FUNCTION public.list_shops_app_page(
  p_tenant_id bigint,
  p_parent_tenant_id bigint DEFAULT NULL,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0,
  p_search text DEFAULT NULL,
  p_active boolean DEFAULT NULL,
  p_catalog_parent_tenant_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_total bigint;
  v_is_parent_query boolean;
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_shops jsonb := '[]'::jsonb;
  v_catalog jsonb := '[]'::jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE (m.tenant_id = p_tenant_id OR m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id))
      AND lower(trim(m.email)) = public.current_user_email()
      AND m.is_active = true
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_is_parent_query := (p_parent_tenant_id IS NOT NULL AND p_parent_tenant_id = p_tenant_id);

  IF v_is_parent_query THEN
    SELECT count(*)
    INTO v_total
    FROM public.shops s
    LEFT JOIN public.tenants t ON t.id = s.tenant_id
    WHERE (s.parent_tenant_id = p_parent_tenant_id OR s.tenant_id = p_parent_tenant_id)
      AND s.deleted_at IS NULL
      AND (p_active IS NULL OR s.is_active = p_active)
      AND (
        p_search IS NULL
        OR s.name ILIKE '%' || p_search || '%'
        OR s.slug ILIKE '%' || p_search || '%'
        OR t.name ILIKE '%' || p_search || '%'
      );

    SELECT coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    INTO v_shops
    FROM (
      SELECT
        s.id,
        s.tenant_id,
        s.name,
        s.slug,
        s.shop_type,
        s.vendor_code,
        s.order_mode,
        s.is_negotiable,
        s.show_stock_quantity,
        s.default_currency_id,
        s.global_stock_type_id,
        s.is_active,
        s.allow_delivery,
        s.buy_currency_id,
        s.sell_currency_id,
        s.pricing_method,
        s.markup_percentage,
        s.quantity_display_mode,
        s.display_quantity_add,
        s.default_print_charge_amount,
        s.default_packing_charge_amount,
        s.deduct_charges_from_margin,
        s.vendor_filters,
        s.deduct_print_from_margin,
        s.deduct_packing_from_margin,
        s.description,
        s.category_ids,
        s.created_at,
        s.updated_at,
        v_total AS total_count,
        coalesce(t.name, '')::text AS tenant_name
      FROM public.shops s
      LEFT JOIN public.tenants t ON t.id = s.tenant_id
      WHERE (s.parent_tenant_id = p_parent_tenant_id OR s.tenant_id = p_parent_tenant_id)
        AND s.deleted_at IS NULL
        AND (p_active IS NULL OR s.is_active = p_active)
        AND (
          p_search IS NULL
          OR s.name ILIKE '%' || p_search || '%'
          OR s.slug ILIKE '%' || p_search || '%'
          OR t.name ILIKE '%' || p_search || '%'
        )
      ORDER BY s.name
      LIMIT v_limit
      OFFSET v_offset
    ) x;
  ELSE
    SELECT count(*)
    INTO v_total
    FROM public.shops s
    LEFT JOIN public.tenants t ON t.id = s.tenant_id
    WHERE s.tenant_id = p_tenant_id
      AND s.deleted_at IS NULL
      AND (p_active IS NULL OR s.is_active = p_active)
      AND (
        p_search IS NULL
        OR s.name ILIKE '%' || p_search || '%'
        OR s.slug ILIKE '%' || p_search || '%'
        OR t.name ILIKE '%' || p_search || '%'
      );

    SELECT coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    INTO v_shops
    FROM (
      SELECT
        s.id,
        s.tenant_id,
        s.name,
        s.slug,
        s.shop_type,
        s.vendor_code,
        s.order_mode,
        s.is_negotiable,
        s.show_stock_quantity,
        s.default_currency_id,
        s.global_stock_type_id,
        s.is_active,
        s.allow_delivery,
        s.buy_currency_id,
        s.sell_currency_id,
        s.pricing_method,
        s.markup_percentage,
        s.quantity_display_mode,
        s.display_quantity_add,
        s.default_print_charge_amount,
        s.default_packing_charge_amount,
        s.deduct_charges_from_margin,
        s.vendor_filters,
        s.deduct_print_from_margin,
        s.deduct_packing_from_margin,
        s.description,
        s.category_ids,
        s.created_at,
        s.updated_at,
        v_total AS total_count,
        coalesce(t.name, '')::text AS tenant_name
      FROM public.shops s
      LEFT JOIN public.tenants t ON t.id = s.tenant_id
      WHERE s.tenant_id = p_tenant_id
        AND s.deleted_at IS NULL
        AND (p_active IS NULL OR s.is_active = p_active)
        AND (
          p_search IS NULL
          OR s.name ILIKE '%' || p_search || '%'
          OR s.slug ILIKE '%' || p_search || '%'
          OR t.name ILIKE '%' || p_search || '%'
        )
      ORDER BY s.name
      LIMIT v_limit
      OFFSET v_offset
    ) x;
  END IF;

  IF v_offset = 0
    AND p_catalog_parent_tenant_id IS NOT NULL
    AND public.can_view_products_for_parent(p_catalog_parent_tenant_id)
  THEN
    SELECT coalesce(jsonb_agg(to_jsonb(l)), '[]'::jsonb)
    INTO v_catalog
    FROM (
      SELECT
        l.id,
        l.parent_tenant_id,
        l.source,
        l.event_kind,
        l.source_url,
        l.file_name,
        l.ran_at,
        l.products_updated,
        l.duration_seconds
      FROM public.catalog_refresh_log l
      WHERE l.parent_tenant_id = p_catalog_parent_tenant_id
      ORDER BY l.ran_at DESC
      LIMIT 200
    ) l;
  END IF;

  RETURN jsonb_build_object(
    'shops', v_shops,
    'total_count', v_total,
    'catalog_refresh_log', v_catalog
  );
END;
$$;

ALTER FUNCTION public.list_shops_app_page(
  bigint, bigint, integer, integer, text, boolean, bigint
) OWNER TO postgres;

GRANT ALL ON FUNCTION public.list_shops_app_page(
  bigint, bigint, integer, integer, text, boolean, bigint
) TO authenticated;

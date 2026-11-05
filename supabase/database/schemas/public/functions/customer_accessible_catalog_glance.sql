CREATE FUNCTION public.customer_accessible_catalog_glance (
  p_tenant_id         bigint,
  p_customer_group_id bigint
)
  RETURNS jsonb
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.customer_accessible_catalog_glance(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.customer_accessible_catalog_glance(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.customer_accessible_catalog_glance(bigint, bigint) TO service_role;
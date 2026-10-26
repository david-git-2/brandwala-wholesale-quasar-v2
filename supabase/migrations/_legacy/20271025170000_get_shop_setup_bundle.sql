CREATE OR REPLACE FUNCTION public.get_shop_setup_bundle(
  p_shop_id bigint,
  p_tenant_id bigint
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_shop jsonb;
  v_shop_tenant_id bigint;
  v_scope_tenant_id bigint;
  v_categories jsonb := '[]'::jsonb;
  v_vendors jsonb := '[]'::jsonb;
  v_brands_by_vendor jsonb := '{}'::jsonb;
BEGIN
  IF p_shop_id IS NULL OR p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop_id and tenant_id are required';
  END IF;

  SELECT
    to_jsonb(s) || jsonb_build_object('tenant_slug', coalesce(t.slug, '')),
    s.tenant_id
  INTO v_shop, v_shop_tenant_id
  FROM public.shops s
  LEFT JOIN public.tenants t ON t.id = s.tenant_id
  WHERE s.id = p_shop_id
    AND s.deleted_at IS NULL
    AND (s.tenant_id = p_tenant_id OR s.parent_tenant_id = p_tenant_id);

  IF v_shop IS NULL OR v_shop_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop not found';
  END IF;

  IF NOT public.user_can_access_tenant_fetch(v_shop_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_scope_tenant_id := public.resolve_parent_tenant_id(v_shop_tenant_id);

  SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY c.name), '[]'::jsonb)
  INTO v_categories
  FROM public.shop_categories c
  WHERE c.tenant_id = v_shop_tenant_id;

  SELECT coalesce(jsonb_agg(to_jsonb(v) ORDER BY v.id), '[]'::jsonb)
  INTO v_vendors
  FROM public.list_vendors_for_tenant(v_shop_tenant_id) v;

  SELECT coalesce(
    jsonb_object_agg(upper(trim(x.vendor_code)), x.brand_names),
    '{}'::jsonb
  )
  INTO v_brands_by_vendor
  FROM (
    SELECT
      pb.vendor_code,
      jsonb_agg(trim(pb.name) ORDER BY trim(pb.name))
        FILTER (WHERE pb.name IS NOT NULL AND trim(pb.name) <> '') AS brand_names
    FROM public.product_brands pb
    WHERE pb.parent_tenant_id = v_scope_tenant_id
      AND pb.vendor_code IS NOT NULL
      AND trim(pb.vendor_code) <> ''
    GROUP BY pb.vendor_code
  ) x
  WHERE x.brand_names IS NOT NULL;

  RETURN jsonb_build_object(
    'shop', v_shop,
    'categories', v_categories,
    'vendors', v_vendors,
    'brands_by_vendor', v_brands_by_vendor
  );
END;
$$;

ALTER FUNCTION public.get_shop_setup_bundle(bigint, bigint) OWNER TO postgres;

GRANT ALL ON FUNCTION public.get_shop_setup_bundle(bigint, bigint) TO authenticated;

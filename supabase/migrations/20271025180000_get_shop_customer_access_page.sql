CREATE OR REPLACE FUNCTION public.get_shop_customer_access_page(
  p_shop_id bigint,
  p_tenant_id bigint
) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO public
    AS $$
DECLARE
  v_shop_tenant_id bigint;
  v_books_id bigint;
  v_groups jsonb := '[]'::jsonb;
  v_access jsonb := '[]'::jsonb;
BEGIN
  IF p_shop_id IS NULL OR p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop_id and tenant_id are required';
  END IF;

  SELECT s.tenant_id
  INTO v_shop_tenant_id
  FROM public.shops s
  WHERE s.id = p_shop_id
    AND s.deleted_at IS NULL
    AND (s.tenant_id = p_tenant_id OR s.parent_tenant_id = p_tenant_id);

  IF v_shop_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop not found';
  END IF;

  IF NOT public.user_can_access_tenant_fetch(v_shop_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_books_id := public.resolve_parent_tenant_id(v_shop_tenant_id);

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', cg.id,
        'name', cg.name,
        'is_active', cg.is_active,
        'accent_color', cg.accent_color
      )
      ORDER BY cg.name
    ),
    '[]'::jsonb
  )
  INTO v_groups
  FROM public.customer_groups cg
  WHERE cg.parent_tenant_id = v_books_id
    AND cg.deleted_at IS NULL;

  SELECT coalesce(jsonb_agg(to_jsonb(a)), '[]'::jsonb)
  INTO v_access
  FROM public.shop_customer_group_access a
  WHERE a.shop_id = p_shop_id;

  RETURN jsonb_build_object(
    'customer_groups', v_groups,
    'access_overrides', v_access
  );
END;
$$;

ALTER FUNCTION public.get_shop_customer_access_page(bigint, bigint) OWNER TO postgres;

GRANT ALL ON FUNCTION public.get_shop_customer_access_page(bigint, bigint) TO authenticated;

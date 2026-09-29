DROP FUNCTION IF EXISTS public.list_products_paginated(
  bigint, text, text, text, text, text, text, boolean, text, text, integer, integer
);

CREATE INDEX IF NOT EXISTS products_parent_tenant_name_id_idx
  ON public.products (parent_tenant_id, name, id);

CREATE OR REPLACE FUNCTION public.list_products_paginated(
  p_tenant_id bigint DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_search_field text DEFAULT 'name',
  p_category text DEFAULT NULL,
  p_brand text DEFAULT NULL,
  p_vendor_code text DEFAULT NULL,
  p_market_code text DEFAULT NULL,
  p_is_available boolean DEFAULT NULL,
  p_sort_dir text DEFAULT 'asc',
  p_limit integer DEFAULT 20,
  p_cursor_name text DEFAULT NULL,
  p_cursor_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $_$
DECLARE
  v_limit integer;
  v_sort_dir text;
  v_search_field text;
  v_scope_tenant_id bigint;
  v_rows jsonb;
  v_n integer;
  v_has_more boolean := false;
  v_next_cursor jsonb := NULL;
  v_last_name text;
  v_last_id bigint;
  v_tokens text[] := '{}'::text[];
  v_cursor_name text;
BEGIN
  IF p_tenant_id IS NOT NULL AND NOT public.user_can_access_tenant_fetch(p_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_scope_tenant_id := CASE
    WHEN p_tenant_id IS NULL THEN NULL
    ELSE public.resolve_parent_tenant_id(p_tenant_id)
  END;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));

  v_sort_dir := lower(trim(coalesce(p_sort_dir, 'asc')));
  IF v_sort_dir NOT IN ('asc', 'desc') THEN
    v_sort_dir := 'asc';
  END IF;

  v_search_field := lower(trim(coalesce(p_search_field, 'name')));
  IF v_search_field NOT IN ('name', 'barcode', 'product_code', 'id') THEN
    v_search_field := 'name';
  END IF;

  IF v_search_field = 'name' AND p_search IS NOT NULL AND trim(p_search) <> '' THEN
    SELECT coalesce(array_agg(tok), '{}'::text[])
    INTO v_tokens
    FROM unnest(regexp_split_to_array(trim(p_search), E'[^[:alnum:]]+')) AS tok
    WHERE tok <> ''
      AND lower(tok) NOT IN ('a', 'an', 'the', 'and', 'or', 'of', 'for', 'to', 'in', 'on');

    IF cardinality(v_tokens) = 0 THEN
      v_tokens := array[trim(p_search)];
    END IF;
  END IF;

  v_cursor_name := coalesce(p_cursor_name, '');

  IF v_sort_dir = 'asc' THEN
    SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q._sort_name ASC, q.id ASC), '[]'::jsonb)
    INTO v_rows
    FROM (
      SELECT
        p.*,
        coalesce(p.name, '') AS _sort_name
      FROM public.products p
      WHERE
        (v_scope_tenant_id IS NULL OR p.parent_tenant_id = v_scope_tenant_id)
        AND (p_search IS NULL OR trim(p_search) = '' OR (
          (v_search_field = 'name' AND (
            cardinality(v_tokens) = 0
            OR (
              SELECT coalesce(bool_and(
                concat_ws(' ', p.name, p.brand) ~* ('(^|[^[:alnum:]])' || t || '([^[:alnum:]]|$)')
              ), true)
              FROM unnest(v_tokens) t
            )
          ))
          OR (v_search_field = 'barcode' AND p.barcode ILIKE ('%' || trim(p_search) || '%'))
          OR (v_search_field = 'product_code' AND p.product_code ILIKE ('%' || trim(p_search) || '%'))
          OR (v_search_field = 'id' AND trim(p_search) ~ '^[0-9]+$' AND p.id = trim(p_search)::bigint)
        ))
        AND (p_category IS NULL OR trim(p_category) = '' OR lower(coalesce(p.category, '')) = lower(trim(p_category)))
        AND (p_brand IS NULL OR trim(p_brand) = '' OR lower(coalesce(p.brand, '')) = lower(trim(p_brand)))
        AND (p_vendor_code IS NULL OR trim(p_vendor_code) = '' OR upper(coalesce(p.vendor_code, '')) = upper(trim(p_vendor_code)))
        AND (p_market_code IS NULL OR trim(p_market_code) = '' OR upper(coalesce(p.market_code, '')) = upper(trim(p_market_code)))
        AND (p_is_available IS NULL OR p.is_available = p_is_available)
        AND (
          p_cursor_id IS NULL
          OR (coalesce(p.name, ''), p.id) > (v_cursor_name, p_cursor_id)
        )
      ORDER BY coalesce(p.name, '') ASC, p.id ASC
      LIMIT v_limit + 1
    ) q;
  ELSE
    SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q._sort_name DESC, q.id DESC), '[]'::jsonb)
    INTO v_rows
    FROM (
      SELECT
        p.*,
        coalesce(p.name, '') AS _sort_name
      FROM public.products p
      WHERE
        (v_scope_tenant_id IS NULL OR p.parent_tenant_id = v_scope_tenant_id)
        AND (p_search IS NULL OR trim(p_search) = '' OR (
          (v_search_field = 'name' AND (
            cardinality(v_tokens) = 0
            OR (
              SELECT coalesce(bool_and(
                concat_ws(' ', p.name, p.brand) ~* ('(^|[^[:alnum:]])' || t || '([^[:alnum:]]|$)')
              ), true)
              FROM unnest(v_tokens) t
            )
          ))
          OR (v_search_field = 'barcode' AND p.barcode ILIKE ('%' || trim(p_search) || '%'))
          OR (v_search_field = 'product_code' AND p.product_code ILIKE ('%' || trim(p_search) || '%'))
          OR (v_search_field = 'id' AND trim(p_search) ~ '^[0-9]+$' AND p.id = trim(p_search)::bigint)
        ))
        AND (p_category IS NULL OR trim(p_category) = '' OR lower(coalesce(p.category, '')) = lower(trim(p_category)))
        AND (p_brand IS NULL OR trim(p_brand) = '' OR lower(coalesce(p.brand, '')) = lower(trim(p_brand)))
        AND (p_vendor_code IS NULL OR trim(p_vendor_code) = '' OR upper(coalesce(p.vendor_code, '')) = upper(trim(p_vendor_code)))
        AND (p_market_code IS NULL OR trim(p_market_code) = '' OR upper(coalesce(p.market_code, '')) = upper(trim(p_market_code)))
        AND (p_is_available IS NULL OR p.is_available = p_is_available)
        AND (
          p_cursor_id IS NULL
          OR (coalesce(p.name, ''), p.id) < (v_cursor_name, p_cursor_id)
        )
      ORDER BY coalesce(p.name, '') DESC, p.id DESC
      LIMIT v_limit + 1
    ) q;
  END IF;

  v_n := jsonb_array_length(v_rows);
  IF v_n > v_limit THEN
    v_has_more := true;
    SELECT elem->>'name', (elem->>'id')::bigint
    INTO v_last_name, v_last_id
    FROM jsonb_array_elements(v_rows) WITH ORDINALITY AS t(elem, ord)
    WHERE ord = v_limit;

    v_next_cursor := jsonb_build_object(
      'name', coalesce(v_last_name, ''),
      'id', v_last_id
    );

    SELECT coalesce(jsonb_agg(elem ORDER BY ord), '[]'::jsonb)
    INTO v_rows
    FROM (
      SELECT (elem - '_sort_name') AS elem, ord
      FROM jsonb_array_elements(v_rows) WITH ORDINALITY AS t(elem, ord)
      WHERE ord <= v_limit
    ) trimmed;
  ELSE
    SELECT coalesce(jsonb_agg(elem ORDER BY ord), '[]'::jsonb)
    INTO v_rows
    FROM (
      SELECT (elem - '_sort_name') AS elem, ord
      FROM jsonb_array_elements(v_rows) WITH ORDINALITY AS t(elem, ord)
    ) trimmed;
  END IF;

  RETURN jsonb_build_object(
    'data', coalesce(v_rows, '[]'::jsonb),
    'meta', jsonb_build_object(
      'has_more', v_has_more,
      'next_cursor', v_next_cursor,
      'limit', v_limit
    )
  );
END;
$_$;

GRANT ALL ON FUNCTION public.list_products_paginated(
  bigint, text, text, text, text, text, text, boolean, text, integer, text, bigint
) TO authenticated;
